#!/usr/bin/env python3
"""
backlog_helper.py
Universal CLI for querying and updating task boards across any Obsidian project.

Features:
- Auto-detects project from current git repo / working directory if not specified
- Lists tasks filtered by column (Backlog, Next Up, In Progress, Review, Done)
- Moves tasks between columns (e.g. from Backlog to In Progress, In Progress to Done)
- Adds new tasks to Backlog
"""

import os
import sys
import re
import subprocess
import argparse
from datetime import datetime

VAULT_PATH = "/Users/supreethks/docs/obsidian/main-vault"
PROJECTS_DIR = os.path.join(VAULT_PATH, "projects")

def get_available_projects():
    if not os.path.exists(PROJECTS_DIR):
        return []
    projects = []
    for item in os.listdir(PROJECTS_DIR):
        item_path = os.path.join(PROJECTS_DIR, item)
        if os.path.isdir(item_path) and os.path.isfile(os.path.join(item_path, "Kanban.md")):
            projects.append(item)
    return sorted(projects)

def detect_current_project():
    """Detects active project from git root or working directory."""
    # 1. Check git root name
    try:
        git_root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], stderr=subprocess.DEVNULL).decode().strip()
        git_name = os.path.basename(git_root).lower()
        # Clean velocity -> vimark or similar mappings if needed
        if git_name == "velocity":
            git_name = "vimark"
        
        available = get_available_projects()
        for p in available:
            if p.lower() == git_name:
                return p
    except Exception:
        pass

    # 2. Check current working directory name
    cwd_name = os.path.basename(os.getcwd()).lower()
    if cwd_name == "velocity":
        cwd_name = "vimark"
    for p in get_available_projects():
        if p.lower() == cwd_name:
            return p

    # 3. Check for .obsidian-project marker file
    if os.path.isfile(".obsidian-project"):
        with open(".obsidian-project", "r") as f:
            slug = f.read().strip()
            if slug:
                return slug

    return None

def resolve_kanban_path(project_name=None):
    if not project_name:
        project_name = detect_current_project()
        if not project_name:
            available = get_available_projects()
            print("Error: Could not automatically detect project from current directory.", file=sys.stderr)
            print(f"Available projects in vault: {', '.join(available)}", file=sys.stderr)
            print("Please specify the project explicitly (e.g. `python3 backlog_helper.py list vimark`).", file=sys.stderr)
            sys.exit(1)

    proj_dir = os.path.join(PROJECTS_DIR, project_name)
    if os.path.isdir(proj_dir):
        kanban_file = os.path.join(proj_dir, "Kanban.md")
        if os.path.isfile(kanban_file):
            return project_name, kanban_file

    # Case-insensitive / partial match
    for item in get_available_projects():
        if item.lower() == project_name.lower():
            return item, os.path.join(PROJECTS_DIR, item, "Kanban.md")

    # Root Kanban fallback
    root_kanban = os.path.join(PROJECTS_DIR, f"Kanban - {project_name}.md")
    if os.path.isfile(root_kanban):
        return project_name, root_kanban

    available = get_available_projects()
    print(f"Error: Project '{project_name}' not found under {PROJECTS_DIR}.", file=sys.stderr)
    print(f"Available projects: {', '.join(available)}", file=sys.stderr)
    sys.exit(1)

def parse_kanban_sections(content: str):
    sections = []
    lines = content.splitlines()
    current_section = None

    for line in lines:
        header_match = re.match(r"^(##\s+(?:[^\n]+))", line)
        if header_match and not line.startswith("## 📚") and not line.startswith("%%"):
            header_full = header_match.group(1).strip()
            title = re.sub(r"^##\s*[\U00010000-\U0010ffff\u2600-\u27ff\u2300-\u23ff]?\s*", "", header_full).strip()
            current_section = {
                "header": header_full,
                "title": title,
                "lines": [],
                "tasks": []
            }
            sections.append(current_section)
        elif current_section is not None:
            current_section["lines"].append(line)

    for sec in sections:
        sec_lines = sec["lines"]
        i = 0
        while i < len(sec_lines):
            line = sec_lines[i]
            task_match = re.match(r"^\s*-\s*\[([ xX])\]\s*(.*)", line)
            if task_match:
                task_status = task_match.group(1)
                task_content = [line]
                j = i + 1
                while j < len(sec_lines):
                    next_line = sec_lines[j]
                    if next_line.startswith("\t") or next_line.startswith("   ") or next_line.startswith("  -"):
                        task_content.append(next_line)
                        j += 1
                    else:
                        break
                sec["tasks"].append({
                    "is_done": task_status.lower() == 'x',
                    "raw": "\n".join(task_content),
                    "summary": task_match.group(2).strip()
                })
                i = j
            else:
                i += 1

    return sections

def list_tasks(project_name=None, column_filter=None):
    slug, kanban_path = resolve_kanban_path(project_name)
    with open(kanban_path, "r", encoding="utf-8") as f:
        content = f.read()

    sections = parse_kanban_sections(content)
    print(f"=== Project: {slug.upper()} ({kanban_path}) ===\n")

    for sec in sections:
        if column_filter and column_filter.lower() not in sec["title"].lower() and column_filter.lower() not in sec["header"].lower():
            continue
        print(f"{sec['header']} ({len(sec['tasks'])} items)")
        if not sec["tasks"]:
            print("  (empty)")
        for idx, task in enumerate(sec["tasks"], 1):
            clean_summary = re.sub(r"@\{\d{4}-\d{2}-\d{2}\}\s*", "", task["summary"])
            clean_summary = re.sub(r"\[\[.*?\|.*?\]\]", "", clean_summary).strip()
            print(f"  {idx}. {clean_summary}")
        print()

def move_task(project_name, task_query, target_column_name):
    slug, kanban_path = resolve_kanban_path(project_name)
    with open(kanban_path, "r", encoding="utf-8") as f:
        content = f.read()

    target_pattern = rf"(##\s*[^#\n]*?{re.escape(target_column_name)}[^#\n]*\n)"
    target_match = re.search(target_pattern, content, re.IGNORECASE)
    if not target_match:
        print(f"Error: Target column '{target_column_name}' not found in {kanban_path}", file=sys.stderr)
        sys.exit(1)

    lines = content.splitlines(keepends=True)
    task_start = -1
    task_end = -1
    matched_task_lines = []

    for i, line in enumerate(lines):
        if re.search(r"^\s*-\s*\[[ xX]\]\s*", line) and task_query.lower() in line.lower():
            task_start = i
            j = i + 1
            while j < len(lines):
                if lines[j].startswith("\t") or lines[j].startswith("   ") or lines[j].startswith("  -"):
                    j += 1
                else:
                    break
            task_end = j
            matched_task_lines = lines[task_start:task_end]
            break

    if task_start == -1:
        print(f"Error: Task matching query '{task_query}' not found in {kanban_path}", file=sys.stderr)
        sys.exit(1)

    # Format checkmark if moving to Done
    if "done" in target_column_name.lower():
        matched_task_lines[0] = re.sub(r"^(\s*-\s*\[)[ ](\])", r"\g<1>x\g<2>", matched_task_lines[0])
        today = datetime.now().strftime("%Y-%m-%d")
        if f"@{{{today}}}" not in matched_task_lines[0] and not re.search(r"@\{\d{4}-\d{2}-\d{2}\}", matched_task_lines[0]):
            matched_task_lines[0] = re.sub(r"^(\s*-\s*\[x\]\s*)", rf"\g<1>@{{{today}}} ", matched_task_lines[0])

    task_block = "".join(matched_task_lines).strip()
    new_lines = lines[:task_start] + lines[task_end:]
    new_content = "".join(new_lines)

    insertion_pattern = rf"(##\s*[^#\n]*?{re.escape(target_column_name)}[^#\n]*\n+)"
    new_content = re.sub(
        insertion_pattern,
        rf"\g<1>{task_block}\n\n",
        new_content,
        count=1,
        flags=re.IGNORECASE
    )

    with open(kanban_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"Successfully moved task in {slug} to '{target_column_name}':")
    print(f"  {task_block.splitlines()[0]}")

def add_task(project_name, task_text, target_column="Backlog"):
    slug, kanban_path = resolve_kanban_path(project_name)
    with open(kanban_path, "r", encoding="utf-8") as f:
        content = f.read()

    today = datetime.now().strftime("%Y-%m-%d")
    card_line = f"- [ ] @{{{today}}} {task_text.strip()}"

    insertion_pattern = rf"(##\s*[^#\n]*?{re.escape(target_column)}[^#\n]*\n+)"
    if not re.search(insertion_pattern, content, re.IGNORECASE):
        content += f"\n\n## 📋 {target_column}\n\n{card_line}\n"
    else:
        content = re.sub(insertion_pattern, rf"\g<1>{card_line}\n", content, count=1, flags=re.IGNORECASE)

    with open(kanban_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Added task to {slug} ({target_column}): {card_line}")

def main():
    parser = argparse.ArgumentParser(description="Universal Obsidian Kanban Backlog Helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    list_parser = subparsers.add_parser("list", help="List tasks from Kanban board")
    list_parser.add_argument("project", nargs="?", default=None, help="Project name (optional, auto-detected from cwd)")
    list_parser.add_argument("--column", help="Filter by column (e.g. Backlog, Next Up, In Progress)")

    # move
    move_parser = subparsers.add_parser("move", help="Move a task to another column")
    move_parser.add_argument("project", nargs="?", default=None, help="Project name (optional, auto-detected from cwd)")
    move_parser.add_argument("--task", required=True, help="Task query string or title snippet")
    move_parser.add_argument("--to", required=True, help="Target column name (e.g. 'In Progress', 'Done', 'Next Up')")

    # add
    add_parser = subparsers.add_parser("add", help="Add a new task to board")
    add_parser.add_argument("project", nargs="?", default=None, help="Project name (optional, auto-detected from cwd)")
    add_parser.add_argument("--task", required=True, help="Task description")
    add_parser.add_argument("--to", default="Backlog", help="Target column (default: Backlog)")

    args = parser.parse_args()

    if args.command == "list":
        list_tasks(args.project, args.column)
    elif args.command == "move":
        move_task(args.project, args.task, args.to)
    elif args.command == "add":
        add_task(args.project, args.task, args.to)

if __name__ == "__main__":
    main()

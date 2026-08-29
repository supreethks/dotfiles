#!/usr/bin/env python3
"""
list_with_prd_status.py
Lists all backlog (or Next Up) tasks for a project, annotating each with
whether a per-task PRD already exists.

Usage:
  python3 list_with_prd_status.py <project_slug> [--column "Backlog"|"Next Up"]

Output (one line per task):
  PRD_EXISTS   <prd_path>  :: <task_summary>
  NO_PRD       -           :: <task_summary>
"""

import os
import re
import sys
import subprocess

VAULT_PATH = "/Users/supreethks/docs/obsidian/main-vault"
PROJECTS_DIR = os.path.join(VAULT_PATH, "projects")
SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))


def slugify(text: str) -> str:
    text = re.sub(r"@\{\d{4}-\d{2}-\d{2}\}\s*", "", text)
    text = re.sub(r"\[\[.*?\]\]", "", text)
    text = re.sub(r"[^\w\s]", "", text)
    return text.lower().strip()


def first_words(text: str, n: int = 4) -> list:
    words = slugify(text).split()
    return [w for w in words if len(w) > 2][:n]


def find_prd(proj_dir: str, task_summary: str) -> str | None:
    keywords = first_words(task_summary, n=4)
    if not keywords:
        return None
    for fname in os.listdir(proj_dir):
        lower = fname.lower()
        if "prd" not in lower or fname == "PRD.md":
            continue
        matches = sum(1 for kw in keywords if kw in lower)
        if matches >= min(2, len(keywords)):
            return os.path.join(proj_dir, fname)
    return None


def get_proj_dir(project_slug: str) -> str:
    direct = os.path.join(PROJECTS_DIR, project_slug)
    if os.path.isdir(direct):
        return direct
    for d in os.listdir(PROJECTS_DIR):
        if d.lower() == project_slug.lower():
            return os.path.join(PROJECTS_DIR, d)
    raise FileNotFoundError(f"Project '{project_slug}' not found under {PROJECTS_DIR}")


def parse_kanban_tasks(kanban_path: str, column_filter: str) -> list:
    with open(kanban_path, encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()
    in_section = False
    tasks = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if re.match(r"^##\s+", line):
            section_title = re.sub(r"^##\s*[\U00010000-\U0010ffff\u2600-\u27ff\u2300-\u23ff]?\s*", "", line).strip()
            in_section = column_filter.lower() in section_title.lower()
        elif in_section:
            task_match = re.match(r"^\s*-\s*\[([ xX])\]\s*(.*)", line)
            if task_match and task_match.group(1) == " ":
                summary = task_match.group(2).strip()
                summary = re.sub(r"@\{\d{4}-\d{2}-\d{2}\}\s*", "", summary)
                summary = re.sub(r"\[\[.*?\|.*?\]\]", "", summary).strip()
                tasks.append(summary)
        i += 1
    return tasks


def main():
    if len(sys.argv) < 2:
        print("Usage: list_with_prd_status.py <project_slug> [--column <col>]", file=sys.stderr)
        sys.exit(2)

    project_slug = sys.argv[1]
    column = "Backlog"
    if "--column" in sys.argv:
        idx = sys.argv.index("--column")
        column = sys.argv[idx + 1]

    proj_dir = get_proj_dir(project_slug)
    kanban_path = os.path.join(proj_dir, "Kanban.md")

    tasks = parse_kanban_tasks(kanban_path, column)
    if not tasks:
        print(f"(No open tasks in '{column}')")
        return

    for task in tasks:
        prd_path = find_prd(proj_dir, task)
        if prd_path:
            print(f"PRD_EXISTS   {prd_path}  :: {task}")
        else:
            print(f"NO_PRD       -           :: {task}")


if __name__ == "__main__":
    main()

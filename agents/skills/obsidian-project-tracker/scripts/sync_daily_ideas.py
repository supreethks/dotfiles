#!/usr/bin/env python3
"""
sync_daily_ideas.py
Scans daily journal files for `#project-tag` entries and syncs them automatically
into the respective project's Kanban board under `## 📋 Backlog`.
"""

import os
import re
import glob

VAULT_PATH = "/Users/supreethks/docs/obsidian/main-vault"
PROJECTS_DIR = os.path.join(VAULT_PATH, "projects")
JOURNAL_DIR = os.path.join(VAULT_PATH, "journal")

PROCESSED_MARKER = "📥"

def get_project_kanbans():
    """Dynamically maps tags (e.g. #vimark, #yorely, #kagga) to Kanban board filepaths."""
    tag_map = {}
    if not os.path.exists(PROJECTS_DIR):
        return tag_map

    for item in os.listdir(PROJECTS_DIR):
        item_path = os.path.join(PROJECTS_DIR, item)
        if os.path.isdir(item_path):
            kanban_path = os.path.join(item_path, "Kanban.md")
            if os.path.isfile(kanban_path):
                clean_tag = f"#{item.lower()}"
                tag_map[clean_tag] = kanban_path
                # Add aliases if needed (e.g. #eink -> eink-templates)
                if "-" in item:
                    tag_map[f"#{item.replace('-', '').lower()}"] = kanban_path

    # Common aliases
    if "#einktemplates" in tag_map:
        tag_map["#eink"] = tag_map["#einktemplates"]
        tag_map["#supernote"] = tag_map["#einktemplates"]

    return tag_map

def sync_daily_ideas():
    tag_map = get_project_kanbans()
    journal_files = glob.glob(os.path.join(JOURNAL_DIR, "*.md"))
    total_imported = 0

    for fpath in journal_files:
        with open(fpath, "r", encoding="utf-8") as f:
            lines = f.readlines()

        file_modified = False
        fname = os.path.basename(fpath).replace(".md", "")
        date_match = re.search(r"(\d{4}-\d{2}-\d{2})", fname)
        date_badge = f"@{{{date_match.group(1)}}} " if date_match else ""

        for i in range(len(lines)):
            line = lines[i]
            if PROCESSED_MARKER in line:
                continue

            matched_tag = None
            for tag in tag_map:
                if re.search(rf"(?:^|\s){re.escape(tag)}(?:\b|\s|$)", line, re.IGNORECASE):
                    matched_tag = tag.lower()
                    break

            if not matched_tag:
                continue

            target_kanban_path = tag_map[matched_tag]
            if not os.path.exists(target_kanban_path):
                continue

            # Clean line of tag and bullet prefixes
            clean_title = re.sub(rf"(?:^|\s){re.escape(matched_tag)}(?:\b|\s|$)", " ", line, flags=re.IGNORECASE)
            clean_title = re.sub(r"^\s*[-*]\s*(?:\[[ xX]\]\s*)?", "", clean_title).strip()
            if not clean_title:
                clean_title = "Untitled Idea"

            # Lookahead for attached images / sub-bullets
            extra_lines = []
            j = i + 1
            while j < len(lines):
                next_line = lines[j]
                if next_line.strip() == "" or re.match(r"^#{1,6}\s", next_line) or re.match(r"^\s*[-*]\s*\[[ xX]\]", next_line):
                    break
                if re.search(r"!\[.*\]\(.*\)|\!\[\[.*\]\]", next_line) or next_line.startswith(" ") or next_line.startswith("\t"):
                    extra_lines.append(next_line.strip())
                    j += 1
                else:
                    break

            with open(target_kanban_path, "r", encoding="utf-8") as kf:
                kanban_content = kf.read()

            # Deduplication
            if clean_title in kanban_content:
                lines[i] = lines[i].rstrip("\n") + f" {PROCESSED_MARKER}\n"
                file_modified = True
                continue

            card_text = f"- [ ] {date_badge}{clean_title} [[journal/{fname}|📅]]"
            if extra_lines:
                card_text += "\n\t" + "\n\t".join(extra_lines)

            backlog_pattern = r"(##\s*(?:📋\s*)?(?:Feature\s+)?Backlog\s*\n)"
            if re.search(backlog_pattern, kanban_content, re.IGNORECASE):
                kanban_content = re.sub(backlog_pattern, rf"\g<1>\n{card_text}\n", kanban_content, count=1, flags=re.IGNORECASE)
            else:
                kanban_content += f"\n\n## 📋 Backlog\n\n{card_text}\n"

            with open(target_kanban_path, "w", encoding="utf-8") as kf:
                kf.write(kanban_content)

            lines[i] = lines[i].rstrip("\n") + f" {PROCESSED_MARKER}\n"
            file_modified = True
            total_imported += 1
            print(f"Added to {matched_tag}: {date_badge}{clean_title}")

        if file_modified:
            with open(fpath, "w", encoding="utf-8") as f:
                f.writelines(lines)

    print(f"Sync complete. Imported {total_imported} idea(s).")

if __name__ == "__main__":
    sync_daily_ideas()

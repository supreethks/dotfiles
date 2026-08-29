#!/usr/bin/env python3
"""
check_prd.py
Checks whether a per-task PRD file already exists in the project vault folder.

Usage:
  python3 check_prd.py <project_slug> "<task_snippet>"

Output (stdout):
  FOUND: <absolute_path_to_prd>   — if a PRD exists
  NOT_FOUND                        — if no PRD exists yet

Exit codes: 0 (found), 1 (not found), 2 (error)
"""

import os
import re
import sys

VAULT_PATH = "/Users/supreethks/docs/obsidian/main-vault"
PROJECTS_DIR = os.path.join(VAULT_PATH, "projects")


def slugify(text: str) -> str:
    """Convert task text to a comparable lowercase slug."""
    text = re.sub(r"@\{\d{4}-\d{2}-\d{2}\}\s*", "", text)
    text = re.sub(r"\[\[.*?\]\]", "", text)
    text = re.sub(r"[^\w\s]", "", text)
    return text.lower().strip()


def first_words(text: str, n: int = 6) -> list[str]:
    """Return first N significant words from text."""
    words = slugify(text).split()
    return [w for w in words if len(w) > 2][:n]


def find_prd(project_slug: str, task_snippet: str) -> str | None:
    """Return path to matching PRD file, or None."""
    proj_dir = os.path.join(PROJECTS_DIR, project_slug)
    if not os.path.isdir(proj_dir):
        # Case-insensitive lookup
        for d in os.listdir(PROJECTS_DIR):
            if d.lower() == project_slug.lower():
                proj_dir = os.path.join(PROJECTS_DIR, d)
                break
        else:
            return None

    keywords = first_words(task_snippet, n=4)
    if not keywords:
        return None

    for fname in os.listdir(proj_dir):
        lower = fname.lower()
        if "prd" not in lower:
            continue
        # Skip the root PRD.md (the master document)
        if fname == "PRD.md":
            continue
        # Count how many keywords match the filename
        matches = sum(1 for kw in keywords if kw in lower)
        if matches >= min(2, len(keywords)):
            return os.path.join(proj_dir, fname)

    return None


def main():
    if len(sys.argv) < 3:
        print("Usage: check_prd.py <project_slug> \"<task_snippet>\"", file=sys.stderr)
        sys.exit(2)

    project_slug = sys.argv[1]
    task_snippet = sys.argv[2]

    result = find_prd(project_slug, task_snippet)
    if result:
        print(f"FOUND: {result}")
        sys.exit(0)
    else:
        print("NOT_FOUND")
        sys.exit(1)


if __name__ == "__main__":
    main()

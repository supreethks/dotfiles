#!/usr/bin/env python3
import os
import sys
import argparse
from datetime import datetime

VAULT_PROJECTS_DIR = "/Users/supreethks/docs/obsidian/main-vault/projects"

def create_project(slug, display_title=None, description=None, tech_stack=""):
    slug = slug.strip().lower().replace(" ", "-")
    display_title = display_title or slug.capitalize()
    description = description or "Project workspace and tracking."
    today = datetime.now().strftime("%Y-%m-%d")

    project_dir = os.path.join(VAULT_PROJECTS_DIR, slug)
    os.makedirs(project_dir, exist_ok=True)

    # 1. Master Dashboard (<slug>.md)
    dashboard_path = os.path.join(project_dir, f"{slug}.md")
    if not os.path.exists(dashboard_path):
        dashboard_content = f"""---
aliases:
  - "{display_title}"
  - "{display_title} Overview"
tags:
  - project
  - active
status: In Progress
created: {today}
tech_stack: "{tech_stack}"
---

# {display_title}

> {description}

## 📊 Overview & Metadata
- **Status**: `In Progress`
- **Tech Stack**: {tech_stack or 'TBD'}
- **Target Release**: TBD
- **Core KPIs**: TBD

---

## 🧭 Navigation & Modules
- 📋 [[projects/{slug}/Kanban|Task Board (Kanban)]]
- 📄 [[projects/{slug}/PRD|Product Requirements Document (PRD)]]
- 🏛️ [[projects/{slug}/Decisions|Architectural Decisions (ADR)]]
- 🐞 [[projects/{slug}/Issues|Known Issues & Tech Debt]]
- 🪵 [[projects/{slug}/Work_Log|Full Work Log]]

---

## 📌 Active Kanban Board
![[projects/{slug}/Kanban]]

---

## 📝 Recent Work Sessions
![[projects/{slug}/Work_Log#Recent Sessions]]
"""
        with open(dashboard_path, "w", encoding="utf-8") as f:
            f.write(dashboard_content)
        print(f"Created: {dashboard_path}")

    # 2. Kanban.md
    kanban_path = os.path.join(project_dir, "Kanban.md")
    if not os.path.exists(kanban_path):
        kanban_content = f"""---
kanban-plugin: board
---

## 📋 Backlog



## 🎯 Next Up



## 🚧 In Progress



## 🧪 Review / Verification



## ✅ Done



***

## 📚 Notes & Links
- [[projects/{slug}/{slug}|{display_title} Dashboard]]
- [[projects/{slug}/PRD|PRD]]


%% kanban:settings
```
{{"kanban-plugin":"board","list-collapse":[false,false,false,false,false,false]}}
```
%%
"""
        with open(kanban_path, "w", encoding="utf-8") as f:
            f.write(kanban_content)
        print(f"Created: {kanban_path}")

    # 3. PRD.md
    prd_path = os.path.join(project_dir, "PRD.md")
    if not os.path.exists(prd_path):
        prd_content = f"""---
aliases:
  - "{display_title} PRD"
tags:
  - prd
  - {slug}
---

# {display_title} — Product Requirements Document

## 1. Problem Statement & Objective
- **Problem**: 
- **Objective**: 

## 2. Target Audience & Personas
- 

## 3. Core Features & Functional Requirements
- [ ] 

## 4. Non-Goals / Out of Scope
- 

## 5. Success Metrics & KPIs
- 
"""
        with open(prd_path, "w", encoding="utf-8") as f:
            f.write(prd_content)
        print(f"Created: {prd_path}")

    # 4. Decisions.md
    decisions_path = os.path.join(project_dir, "Decisions.md")
    if not os.path.exists(decisions_path):
        decisions_content = f"""---
aliases:
  - "{display_title} Decisions"
  - "{display_title} ADR"
tags:
  - adr
  - decisions
  - {slug}
---

# {display_title} — Architecture Decision Records (ADR)

*Record major technical, product, and architecture decisions to maintain context across sessions.*

---

### [ADR-001] Project Initialization & Structure
- **Date**: {today}
- **Context**: Setting up standardized agent-driven project tracking in Obsidian.
- **Decision**: Use dedicated folder structure with Kanban, PRD, Decisions, and Work Log.
- **Consequences**: Standardized cross-agent context retention and frictionless navigation.
"""
        with open(decisions_path, "w", encoding="utf-8") as f:
            f.write(decisions_content)
        print(f"Created: {decisions_path}")

    # 5. Work_Log.md
    worklog_path = os.path.join(project_dir, "Work_Log.md")
    if not os.path.exists(worklog_path):
        worklog_content = f"""---
aliases:
  - "{display_title} Work Log"
tags:
  - worklog
  - {slug}
---

# Work Log — {display_title}

## Recent Sessions

### {today} — Project Setup & Workspace Initialization
- **Goal**: Establish project directory and tracking files
- **Changes Implemented**: Scaffolded master dashboard, Kanban board, PRD, ADR ledger, and issues tracker
- **Next Steps**: Begin feature backlog grooming

---

## Archive / Past Sessions
"""
        with open(worklog_path, "w", encoding="utf-8") as f:
            f.write(worklog_content)
        print(f"Created: {worklog_path}")

    # 6. Issues.md
    issues_path = os.path.join(project_dir, "Issues.md")
    if not os.path.exists(issues_path):
        issues_content = f"""---
aliases:
  - "{display_title} Issues"
tags:
  - issues
  - tech-debt
  - {slug}
---

# {display_title} — Known Issues & Tech Debt

## 🔴 Critical / Active Bugs
- 

## 🟡 Technical Debt & Refactoring
- 

## 🟢 Resolved
- 
"""
        with open(issues_path, "w", encoding="utf-8") as f:
            f.write(issues_content)
        print(f"Created: {issues_path}")

    print(f"Successfully configured project '{slug}' at {project_dir}")

def main():
    parser = argparse.ArgumentParser(description="Scaffold a project tracker in Obsidian main vault.")
    parser.add_argument("slug", help="Project slug (e.g. vimark, yorely, kagga)")
    parser.add_argument("--title", help="Display title (e.g. 'ViMark Desktop App')")
    parser.add_argument("--desc", help="Short project description")
    parser.add_argument("--tech", help="Tech stack summary", default="")
    args = parser.parse_args()

    create_project(args.slug, args.title, args.desc, args.tech)

if __name__ == "__main__":
    main()

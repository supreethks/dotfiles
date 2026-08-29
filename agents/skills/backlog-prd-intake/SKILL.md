---
name: backlog-prd-intake
description: >-
  Grills the user on every backlog item to collect detailed requirements, then
  writes a per-task PRD file and moves the task to "Next Up". On subsequent
  runs, skips items that already have a PRD and immediately starts implementing
  "Next Up" items in order. Activate when the user says "let's work on the
  backlog", "grill me on backlog", "burn down Next Up", or starts any ViMark
  feature session.
---

# Backlog PRD Intake & Burn-Down Skill

This skill operates in **two mutually exclusive modes** detected automatically at the start of every session:

```
Mode A — INTAKE:   Backlog has items without PRDs  →  Grill user, write PRD, move to Next Up
Mode B — EXECUTE:  Next Up has items with PRDs      →  Implement them top-to-bottom
```

---

## Step 0 — Detect Project & Mode

```bash
# 1. Resolve project slug (auto-detect or ask)
python3 /Users/supreethks/.agents/skills/obsidian-project-tracker/scripts/backlog_helper.py list vimark --column "Backlog"

# 2. Annotate backlog with PRD status
python3 /Users/supreethks/.agents/skills/backlog-prd-intake/scripts/list_with_prd_status.py vimark --column "Backlog"

# 3. Check Next Up for ready-to-implement items
python3 /Users/supreethks/.agents/skills/backlog-prd-intake/scripts/list_with_prd_status.py vimark --column "Next Up"
```

**Decision logic:**
- If any Backlog tasks output `NO_PRD` → **Mode A** for those items.
- If Backlog is empty or all items have PRDs, and Next Up has `PRD_EXISTS` items → **Mode B**.
- If both lists are empty → report to user; session complete.

---

## Mode A — Intake: Grill → Write PRD → Move to Next Up

### A1. Present tasks needing a PRD

Show the user the list of `NO_PRD` tasks numbered. Ask which one to start with, or offer to go through them all in order.

### A2. Grill Interview (per task)

For each selected task, conduct a structured interview. Ask **one group at a time** — do NOT dump all questions at once. Wait for answers, then probe deeper if the answer is vague.

#### Group 1 — User Experience & Interaction Flow
- Walk me through the exact user journey: what triggers this feature, what happens step by step?
- What UI states exist: idle / loading / empty / success / error? How do they look?
- Any keyboard shortcuts, window behavior, or focus rules?
- Where in the app does this live? New screen, modal, existing panel, background task?

#### Group 2 — Edge Cases & Failure Modes
- What happens if the input is missing, malformed, or too long?
- What happens on network timeout, DB unavailability, or permission denied?
- Any platform-specific constraints (macOS global shortcuts, Tauri window levels, Chrome extension CSP)?
- Is there any state that must survive app restart?

#### Group 3 — Architecture & Technical Alignment

> [!IMPORTANT]
> **MANDATORY BEFORE GROUP 3**: Read the source code first. Answer all architecture questions yourself from the code. DO NOT ask the user about implementation details that are discoverable in the repo. Only raise a Group 3 question if it cannot be resolved from reading the code, `Decisions.md`, or `PRD.md`.
>
> For ViMark, always read at minimum:
> - `repo/src-tauri/src/lib.rs` — Tauri setup, shortcut registration, window management
> - `repo/src-tauri/src/native/protocol.rs` — Chrome native messaging / launch mechanism
> - `repo/src-tauri/src/commands/` — Tauri IPC commands
> - `repo/src/` or `repo/apps/` — React frontend entry points and relevant components

- What layers change based on what the code shows (Rust / SQLite / React / Extension)?
- Any third-party APIs or system integrations involved (read Cargo.toml / package.json)?
- Does this touch sync, keychain, or the extension bridge (read relevant modules)?
- Review `Decisions.md` — does the proposed approach conflict with any existing ADR?
- Only ask the user if the answer is genuinely ambiguous after reading the code.

#### Group 4 — Verification & Acceptance Criteria
- How will we know this feature is done and correct?
- Which automated tests are needed (unit, integration, Playwright e2e)?
- Is manual device/webview verification required?
- What's the "Definition of Done" — exact observable behaviors?

### A3. Write Per-Task PRD File

After grilling, create a PRD file strictly inside the project vault folder.

**File naming**: `YYYYMMDD - PRD - <short-slug>.md`  
Example: `20260827 - PRD - global-shortcut-always-on.md`

**PRD Template** (fill every section — no blanks):

```markdown
---
created_by: agent
date: YYYY-MM-DD
task_source: "<original backlog task text verbatim>"
---

# PRD: <Feature Title>

## 1. Problem Statement
<One paragraph: what pain does this solve and for whom?>

## 2. User Journey
<Numbered step-by-step flow from trigger to completion>

## 3. UI States & Behavior
| State | Trigger | Visual / Behavior |
|-------|---------|-------------------|
| idle  | ...     | ...               |
| ...   | ...     | ...               |

## 4. Edge Cases & Failure Handling
- **<Scenario>**: <Expected behavior>
- ...

## 5. Architecture & Technical Scope
- **Layers touched**: <Rust / SQLite / React / Extension / Native Messaging>
- **New Tauri commands**: <list if any>
- **DB schema changes**: <describe if any>
- **ADR alignment**: <reference any relevant ADR from Decisions.md>

## 6. Acceptance Criteria
- [ ] <Exact, testable behavior 1>
- [ ] <Exact, testable behavior 2>
- ...

## 7. Test Plan
- **Unit tests**: <what to test>
- **Integration / e2e**: <Playwright or Tauri webview tests>
- **Manual verification**: <steps to verify in the running app>

## 8. Out of Scope
- <Explicitly excluded items>
```

### A4. Move Task to Next Up

```bash
python3 /Users/supreethks/.agents/skills/obsidian-project-tracker/scripts/backlog_helper.py move vimark \
  --task "<task_snippet>" --to "Next Up"
```

Update the Kanban task line to append a link to the PRD:
- Append `[[projects/vimark/YYYYMMDD - PRD - <slug>|📋 PRD]]` to the task line in `Kanban.md`.

Then continue to the next `NO_PRD` task, or stop and report to user if all are done.

---

## Mode B — Execute: Burn Down Next Up

When Next Up contains tasks annotated `PRD_EXISTS`:

1. **Pick the top item** (highest in the list).
2. **Read the PRD file** fully before writing any code.
3. **Follow the vimark feature workflow** (branch hygiene, implementation, adversarial review, PR) as defined in the `obsidian-project-tracker` skill Stage 3–5.
4. After PR is opened, move task to Done:
   ```bash
   python3 /Users/supreethks/.agents/skills/obsidian-project-tracker/scripts/backlog_helper.py move vimark \
     --task "<task_snippet>" --to "Done"
   ```
5. Repeat for the next Next Up item until the list is empty.

---

## PRD File Location Rule

All per-task PRD files MUST be placed in:
```
/Users/supreethks/docs/obsidian/main-vault/projects/vimark/
```

Never write PRDs to any other vault location. Filename MUST start with `YYYYMMDD - PRD - `.

---

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `scripts/check_prd.py <project> "<task>"` | Returns `FOUND: <path>` or `NOT_FOUND` |
| `scripts/list_with_prd_status.py <project> [--column <col>]` | Lists tasks annotated with PRD status |

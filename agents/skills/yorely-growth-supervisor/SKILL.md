---
name: yorely-growth-supervisor
description: >-
  Orchestrate Yorely daily growth passes as a thin supervisor only — read
  HANDOFF.md, delegate Statsig pulls, funnel analysis, platform ideas, and
  Obsidian updates to Herdr pane agents (gh-statsig, gh-analyze, gh-android,
  gh-ios, gh-obsidian), then overwrite HANDOFF.md and close panes. Use when
  the user asks to run the growth supervisor, growth hack Yorely, daily growth
  pass, AGENT_LOOP_TICK_yorely_growth, or when starting a fresh Composer
  session for recurring Yorely growth work. Requires HERDR_ENV=1.
---

# Yorely Growth Supervisor

Thin orchestrator for daily Yorely growth loops. **Do not** pull Statsig, analyze funnels, write Obsidian notes, or sketch implementations in the supervisor pane.

## Prerequisites

1. `test "${HERDR_ENV:-}" = 1` — if false, stop and tell the user to run inside Herdr.
2. Read `/Users/supreethks/development/project-yorely/repo/data/growth/HANDOFF.md` first (ignore prior chat).
3. For Herdr pane/agent commands, follow the `herdr` skill.

## Paths

| What | Path |
|------|------|
| Repo root | `/Users/supreethks/development/project-yorely/repo` |
| HANDOFF (overwrite each pass) | `repo/data/growth/HANDOFF.md` |
| Growth data | `repo/data/growth/` |
| Obsidian project | `/Users/supreethks/docs/obsidian/main-vault/projects/yorely/` |
| Runbook | `projects/yorely/20260901 - Growth Supervisor Runbook.md` |

## Agent roster — delegate all substantive work

| Agent | When | Output |
|-------|------|--------|
| `gh-statsig` | Every pass | `repo/data/growth/statsig_7d_summary_YYYYMMDD.json` |
| `gh-analyze` | After statsig | `repo/data/growth/analysis_YYYYMMDD.md` |
| `gh-android` | Triggered (see below) | `repo/data/growth/subagent_android_YYYYMMDD.md` |
| `gh-ios` | Triggered (see below) | `repo/data/growth/subagent_ios_YYYYMMDD.md` |
| `gh-obsidian` | After analyze (always) | Vault updates + PRD files + PRD-linked Kanban cards + `Work_Log.md` prepend |

Spawn `gh-android` / `gh-ios` when **any** of: funnel event count shifts >20% vs prior baseline; new stuck journey in analyze output; platform split changes materially.

## Supervisor checklist

```
- [ ] Read HANDOFF.md
- [ ] Spawn gh-statsig → wait → confirm baseline JSON
- [ ] Spawn gh-analyze → wait → read analysis for platform trigger
- [ ] Spawn gh-android / gh-ios if triggered (parallel OK)
- [ ] Spawn gh-obsidian with analysis (+ subagent paths if any)
- [ ] Overwrite HANDOFF.md (summary + next actions only)
- [ ] Close all temporary panes/tabs
```

Supervisor reads **output files**, not agent scrollback.

## Spawn pattern

```bash
herdr pane split --current --direction right --cwd "/Users/supreethks/development/project-yorely/repo" --no-focus
# pane id from .result.pane.pane_id

herdr agent start gh-statsig --kind cursor --pane <id>
herdr agent prompt gh-statsig "<task from reference.md>" --wait --timeout 300000
herdr pane close <id>
```

Repeat for each agent. Platform agents: split two panes (`right` + `down`), run in parallel, close both.

## What the supervisor must NOT do

- Call Statsig MCP directly
- Write analysis notes or Kanban items
- Implement app features
- Carry prior chat context into decisions

## Daily loop

```
/loop 1d /yorely-growth-supervisor
```

Or explicit prompt: read HANDOFF, run this skill, overwrite HANDOFF when done.

## Agent prompts and HANDOFF template

See [reference.md](reference.md).

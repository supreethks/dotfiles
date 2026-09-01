# Yorely Growth Supervisor — Reference

## gh-statsig prompt

```
Pull Statsig events via MCP Query_Logs_Explorer (source=events, max 7d window).
Paginate until has_more=false (cap 500). Record start_ts/end_ts in ms UTC.
Unfiltered pagination works; event_name filters often return empty.
Write repo/data/growth/statsig_7d_summary_YYYYMMDD.json with:
- window, event_count, unique_users, platform split (sdk_type)
- per-event counts
Optional: aggregate pages with python3 repo/scripts/growth/aggregate_statsig_events.py
Reply with file path only.
```

## gh-analyze prompt

```
Read repo/data/growth/statsig_7d_summary_YYYYMMDD.json and prior baseline path from HANDOFF.md.
Group sessions by user_id, sort by timestamp.
Flag canonical stuck journey: skip → demo dashboard → paywall_dismissed without checkout/peek.
Write funnel table + % diff vs baseline to repo/data/growth/analysis_YYYYMMDD.md.
End with: RUN_PLATFORM_AGENTS: yes|no and reason.
Reply with file path only.
```

## gh-android prompt

```
You are a Yorely Android growth analyst.
Repo: /Users/supreethks/development/project-yorely/repo/android
Read ONLY analytics code (data/analytics/*.kt).
Evidence: <paste 3-5 bullets from analysis_YYYYMMDD.md>.
Propose ranked growth ideas: problem, hypothesis, implementation sketch (files), success metric, effort S/M/L.
Write repo/data/growth/subagent_android_YYYYMMDD.md only. Reply with path only.
```

## gh-ios prompt

```
You are a Yorely iOS growth analyst.
Repo: /Users/supreethks/development/project-yorely/repo/ios
Read ONLY Services/Analytics/*.swift.
Evidence: <paste 3-5 bullets from analysis_YYYYMMDD.md>.
Propose ranked growth ideas: problem, hypothesis, implementation sketch (files), success metric, effort S/M/L.
Write repo/data/growth/subagent_ios_YYYYMMDD.md only. Reply with path only.
```

## gh-obsidian prompt

```
Read repo/data/growth/analysis_YYYYMMDD.md and any subagent_*.md from this pass.
Vault: /Users/supreethks/docs/obsidian/main-vault/projects/yorely/
Update or create YYYYMMDD - Growth Hacking Analysis.md.
Prepend Work_Log.md session entry.

Kanban / backlog policy (mandatory):
- NEVER add short one-line backlog cards with inline descriptions, effort tags, or file paths.
- For each new backlog item: write a detailed PRD file FIRST, then add a Kanban card that links ONLY to that PRD.
- PRD path: projects/yorely/YYYYMMDD - PRD <Short Title>.md
- PRD front matter: created_by: agent, date, tags: [yorely, growth, prd]
- PRD sections (all required): Problem & evidence, Hypothesis, User journey & UX states, Functional requirements, Analytics & success metrics, Implementation scope (platform, files), Effort S/M/L, Out of scope
- Kanban card = title + wiki link only. Add via:
  python3 /Users/supreethks/.agents/skills/obsidian-project-tracker/scripts/backlog_helper.py add yorely --task "[[YYYYMMDD - PRD Short Title|Short Title]]"
- Promote max 3 PRD-linked cards to Next Up with backlog_helper move (do not copy PRD body onto the card).
- If a PRD already exists for an idea, link the existing note — do not duplicate.
Reply with PRD paths + Kanban changes only.
```

## Growth PRD template (gh-obsidian)

```markdown
---
created_by: agent
date: YYYY-MM-DD
tags:
  - yorely
  - growth
  - prd
---

# PRD: <Short Title>

## Problem & evidence
<Statsig funnel counts, stuck journey, platform split>

## Hypothesis
<What change will move the metric>

## User journey & UX
<Step-by-step flow, loading/empty/error states>

## Functional requirements
- [ ] ...

## Analytics & success metrics
<Events to add or watch; target delta>

## Implementation scope
| Platform | Files / modules |
|----------|-----------------|
| Android | ... |
| iOS | ... |

**Effort:** S | M | L

## Out of scope
- ...
```

## Key metrics

| Metric | Healthy direction |
|--------|-------------------|
| `onboarding_profile_created` / `onboarding_completed` | ↑ |
| `profile_created` / `dashboard_demo_add_profile_tapped` | ↑ |
| `timeline_peek_shown` / `dashboard_timeline_card_tapped` | ↑ |
| `begin_checkout` / `paywall_screen_viewed` | ↑ |
| iOS `app_opened` | ↑ week-over-week |

## HANDOFF.md overwrite template

Supervisor overwrites `repo/data/growth/HANDOFF.md` entirely each pass:

```markdown
# Yorely Growth Supervisor — HANDOFF

> Read this file first. Overwritten each pass. History in dated notes, Work_Log, statsig_7d_summary_*.json.

**Last pass:** YYYY-MM-DD
**Next pass due:** ~YYYY-MM-DD (+1d loop: AGENT_LOOP_TICK_yorely_growth)

## Role: supervisor = orchestrator only

Delegate via Herdr agents. Skill: yorely-growth-supervisor. Requires HERDR_ENV=1.

## Current baseline

| Metric | Value |
|--------|-------|
| Window | ... |
| Events | ... |
| Users | ... |
| Android / iOS | ... |

**Baseline file:** repo/data/growth/statsig_7d_summary_YYYYMMDD.json

## Where users get stuck

<one-line journey + key funnel counts>

## Next Up (Kanban)

<max 3 items from gh-obsidian pass>

## Agent roster

| Agent | When | Output path |
|-------|------|-------------|
| gh-statsig | Every pass | statsig_7d_summary_YYYYMMDD.json |
| gh-analyze | After statsig | analysis_YYYYMMDD.md |
| gh-android | If triggered | subagent_android_YYYYMMDD.md |
| gh-ios | If triggered | subagent_ios_YYYYMMDD.md |
| gh-obsidian | Always | vault updates |

## Next pass checklist (supervisor only)

1. Read HANDOFF + run yorely-growth-supervisor skill
2. gh-statsig → gh-analyze → (optional) platform agents → gh-obsidian
3. Overwrite HANDOFF.md
4. Close panes; no prior chat

## Pointers

| What | Where |
|------|-------|
| Skill | ~/.agents/skills/yorely-growth-supervisor/SKILL.md |
| Runbook | projects/yorely/20260901 - Growth Supervisor Runbook.md |
| Kanban | projects/yorely/Kanban.md |

## Loop prompt

Read repo/data/growth/HANDOFF.md. Run yorely-growth-supervisor skill. Delegate all work to Herdr agents. Overwrite HANDOFF when done.
```

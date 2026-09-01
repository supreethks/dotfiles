# git-cleanup

Automated, deterministic, non-destructive Git branch and worktree cleanup engine.

## Overview
- Scans repositories across the system (`~/development`, `~/Projects`, `~/dotfiles`, `~/scripts`, `~/Documents/dev`).
- **Priority 1 (Forgejo)**: If a Forgejo remote exists, queries Forgejo PR API.
- **Priority 2 (GitHub)**: If no Forgejo remote exists, queries GitHub PR API.
- **Safety checks**:
  - Only deletes local branches whose associated PR is confirmed merged (`merged == True` / `merged_at != null`).
  - Protects default branches (`main`, `master`, `develop`, etc.) and open PRs.
  - Never removes worktrees with uncommitted tracked changes (`M`, `A`, `D`, etc.) or untracked user files.
  - Safely prunes dangling worktrees and refreshes remote tracking refs.

## Files
- `cleanup.py`: Core cleanup engine.
- `run_cleanup.sh`: Cron and interactive execution wrapper.
- `logs/cleanup.log`: Paired standard output log.
- `logs/cleanup.err.log`: Paired error log.

## Scheduling
Configured in crontab to run on reboot and every 3 days at 03:00 AM:
```cron
@reboot /Users/supreethks/scripts/git-cleanup/run_cleanup.sh
0 3 */3 * * /Users/supreethks/scripts/git-cleanup/run_cleanup.sh
```

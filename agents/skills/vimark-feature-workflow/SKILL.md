---
name: vimark-feature-workflow
description: End-to-end delivery workflow for the ViMark desktop repo (Tauri + React) on Forgejo — start every change on a clean branch cut from `forgejo/develop` (or an isolated worktree when the current branch has uncommitted work), run the frontend/Rust/e2e checks that match PR CI, verify in the desktop app, backfill automated tests for what was verified by hand, then commit and open a PR against `develop`. Use this skill at the START of any coding task in a repo that has a `forgejo` git remote and `src-tauri/` (ViMark / velocity) — implementing a feature, fixing a bug, changing UI — even when the user only says "add X" or "fix Y" and never mentions branches, tests, or PRs. Also use it when the user asks to run tests, verify the app, or raise a PR for work already in progress.
---

# ViMark feature workflow

Delivery loop for this Forgejo-hosted Tauri app: **clean branch → implement → match CI → verify in the desktop app → automate that verification → PR**.

Branching first keeps unrelated in-flight work out of the PR. Verifying the running app before writing UI/e2e tests means the tests encode behaviour you observed, not behaviour you assumed.

## 0. Confirm this repo matches & Establish Context

```bash
git remote -v | grep forgejo    # Forgejo remote required
ls src-tauri package.json       # Tauri desktop app
```

No `forgejo` remote, or no `src-tauri/` — this skill does not apply. For Android/iOS Forgejo repos use `mobile-feature-workflow` instead.

**Obsidian Project Context & Backlog Intake**:
- Check `/Users/supreethks/docs/obsidian/main-vault/projects/vimark/` (`vimark.md`, `Kanban.md`, `PRD.md`).
- **If triggered by "let's work on the backlog"**:
  1. Pull backlog items (`python3 /Users/supreethks/.agents/skills/obsidian-project-tracker/scripts/backlog_helper.py list vimark --column "Backlog"`).
  2. Present the backlog tasks and ask the user to pick.
  3. **Conduct the Mandatory "Grill-Me" Interview**: Clarify exact UI/UX behaviour, keyboard shortcuts, error states, and Rust/TS contracts before cutting a branch.
  4. Move the task to `## 🚧 In Progress` in `Kanban.md`.

## 1. Start on a clean branch

**Always fetch first.** Local `develop` is often stale.

```bash
git fetch forgejo
git log --oneline HEAD..forgejo/develop | head
git log --oneline forgejo/develop..HEAD
```

Then pick one path:

**Clean tree, no unrelated commits** — branch directly:
```bash
git checkout -b <type>/<slug> forgejo/develop
```

**Uncommitted work on the current branch** — do not stash across a base change. Use an isolated worktree so the user's tree stays untouched:
```bash
git worktree add ../velocity-<slug> -b <type>/<slug> forgejo/develop
```
Call `move_agent_to_root` on the worktree path before editing. Tell the user the original checkout is untouched. Remove with `git worktree remove` after the PR is open and they confirm.

**Current branch carries unrelated in-flight commits** — commit your work, then replay only your commit(s):
```bash
git rebase --onto forgejo/develop <last-unrelated-commit> <your-branch>
git log --oneline forgejo/develop..HEAD   # expect only your commits
```

Branch naming follows existing history (`git log --oneline -20`): commonly `feat/`, `fix/`, `test/`, `chore/`, sometimes `claude/` or `feature/`.

## 2. Do the work

Keep changes scoped to the bug/feature. Prefer Nx-aware commands (`npm exec nx …` / `npx nx …`) over ad-hoc tooling when the workspace already wires the target.

Touching both frontend and Rust? Keep the contract aligned (commands in `generate_handler!`, capabilities permissions, TS invoke types).

## 3. Test what changed

Match `.forgejo/workflows/pr.yml` — green locally must mean the same checks the PR runs.

| Changed | Local command (mirrors CI) |
|---|---|
| Frontend (`src/`, shared UI) | `npx nx affected -t typecheck test build --base=forgejo/develop --head=HEAD` (or project-scoped `typecheck` / `vitest` / `vite build`) |
| Rust (`src-tauri/`) | `npm run build` then `cd src-tauri && cargo test --locked` |
| Extension / website workspace | `npx nx run <project>:test` / `:build` as applicable |
| Window / capture / mode flows | Playwright e2e under `e2e/` when those behaviours change |

If nothing testable changed (docs-only), say so and skip.

**Re-run after rebasing.** Tests that passed on the old base prove nothing about the tip you will push.

## 4. Verify in the desktop app

Automated tests miss Spotlight-style window sizing, focus/blur launcher behaviour, and native host capture. For any UI or window-behaviour change, run the app and exercise the flow:

```bash
npm run tauri dev
```

Prefer the Tauri MCP (`user-@hypothesi/tauri-mcp-server`) for webview screenshots, DOM snapshots, and IPC when available. Otherwise drive the palette manually (global shortcut, search, add/edit, hide-on-blur) and capture screenshots of each meaningful state.

Say where verification happened ("tauri dev on macOS", "e2e only") so the reviewer does not guess.

## 5. Backfill tests for what you verified

Manual verification is not the deliverable — encode it:

- Frontend behaviour → Vitest next to the component/hook (`*.test.tsx`)
- Window sizing / activation / capture → Playwright specs in `e2e/`
- Rust commands / search / DB → `cargo test` in `src-tauri`

Match neighbouring test style. If a behaviour cannot be automated (real browser native messaging, OS focus quirks), say so explicitly in the PR.

## 6. Commit and open the PR

Review the diff before staging. Commit message explains **why**; follow `git log -15` style (`fix(ui): …`, `feat(…): …`, `behavior: …`).

Push and open against `develop`:

```bash
git push -u forgejo HEAD
```

Forgejo's API is Gitea-compatible. Reuse the credential git already has — never echo it:

```bash
REMOTE_URL=$(git remote get-url forgejo)   # e.g. http://localhost:3300/owner/repo.git
# parse host, owner, repo from REMOTE_URL
CRED=$(printf 'protocol=http\nhost=<host:port>\n\n' | git credential fill 2>/dev/null)
U=$(printf '%s\n' "$CRED" | sed -n 's/^username=//p')
P=$(printf '%s\n' "$CRED" | sed -n 's/^password=//p')
curl -s -u "$U:$P" -X POST -H "Content-Type: application/json" \
  -d @pr.json \
  "http://<host:port>/api/v1/repos/<owner>/<repo>/pulls"
```

`pr.json`: `{"head","base":"develop","title","body"}`. Build the body with `json.dumps` from Markdown — do not hand-escape.

PR body must include: why the change is shaped this way, what was verified and how, and anything still needing a human decision.

Poll commit statuses and report the real result.

## 7. Sync Obsidian Project Tracker

Upon PR creation or task completion:
1. **Update Kanban**: Open `/Users/supreethks/docs/obsidian/main-vault/projects/vimark/Kanban.md` and move the completed task to `## ✅ Done`.
2. **Append Work Log**: Add a session summary to `/Users/supreethks/docs/obsidian/main-vault/projects/vimark/Work_Log.md` with goal, modified files, verification notes, and PR link.
3. **Record Decisions**: If an architectural choice was made, append an ADR entry in `/Users/supreethks/docs/obsidian/main-vault/projects/vimark/Decisions.md`.

## Reporting back

State: branch + base, which checks ran, desktop verification notes, tests added, PR URL + check status, and Obsidian docs updated. If a step was skipped, say so plainly.

## Additional resources

- Desktop verification details: [references/desktop-verification.md](references/desktop-verification.md)

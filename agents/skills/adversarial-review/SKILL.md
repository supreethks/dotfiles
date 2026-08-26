---
name: adversarial-review
description: Multi-perspective adversarial code review and self-healing review loop based on git diffs. Dynamically dispatches specialized stack reviewers (Rust backend, Tauri frontend, Desktop OS, Browser Extensions, Mobile Native, Cloudflare Sync, Security, and Architecture) located directly in ~/.agents/skills/adversarial-review/prompts/. Use before committing changes, opening PRs, or when the user asks to "review changes", "run adversarial review", or "check diff".
disable-model-invocation: true
---

# Adversarial Code Review Skill

This skill orchestrates stack-aware, multi-persona adversarial reviews on code changes using self-contained review personas and runner scripts in `~/.agents/skills/adversarial-review/`.

It acts as an automated quality gate to catch security risks, concurrency bugs, edge-case panics, architecture leaks, and platform-specific regressions before changes are committed or PRs are opened.

---

## 1. How It Works

1. **Diff Inspection**: Computes the patch against the base branch or commit (default `HEAD~1` or `forgejo/develop` / `origin/main`).
2. **Stack-Aware Persona Dispatch**: Selects specialized reviewers based on modified file paths:
   - `.rs`, `Cargo.toml` → `reviewer_rust_backend.txt`
   - `src-tauri/`, `tauri.conf.json` → `reviewer_tauri_frontend.txt`, `reviewer_desktop_os.txt`
   - `extension/`, `manifest.json` → `reviewer_extension_crossbrowser.txt`
   - `android/`, `ios/`, `.kt`, `.swift` → `reviewer_mobile_native.txt`
   - `workers/`, `wrangler.jsonc`, `sync/` → `reviewer_cloudflare_sync.txt`
   - Global fallback / Security gate → `reviewer_sec.txt`, `reviewer_arch.txt`
3. **Approval Verdict**: Reviewers evaluate the patch in parallel. If all reviewers output `VERDICT: APPROVED`, the gate passes.
4. **Auto-Healing**: If issues are found, actionable feedback is fed back to the agent to fix the code, re-test, and re-evaluate.

---

## 2. Reviewer Personas Reference

All prompt personas are version-controlled in `~/.agents/skills/adversarial-review/prompts/`:

| Persona File | Scope & Focus Areas |
|---|---|
| `reviewer_sec.txt` | Security regressions, unhandled panics/unwraps, injection vectors, socket/memory leaks. |
| `reviewer_arch.txt` | Clean architecture, abstraction boundaries, maintainability, separation of concerns. |
| `reviewer_rust_backend.txt` | Memory safety, locking/deadlocks, async runtime blocking, error handling, SQLite/Tantivy patterns. |
| `reviewer_tauri_frontend.txt` | Tauri IPC safety, capability permissions, CSP adherence, window state synchronization. |
| `reviewer_desktop_os.txt` | Native macOS/Windows quirks, window activation, focus stealing, multi-monitor coordinates. |
| `reviewer_extension_crossbrowser.txt` | Manifest V3 lifecycle, minimal permissions, background worker wakeups, native messaging. |
| `reviewer_mobile_native.txt` | Android/iOS lifecycle, background execution limits, memory footprint, dual-install qualifiers. |
| `reviewer_cloudflare_sync.txt` | Workers/Durable Objects concurrency, edge caching, WebSocket alarms, transaction isolation. |

---

## 3. Execution Workflows

### Option A: Shell Script Execution (Fast & Autonomous)

Run dynamic stack review against a base branch:
```bash
~/.agents/skills/adversarial-review/scripts/herdr-dynamic-review.sh [base_ref]
```

Run autonomous multi-round self-healing loop:
```bash
~/.agents/skills/adversarial-review/scripts/herdr-auto-loop.sh [base_ref]
```

### Option B: In-Session Parallel Subagents (Interactive)

When performing in-depth reviews inside an active pair programming session:
1. Identify modified files (`git diff --name-only <base_ref> --`).
2. Read the matching prompt files from `~/.agents/skills/adversarial-review/prompts/`.
3. Launch parallel reviewer subagents passing the git diff.
4. Collect verdicts:
   - If all approved: Proceed to PR / Commit.
   - If blockers flagged: Implement fixes and re-verify.

---

## 4. Integration with Feature Workflows & Obsidian

This skill is invoked during **Stage 4b (Adversarial Review Gate)** of the `obsidian-project-tracker` and `vimark-feature-workflow` lifecycles:

1. **Before Staging / Committing**:
   ```bash
   ~/.agents/skills/adversarial-review/scripts/herdr-dynamic-review.sh origin/develop
   ```
2. **Log Reviewer Sign-Off in Obsidian `Work_Log.md`**:
   ```markdown
   - **Adversarial Review**: ✔ Approved by `reviewer_rust_backend`, `reviewer_extension_crossbrowser`, `reviewer_sec`.
   ```

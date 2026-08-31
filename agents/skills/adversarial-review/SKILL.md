---
name: adversarial-review
description: Multi-perspective adversarial code review and self-healing review loop based on git diffs. Prompts the user to select their desired LLM agent CLI reviewer (agy, agy with claude model, cursor-agent, codex, or claude) and dynamically dispatches specialized stack reviewers (Rust backend, Tauri frontend, Desktop OS, Browser Extensions, Mobile Native, Cloudflare Sync, Security, and Architecture) located in ~/.agents/skills/adversarial-review/prompts/. Use before committing changes, opening PRs, or when the user asks to "review changes", "run adversarial review", or "check diff".
disable-model-invocation: true
---

# Adversarial Code Review Skill

This skill orchestrates stack-aware, multi-persona adversarial reviews on code changes using self-contained review personas and runner scripts in `~/.agents/skills/adversarial-review/`.

It acts as an automated quality gate to catch security risks, concurrency bugs, edge-case panics, architecture leaks, and platform-specific regressions before changes are committed or PRs are opened.

---

## 1. Reviewer LLM Agent CLI Selection (MANDATORY)

Before initiating an adversarial review (either via runner scripts or in-session interactive subagents), **ALWAYS ask the user which LLM agent CLI they want to use as reviewers**:

| Runner Option | Description | CLI Command Pattern |
|---|---|---|
| **`agy`** | Google Antigravity CLI (Default Gemini model) | `echo "$DIFF" \| agy -p "$(cat "$PROMPT")" --no-context` |
| **`agy-claude`** | Google Antigravity CLI with Claude model | `echo "$DIFF" \| agy -m "Claude 3.7 Sonnet" -p "$(cat "$PROMPT")" --no-context` |
| **`cursor-agent`** | Cursor Agent CLI | `echo "$DIFF" \| cursor-agent -p "$(cat "$PROMPT")" --output-format text` |
| **`codex`** | Codex CLI | `echo "$DIFF" \| codex exec "$(cat "$PROMPT")"` |
| **`claude`** | Claude Code CLI | `echo "$DIFF" \| claude -p "$(cat "$PROMPT")"` |

> [!IMPORTANT]
> When executing interactively as an AI assistant in chat, prompt the user for their preferred LLM reviewer CLI (e.g. `agy`, `agy-claude`, `cursor-agent`, `codex`, `claude`) before running the review scripts or launching subagents, or pass their choice explicitly to the runner scripts.

---

## 2. How It Works

1. **Reviewer Selection**: User chooses the reviewer CLI (`agy`, `agy-claude`, `cursor-agent`, `codex`, `claude`).
2. **Diff Inspection**: Computes the patch against the base branch or commit (default `HEAD~1` or `forgejo/develop` / `origin/main`).
3. **Stack-Aware Persona Dispatch**: Selects specialized reviewers based on modified file paths:
   - `.rs`, `Cargo.toml` → `reviewer_rust_backend.txt`
   - `src-tauri/`, `tauri.conf.json` → `reviewer_tauri_frontend.txt`, `reviewer_desktop_os.txt`
   - `extension/`, `manifest.json` → `reviewer_extension_crossbrowser.txt`
   - `android/`, `.kt` → `reviewer_android.txt`
   - `ios/`, `.swift` → `reviewer_mobile_native.txt`
   - `workers/`, `wrangler.jsonc`, `sync/` → `reviewer_cloudflare_sync.txt`
   - Global fallback / Security gate → `reviewer_sec.txt`, `reviewer_arch.txt`
4. **Approval Verdict**: Reviewers evaluate the patch in parallel. If all reviewers output `VERDICT: APPROVED`, the gate passes.
5. **Auto-Healing**: If issues are found, actionable feedback is fed back to the builder agent to fix the code, re-test, and re-evaluate.

---

## 3. Reviewer Personas Reference

All prompt personas are version-controlled in `~/.agents/skills/adversarial-review/prompts/`:

| Persona File | Scope & Focus Areas |
|---|---|
| `reviewer_sec.txt` | Security regressions, unhandled panics/unwraps, injection vectors, socket/memory leaks. |
| `reviewer_arch.txt` | Clean architecture, abstraction boundaries, maintainability, separation of concerns. |
| `reviewer_rust_backend.txt` | Memory safety, locking/deadlocks, async runtime blocking, error handling, SQLite/Tantivy patterns. |
| `reviewer_tauri_frontend.txt` | Tauri IPC safety, capability permissions, CSP adherence, window state synchronization. |
| `reviewer_desktop_os.txt` | Native macOS/Windows quirks, window activation, focus stealing, multi-monitor coordinates. |
| `reviewer_extension_crossbrowser.txt` | Manifest V3 lifecycle, minimal permissions, background worker wakeups, native messaging. |
| `reviewer_android.txt` | Native Kotlin XML/Fragments/MVI companion: Share/`ACTION_SEND`, Keystore vs desktop Rust Argon2id/AES-GCM, WorkManager/Doze, Room LWW/dirty queue, R8 keep-rules, dual-install, exported components. Not Compose. |
| `reviewer_mobile_native.txt` | iOS (and shared mobile) lifecycle, background execution limits, memory footprint. Do not dispatch for `android/` / `*.kt`. |
| `reviewer_cloudflare_sync.txt` | Workers/Durable Objects concurrency, edge caching, WebSocket alarms, transaction isolation. |

---

## 4. Execution Workflows

### Option A: Shell Script Execution (Fast & Autonomous)

Run dynamic stack review against a base branch:
```bash
~/.agents/skills/adversarial-review/scripts/herdr-dynamic-review.sh [base_ref] [runner]
```
*(If `runner` is omitted in an interactive terminal, the script interactively prompts to pick 1-5).*

Run autonomous multi-round self-healing loop:
```bash
~/.agents/skills/adversarial-review/scripts/herdr-auto-loop.sh [base_ref] [runner]
```

Examples:
```bash
# Review using Google Antigravity CLI with Claude model
~/.agents/skills/adversarial-review/scripts/herdr-dynamic-review.sh origin/develop agy-claude

# Autonomous auto-healing loop using Cursor Agent CLI
~/.agents/skills/adversarial-review/scripts/herdr-auto-loop.sh forgejo/develop cursor-agent

# Review using Claude Code CLI
~/.agents/skills/adversarial-review/scripts/herdr-dynamic-review.sh HEAD~1 claude
```

### Option B: In-Session Parallel Subagents (Interactive)

When performing in-depth reviews inside an active pair programming session:
1. Ask the user which reviewer agent CLI they prefer (`agy`, `agy-claude`, `cursor-agent`, `codex`, `claude`).
2. Identify modified files (`git diff --name-only <base_ref> --`).
3. Read the matching prompt files from `~/.agents/skills/adversarial-review/prompts/`.
4. Launch parallel reviewer subagents or CLI subprocesses passing the git diff and selected runner.
5. Collect verdicts:
   - If all approved: Proceed to PR / Commit.
   - If blockers flagged: Implement fixes and re-verify.

---

## 5. Integration with Feature Workflows & Obsidian

This skill is invoked during **Stage 4 (Adversarial Code Gate)** of the `obsidian-project-tracker`, `vimark-feature-workflow`, and `mobile-feature-workflow` lifecycles.

**Companion skills**: After this code gate, run **`adversarial-ui-review`** (design) and **`adversarial-qa`** (end-user binary/site QA package on Tart/emulator/simulator/browser). Code review does not replace either.

1. **Before Staging / Committing / Merge**:
   ```bash
   ~/.agents/skills/adversarial-review/scripts/herdr-dynamic-review.sh origin/develop agy-claude
   ~/.agents/skills/adversarial-ui-review/scripts/herdr-ui-dynamic-review.sh origin/develop agy-claude
   ~/.agents/skills/adversarial-qa/scripts/run-qa-gate.sh origin/develop
   ```
2. **Log Reviewer Sign-Off in Obsidian `Work_Log.md`**:
   ```markdown
   - **Adversarial Review**: ✔ Approved by `reviewer_rust_backend`, `reviewer_extension_crossbrowser`, `reviewer_sec` (via agy-claude).
   - **Adversarial UI Review**: ✔ Approved by `reviewer_ui_desktop` (via agy-claude).
   - **Adversarial QA**: ✔ APPROVED — `qa-packages/…`
   ```

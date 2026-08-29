---
name: adversarial-ui-review
description: >-
  Multi-persona adversarial UI/UX/design review gate for desktop apps, websites,
  Android, and iOS — separate evidence-cited reviewers (Nielsen heuristics, WCAG
  2.2, Laws of UX, Apple HIG, Material Design) that approve or block on visual
  hierarchy, interaction, accessibility, and platform convention regressions.
  Use after desktop/device verification and before opening a PR; also when the
  user asks for "adversarial UI review", "UX review", "design review", or
  "critique the UI". Complements adversarial-review (code) — does not replace it.
disable-model-invocation: true
---

# Adversarial UI / UX / Design Review Skill

Evidence-first UI quality gate, parallel to `adversarial-review` (code). Reviewers
**must cite** an authority for every finding — taste alone is not a finding.

Grounding research (2024–2026 practice):
- Nielsen Norman Group — 10 Usability Heuristics
- W3C WCAG 2.2 AA
- Laws of UX (Fitts, Miller, Doherty, Hick, Jakob)
- Astralab / forgehouse evidence-based UX audit method (authority + severity + score)
- Browserbase ui-test adversarial categories (keyboard-only, empty/error, overflow, rapid input)
- Apple HIG (iOS / macOS keyboard & focus) and Material Design 3 (Android)

---

## 1. Reviewer LLM Agent CLI Selection (MANDATORY)

Same runner menu as code review — **ask before running**:

| Runner | CLI pattern |
|---|---|
| **`agy`** | `echo "$PAYLOAD" \| agy -p "$(cat "$PROMPT")" --no-context` |
| **`agy-claude`** | `echo "$PAYLOAD" \| agy -m "Claude 3.7 Sonnet" -p "$(cat "$PROMPT")" --no-context` |
| **`cursor-agent`** | `echo "$PAYLOAD" \| cursor-agent -p "$(cat "$PROMPT")" --output-format text` |
| **`codex`** | `echo "$PAYLOAD" \| codex exec "$(cat "$PROMPT")"` |
| **`claude`** | `echo "$PAYLOAD" \| claude -p "$(cat "$PROMPT")"` |

---

## 2. How It Works

1. **Detect UI surfaces** from the diff (and optional live evidence).
2. **Dispatch platform personas** (desktop / website / Android / iOS) — only those that match.
3. **Prefer live evidence** when UI changed: screenshots + DOM/accessibility tree from Tauri MCP, Playwright/Chrome DevTools, Peekaboo, or mobile MCP. Attach paths in the payload.
4. **Fall back to code+styles** when the app cannot run (still require citations).
5. **Verdict**: every active persona must print `VERDICT: APPROVED`, or list blockers with severity + citation.
6. **Auto-heal** (optional): feed blockers to the builder, re-verify visually, re-run.

> Code security / IPC / concurrency stay in `adversarial-review`. This skill owns
> hierarchy, copy, states, a11y, motion, density, and platform UI conventions.

---

## 3. Personas

| Persona file | When dispatched | Focus |
|---|---|---|
| `reviewer_ui_desktop.txt` | Tauri / Electron / `src-tauri` / desktop React window UI | Spotlight windows, focus/blur, keyboard first, density, native chrome |
| `reviewer_ui_website.txt` | `website/`, Astro/HTML marketing or docs sites | Responsive, SEO landmarks, CTA hierarchy, scroll, Core Web Vitals UX |
| `reviewer_ui_android.txt` | `android/`, `.kt` Compose UI | Material 3, 48dp targets, back stack, system bars, TalkBack |
| `reviewer_ui_ios.txt` | `ios/`, `.swift` SwiftUI/UIKit | HIG, 44pt targets, Dynamic Type, safe areas, VoiceOver |

Shared rubric: `references/severity-rubric.md`  
Shared authorities & thresholds: `references/evidence-authorities.md`

---

## 4. Path → Persona Dispatch

```text
src-tauri/ | tauri.conf | desktop window React (src/components, src/App)  → desktop
website/ | *.astro | marketing HTML                                       → website
android/ | *.kt Compose screens                                           → android
ios/ | *.swift | *.storyboard | *.xib                                     → ios
```

Overrides:
- `UI_PLATFORMS=desktop,website` — force personas
- `UI_EVIDENCE_DIR=/path/to/screenshots` — attach images listed in that dir to the payload

If no UI paths match → skip with message `No UI surfaces in diff; adversarial-ui-review skipped.` (exit 0).

---

## 5. Execution

### Dynamic one-shot

```bash
~/.agents/skills/adversarial-ui-review/scripts/herdr-ui-dynamic-review.sh [base_ref] [runner]
```

### Auto-heal loop (UI blockers → builder → re-review)

```bash
~/.agents/skills/adversarial-ui-review/scripts/herdr-ui-auto-loop.sh [base_ref] [runner]
```

### In-session (interactive)

1. Ask for runner CLI.
2. Collect screenshots of changed flows (required when UI visibly changed).
3. Read matching `prompts/reviewer_ui_*.txt`.
4. Launch parallel reviewers with diff + evidence list.
5. Block PR until all return `VERDICT: APPROVED` **or** user explicitly waives with rationale in the PR.

---

## 6. Finding Format (enforced by prompts)

```text
SEVERITY: Blocker|Critical|Warning|Tip
WHERE: <file:line or screenshot + selector/region>
BEFORE: <observable current behaviour>
AFTER: <concrete fix a developer can implement>
WHY: <one citation — Nielsen Hn | WCAG SC x.y.z | Law name | HIG/Material rule>
```

No citation → drop the finding. Accessibility Blockers always outrank polish.

Score (optional roll-up):  
`100 − (Blockers×12) − (Criticals×8) − (Warnings×4) − (Tips×1)`  
Gate rule: any **Blocker** or **Critical** → not approved.

---

## 7. Workflow Integration

Invoked as **Stage 4c** after code adversarial review and after manual/desktop/device verification:

| Workflow | Call |
|---|---|
| `vimark-feature-workflow` | `herdr-ui-auto-loop.sh forgejo/develop` when React/window/website UI changed |
| `mobile-feature-workflow` | `herdr-ui-auto-loop.sh forgejo/develop` when Compose/SwiftUI screens changed |
| `obsidian-project-tracker` Stage 4 | Run code gate **and** UI gate before QA / PR |

**Next gate**: `adversarial-qa` (end-user binary/site proof package) is mandatory before merge after this design gate.

Work_Log line:

```markdown
- **Adversarial UI Review**: ✔ Approved by `reviewer_ui_desktop` (via agy-claude). Evidence: tauri MCP screenshots.
```

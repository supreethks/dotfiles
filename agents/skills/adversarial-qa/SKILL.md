---
name: adversarial-qa
description: >-
  Project-agnostic mandatory pre-merge end-user QA gate for any repo — exercises
  real binaries and sites close to user state (warm Tart VM for desktop, Android
  emulator, iOS Simulator, real browser for websites) with always-on video, step
  screenshots, and a hashed QA verification package (defects vs observations vs
  infra flakes). Configure per repo via .adversarial-qa.json. Use on every PR
  before merge, or when the user says "run QA gate", "QA verification package",
  or "test on Tart/emulator/simulator". Complements adversarial-review (code) and
  adversarial-ui-review (design). Exploratory chaos is nightly-only, not PR.
disable-model-invocation: true
---

# Adversarial End-User QA Skill (global)

**Shared across all projects.** Lives in `~/.agents/skills/adversarial-qa/`
(symlinked into Claude/Cursor). Per-project differences belong in **repo config**,
not in this skill.

Runs **smoke + PRD acceptance** against a build the user would actually launch.
Produces a **QA verification package** as proof of work. **Mandatory before merge
on every PR** that changes product surfaces (prefer run when unsure).

## Global policy

- Gate: **mandatory before merge**
- Build: **unsigned debug OK**
- Desktop: **reuse warm long-lived Tart sandbox** (never cold-clone/destroy per PR)
- Depth: **smoke + PRD acceptance only** (exploratory → nightly)
- Taxonomy: Defects block · Observations do not · Infra flake → one retry → Inconclusive
- Cadence: **every PR**
- Timeouts: journey ≤ **5 minutes**; **video always on**

---

## 0. Project config (required for desktop; recommended always)

Resolve settings in this order (later wins only for explicit env overrides):

1. Repo file **`.adversarial-qa.json`** (commit this — no secrets)
2. Environment variables (`QA_TART_VM`, `QA_PACKAGE_ROOT`, `QA_PLATFORMS`, …)
3. Built-in path heuristics for platform dispatch only (no project-specific VM names)

### `.adversarial-qa.json` schema

```json
{
  "project": "<slug>",
  "tart_vm": "<warm-long-lived-tart-name>",
  "package_root": "qa-packages",
  "debug_build_command": "<cmd to produce unsigned debug binary>",
  "primary_launch": {
    "kind": "shortcut|url|activity|scheme",
    "value": "<e.g. Cmd+Shift+Space or https://localhost:4321>"
  },
  "website_url": "",
  "android": {
    "package_id": "",
    "main_activity": "",
    "apk_path_glob": "",
    "avd": "",
    "console_port": "",
    "serial": ""
  },
  "ios": { "scheme": "", "bundle_id": "", "simulator_name": "" },
  "prd_glob": "**/YYYYMMDD - PRD - *.md"
}
```

Template: `references/adversarial-qa.example.json`  
Loader: `scripts/resolve-qa-config.sh` (prints `KEY=value` for `eval`)

If desktop QA is selected and `tart_vm` / `QA_TART_VM` is missing → **stop** and ask the user which warm Tart VM to use; do not invent a project name.

Also gitignore `qa-packages/` in each repo.

---

## 1. Relation to Other Gates

| Gate | Skill | Question |
|---|---|---|
| Code | `adversarial-review` | Is the diff safe/correct in code? |
| Design | `adversarial-ui-review` | Design/a11y heuristics on evidence? |
| **QA (this)** | `adversarial-qa` | Does the **running binary/site** pass smoke + PRD with proof? |

Order: interactive verify → code gate → UI gate → **QA gate** → PR/merge.

Used by any feature workflow (`vimark-feature-workflow`, `mobile-feature-workflow`, web/custom) and by **`obsidian-project-tracker` Stage 4** for every project slug.

---

## 2. Platform Dispatch

| Surface | Environment | Drivers | Persona |
|---|---|---|---|
| Desktop | Warm Tart (`tart_vm` from config) | Peekaboo / OS keyboard, ffmpeg, optional app MCP | `qa_desktop_tart.txt` |
| Website | Real Chromium | chrome-devtools MCP or Playwright | `qa_website_browser.txt` |
| Android | Emulator from repo `android.avd` / `android.serial` (ViMark: `Vimark_Pixel_8` @ `emulator-5574`) | adb + mobile MCP | `qa_android_emulator.txt` |
| iOS | Simulator | simctl + xcodemcp / mobile MCP | `qa_ios_simulator.txt` |

Path heuristics (override with `QA_PLATFORMS`):  
`src-tauri|Electron|desktop/` → desktop · `website/|*.astro` → website · `android/|*.kt` → android · `ios/|*.swift` → ios

---

## 3. Journey Set (PR scope)

1. **Smoke** — launch, ready, primary entry (`primary_launch` from config), clean quit  
2. **PRD acceptance** — each Acceptance Criteria → step + screenshot  
3. **Not in PR** — exploratory / chaos (nightly)

Journey timeout **5 minutes**. Ready-wait ≤ 30s per condition.

---

## 4. Finding Taxonomy

| Class | Blocks merge? |
|---|---|
| **Defect** | **Yes** |
| **Observation** | No |
| **Infra flake** | Retry once → else **Inconclusive** (not a product fail; human note) |

---

## 5. QA Verification Package

Under `$QA_PACKAGE_ROOT` or config `package_root` (default `qa-packages/`):

```text
qa-packages/<YYYYMMDDTHHMMSS>-<gitsha7>-<platform>/
  manifest.json
  REPORT.md
  journeys/<journey-id>/steps.jsonl screenshots/
  video/<journey-id>.mp4
  logs/
  SHA256SUMS
```

See `references/package-schema.md`. Attach path + REPORT to PR and project `Work_Log.md`.

---

## 6. Desktop / Tart (warm sandbox)

```bash
eval "$(~/.agents/skills/adversarial-qa/scripts/resolve-qa-config.sh)"
tart list
# start only if stopped — reuse disk (accounts, TCC, logins)
tart run "$QA_TART_VM" &
# deploy debug binary via shared folder / scp
# ffmpeg always on → drive primary_launch → screenshots → pull artifacts
```

Build via `debug_build_command` from config (unsigned OK).

---

## 7. Execution

```bash
~/.agents/skills/adversarial-qa/scripts/run-qa-gate.sh <base_ref>
# … agent runs journeys …
QA_VERDICT=APPROVED|REJECTED|INCONCLUSIVE \
  ~/.agents/skills/adversarial-qa/scripts/finalize-qa-package.sh <package-dir>
```

Exit: `0` APPROVED/skip · `1` REJECTED · `2` INCONCLUSIVE  

Merge: REJECTED blocks · INCONCLUSIVE needs human ack · APPROVED required for normal merge.

---

## 8. Anti-Flake

See `references/anti-flake.md`: no fixed sleeps; a11y selectors; classify infra vs defect before retry; always keep video + screenshots.

---

## 9. Wiring into projects

| Layer | Responsibility |
|---|---|
| This skill | Global procedure, scripts, personas, package schema |
| `.adversarial-qa.json` in each repo | Tart VM name, build cmd, launch shortcut/URL, package ids |
| `*-feature-workflow` | When to invoke (still call this skill) |
| `obsidian-project-tracker` | Stage 4 for **any** project slug |

Work_Log:

```markdown
- **Adversarial QA**: ✔ APPROVED (`qa-packages/…`). Smoke + PRD. Video on.
```

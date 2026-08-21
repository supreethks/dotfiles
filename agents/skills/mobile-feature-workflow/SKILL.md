---
name: mobile-feature-workflow
description: End-to-end delivery workflow for Android/iOS repos that use a Forgejo remote — start every change on a clean branch cut from `forgejo/develop` (or an isolated worktree when the current branch has uncommitted work), run the unit and instrumentation tests for whichever platforms changed, verify on any physically connected device with the device MCP, backfill instrumentation tests covering what was verified by hand, then commit and open a PR against `develop`. Use this skill at the START of any coding task in a repo that has a `forgejo` git remote and `android/` or `ios/` directories — implementing a feature, fixing a bug, changing UI — even when the user only says "add X" or "fix Y" and never mentions branches, tests, or PRs. Also use it when the user asks to run tests, verify on device, or raise a PR for work already in progress.
---

# Mobile feature workflow

This encodes a delivery loop for mobile repos hosted on Forgejo: **clean branch → build → test → verify on real hardware → automate that verification → PR**.

The order matters. Branching first keeps unrelated in-flight work out of the PR. Verifying on a device before writing instrumentation tests means the tests encode behaviour you actually observed rather than behaviour you assumed.

## 0. Confirm this repo matches & Establish Context

Run these before assuming the workflow applies:

```bash
git remote -v | grep forgejo    # is there a forgejo remote?
ls android ios 2>/dev/null      # which platforms exist?
```

No `forgejo` remote, or no mobile directories — this skill does not apply. Fall back to the repo's own conventions and say so rather than inventing a Forgejo flow.

**Obsidian Project Context & Backlog Intake**:
- For **Yorely**: Check `/Users/supreethks/docs/obsidian/main-vault/projects/yorely/` (`yorely.md`, `Kanban.md`, `PRD.md`)
- For **Kagga**: Check `/Users/supreethks/docs/obsidian/main-vault/projects/kagga/` (`kagga.md`, `Kanban.md`, `PRD.md`)
- **If triggered by "let's work on the backlog"**:
  1. Pull backlog items (`python3 /Users/supreethks/.agents/skills/obsidian-project-tracker/scripts/backlog_helper.py list <yorely|kagga> --column "Backlog"`).
  2. Present the backlog tasks and ask the user to pick.
  3. **Conduct the Mandatory "Grill-Me" Interview**: Clarify user flows, design specifications, Android/iOS parity expectations, edge cases, and test strategies before cutting a branch.
  4. Move the task to `## 🚧 In Progress` in `Kanban.md`.

## 1. Start on a clean branch

**Always fetch first.** A local `develop` branch is very often stale — it can be many release commits behind what is actually on the remote. Branching from a stale base produces a PR full of phantom changes and merge conflicts.

```bash
git fetch forgejo
git log --oneline HEAD..forgejo/develop | head   # what has moved on the remote?
git log --oneline forgejo/develop..HEAD          # unrelated commits on the current branch?
```

Then pick one of three paths:

**Clean tree, no unrelated commits** — branch directly:
```bash
git checkout -b <type>/<slug> forgejo/develop
```

**Uncommitted work on the current branch** — do not stash and hope. Stashing across a base change can conflict on generated files (`project.pbxproj`, lockfiles) and the user loses sight of their own work. Use an isolated worktree so their tree is untouched:
```bash
git worktree add ../<repo>-<slug> -b <type>/<slug> forgejo/develop
cd ../<repo>-<slug>
```
Tell the user where the worktree is and that their original checkout is untouched. Remove it with `git worktree remove` once the PR is open and they confirm they're done.

**Current branch carries unrelated in-flight commits** (someone else's WIP, or a separate fix awaiting its own PR) — commit your work, then replay only your commit onto the fresh base so the PR stays scoped:
```bash
git rebase --onto forgejo/develop <last-unrelated-commit> <your-branch>
git log --oneline forgejo/develop..HEAD   # expect only your commits
```

Branch naming follows the repo's existing history — check `git log --oneline -20` for the prevailing convention (commonly `feature/`, `fix/`, `chore/`).

## 2. Do the work

Nothing special here, except: **when a change touches both platforms, keep them behaviourally identical.** These codebases mirror each other deliberately — a Kotlin file usually has a Swift counterpart with the same name and the same comments. Diverging silently is how the two apps drift apart.

**iOS only:** new `.swift` files must be registered in `project.pbxproj` or they will not compile into the target. The `xcodeproj` Ruby gem is the reliable way:

```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('<path>/Yorely.xcodeproj')
target  = project.targets.find { |t| t.name == '<TargetName>' }
group   = project.main_group.find_subpath(File.join('<Dir>', '<Sub>'), false)
ref = group.new_reference('<NewFile>.swift', :group)
target.source_build_phase.add_file_reference(ref)
project.save
```

Editor diagnostics will report "No such module" or "Cannot find type in scope" for a file that isn't in the target yet — and also, confusingly, whenever the index is merely stale. Trust a real `xcodebuild` over the editor's squiggles; only a compile settles it.

## 3. Test what changed

Match the project's CI rather than inventing a test command — read `.forgejo/workflows/*pr-ci*.yml` to see exactly what the required checks run, then run that locally. Diverging means green locally and red on the PR.

| Changed | Unit tests | Instrumentation / UI tests |
|---|---|---|
| `android/` | `cd android && ./gradlew test` | `./gradlew connectedDebugAndroidTest` (needs a device/emulator) |
| `ios/` | `xcodebuild test -scheme <S> -destination <D> -only-testing:<Target>Tests` | `-only-testing:<Target>UITests` |

Touch both platforms, run both sides. Touch neither (docs, CI config), say so and skip.

**Gradle caches aggressively.** `UP-TO-DATE` on a test task means it did not run. When the result actually matters — before committing, after a rebase — force it:

```bash
./gradlew test --rerun-tasks
```

And read the count, not just `BUILD SUCCESSFUL`: a suite that silently ran zero tests also succeeds.

```bash
python3 - <<'EOF'
import glob, xml.etree.ElementTree as ET
tot=fail=err=0
for f in glob.glob('android/app/build/test-results/*/*.xml'):
    r=ET.parse(f).getroot()
    tot+=int(r.get('tests',0)); fail+=int(r.get('failures',0)); err+=int(r.get('errors',0))
print(f"{tot} tests, {fail} failures, {err} errors")
EOF
```

**Re-run after rebasing.** A rebase pulls in commits you never compiled against. Tests that passed on the old base prove nothing about what you're pushing.

## 4. Verify on a device — physical if attached, otherwise simulated

Automated tests confirm logic; they do not confirm the thing looks right or that a flow is even reachable. **This step always happens** for a change with any UI surface. See `references/device-verification.md` for the full procedure — worth reading before touching a physical device, because several steps are destructive if done carelessly.

Find out what is available:

```bash
adb devices -l                       # Android: emulator-* are emulators, rest are physical
xcrun devicectl list devices         # iOS: physical, look for state "connected"
xcrun simctl list devices booted     # iOS: booted simulators
```

Then, per platform that changed:

- **Physical device attached** — verify there. It is the only way to catch real-hardware behaviour: locale-formatted input, store/billing, notification delivery, actual deep links into other apps.
- **No physical device** — boot an emulator or simulator and verify there instead. Missing hardware is never a reason to skip verification; a simulated run still catches unreachable flows, broken navigation, wrong empty states and layout regressions, which is most of what goes wrong.

```bash
~/Library/Android/sdk/emulator/emulator -list-avds
~/Library/Android/sdk/emulator/emulator -avd <name> -no-snapshot-load -no-boot-anim   # background
adb wait-for-device && adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'

xcrun simctl list devices available | grep iPhone
xcrun simctl boot <udid> && xcrun simctl bootstatus <udid> -b
```

Install a **debug** build, drive the app with the device MCP (`mobile_list_elements_on_screen` for coordinates and identifiers, `mobile_click_on_screen_at_coordinates`, `mobile_type_keys`), and screenshot each meaningful state.

Be explicit in the write-up about *where* each thing was verified — "verified on a Pixel 8 emulator" and "verified on a physical Pixel 6a" carry different weight, and the reader should not have to guess which one you mean. Where a behaviour genuinely cannot be exercised in a simulator (in-app purchase, push delivery, a third-party app that is not installed), say that it remains unverified rather than implying full coverage.

Three rules that protect the user's own device:

- **Target every command explicitly** (`adb -s <serial>`, `xcrun simctl ... <udid>`) whenever more than one device is attached. An unqualified `adb shell pm clear` on the wrong device destroys real data.
- **Never uninstall to force a build on.** A release-signed app already on the phone will reject a debug APK; uninstalling wipes the user's profiles and settings irreversibly. Build a signed release instead and install over the top — see the reference.
- **Restore what you touched.** Delete test data you created, and leave developer/QA toggles exactly as found. Then report precisely what changed on their device.

## 5. Backfill instrumentation tests for what you verified

This is the step that stops the manual pass from being throwaway. Everything just confirmed by hand should become an automated test, so the next change cannot silently break it.

Write them against the flow actually exercised, mirroring the existing tests in `android/app/src/androidTest/` (Compose `createAndroidComposeRule`, Espresso) and the iOS UI test target (XCUITest). Match their structure and naming — a test that looks like its neighbours gets maintained.

**These tests are part of the deliverable, not a follow-up.** A PR that says "verified manually" and ships no test has moved the verification burden onto the next person. If they genuinely cannot land in the same PR, open the follow-up immediately and link it, rather than leaving it as an intention.

Three things make these tests reliable:

- **Test the control alongside the behaviour.** Asserting the feature appears when its flag is on proves little on its own; also assert it is *absent* when the flag is off. That pair is what proves the flag actually gates, and it is the assertion that catches a gate wired to the wrong key.
- **Drive by accessibility identifier, not coordinates.** Coordinates shift with locale, font scale and screen size. If a control you tapped by pixel has no identifier, add one — it improves accessibility and testability together.
- **Use the app's existing test hooks** rather than fighting real state. Mobile apps usually expose launch arguments or system properties to force a starting state (skip onboarding, bypass a paywall, pin a trial length). Grep for `ProcessInfo.processInfo.arguments` and `System.getProperty` to find what already exists, and extend that mechanism instead of inventing a parallel one. On iOS in particular, a launch argument `-someKey YES` seeds `UserDefaults` for that launch, so any preference-backed flag can be forced without touching the UI or persisting anything.

Remote feature flags need pinning too: a test that depends on a live flag service is a test that fails when someone changes a rollout. Force the flag locally through the app's own override so the test is deterministic.

Then run the new tests and confirm they pass against a device or emulator. Reporting them as added without running them is worse than not adding them.

If the verified behaviour genuinely cannot be automated — it depends on an external app, a real purchase, a push notification — say so explicitly and explain why, so the gap is a known decision rather than an oversight.

## 6. Commit and open the PR

Review the diff before staging, especially generated files. `git diff <generated-file>` should contain only changes you intended; a stray version bump or reordered UUID block means something else edited it.

Write the commit body to explain **why**, not to list files — the diff already lists files. Follow the repo's existing commit style (`git log -15` to see it), and end with the required trailer if the project uses one.

Push and open the PR against `develop`:

```bash
git push -u forgejo <branch>
```

Forgejo's API is Gitea-compatible. The credential git just used for the push is already in the OS keychain, so reuse it rather than asking the user for a token — and never echo it:

```bash
CRED=$(printf 'protocol=http\nhost=<host:port>\n\n' | git credential fill 2>/dev/null)
U=$(printf '%s\n' "$CRED" | sed -n 's/^username=//p')
P=$(printf '%s\n' "$CRED" | sed -n 's/^password=//p')
curl -s -u "$U:$P" -X POST -H "Content-Type: application/json" \
  -d @pr.json \
  http://<host:port>/api/v1/repos/<owner>/<repo>/pulls
```

`pr.json` carries `{"head","base":"develop","title","body"}`. Build it with `json.dumps` from a Markdown file rather than hand-escaping — PR bodies contain quotes, backticks and newlines that break shell quoting.

A PR body earns its keep by telling the reviewer what the diff cannot: why the change is shaped this way, what was verified and how, and what you deliberately left undone. Put anything that needs a human decision — untranslated strings, a flag that still needs creating, a behaviour change with product implications — under an explicit heading so it cannot be skimmed past.

Finally, poll the checks and report the real result:

```bash
curl -s -u "$U:$P" "http://<host:port>/api/v1/repos/<owner>/<repo>/commits/$(git rev-parse HEAD)/statuses"
```

## 7. Sync Obsidian Project Tracker

Upon PR creation or task completion:
1. **Update Kanban**: Open the project board (`projects/yorely/Kanban.md` or `projects/kagga/Kanban.md`) and move the completed task to `## ✅ Done`.
2. **Append Work Log**: Add a session summary to `Work_Log.md` with goal, modified files, verification notes (physical device vs emulator), and PR link.
3. **Record Decisions**: If an architectural choice was made, append an ADR entry in `Decisions.md`.

## Reporting back

State what actually happened: the branch and base, test counts per platform, which devices were verified on and what was observed, the tests added, the PR URL and its check status, and Obsidian docs updated. If something was skipped — no device attached, a step blocked — say so plainly instead of leaving the user to infer it from silence.


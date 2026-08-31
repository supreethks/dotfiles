# Journey Templates (PR: smoke + PRD) — project-agnostic

Primary entry comes from repo `.adversarial-qa.json` → `primary_launch`
(or env `QA_PRIMARY_LAUNCH_KIND` / `QA_PRIMARY_LAUNCH_VALUE`).

## Desktop smoke (`smoke-desktop`)

1. `eval "$(resolve-qa-config.sh)"` — require `QA_TART_VM`
2. Confirm Tart VM running (`tart list`); start if stopped; wait for IP
3. Build/install unsigned debug binary (`QA_DEBUG_BUILD_COMMAND`)
4. Start ffmpeg → `video/smoke-desktop.mp4`
5. Launch app
6. Wait ready (window / AX / log)
7. Trigger `QA_PRIMARY_LAUNCH_*` (shortcut, URL, or custom)
8. Screenshot; exercise one trivial interaction; dismiss/hide if applicable
9. Quit cleanly; no new crash report
10. Stop ffmpeg

## Desktop PRD (`prd-<slug>`)

For each Acceptance Criteria checkbox in the task PRD:

1. Step = one criterion
2. Perform user-visible action
3. Assert observable result
4. Screenshot; append `steps.jsonl`
5. On fail → Defect with criterion text quoted

## Website smoke (`smoke-website`)

1. Open `QA_WEBSITE_URL` (or PRD-specified URL)
2. Start browser recording
3. Home renders; primary CTA visible; no console `Error`
4. One secondary route
5. Width 375 — no horizontal overflow

## Android smoke (`smoke-android`)

1. Emulator ready (`adb -s "$QA_ANDROID_SERIAL" wait-for-device` + boot_completed). ViMark: `Vimark_Pixel_8` / `emulator-5574`.
2. Install APK (`QA_ANDROID_APK_GLOB` / package `QA_ANDROID_PACKAGE`)
3. Screen recording on
4. Launch main activity; primary interaction
5. Force-stop; pull recording

## iOS smoke (`smoke-ios`)

1. Simulator (`QA_IOS_SIMULATOR`) booted
2. Install debug build (`QA_IOS_SCHEME` / `QA_IOS_BUNDLE`)
3. Recording on; launch; primary interaction
4. Terminate; save video

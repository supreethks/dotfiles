# Anti-Flake Playbook (PR QA)

E2E against real GUIs will flake. Goal: **diagnose**, not pretend certainty.

## Do

| Practice | Why |
|---|---|
| Poll for ready (window, selector, log, HTTP 200) with timeout | Fixed sleeps fail both fast and slow machines |
| Accessibility / `data-testid` / AX labels | Coordinates drift with DPI and layout |
| Fresh app state for smoke; keep Tart **disk** warm | Cold VM boot is slow; wiping TCC every run is worse |
| Always record video + step screenshots | Separates product bug vs driver miss |
| Classify Defect vs Infra before retry | Retries must not hide product bugs |
| Cap journey at 5 minutes | Hung waits are infra, not “still testing” |
| Disable non-essential animations in debug | Reduces timing races |

## Don't

- `sleep 5` as synchronization
- Click by raw coordinates as first choice
- Destroy/recreate Tart per PR (policy: warm sandbox)
- Exploratory chaos on PR runs (nightly only)
- Mark “element not found” as product Defect without screenshot + video review
- Retry a clear assertion failure hoping it passes

## Retry policy

1. Attempt 1 fails → inspect evidence
2. If Infra (boot, SSH, emulator offline, ffmpeg, agent disconnect) → reset driver, **one** retry
3. Still infra → `INCONCLUSIVE` (merge only with human note)
4. If Defect → `REJECTED`, no retry lottery

## Ready signals (examples)

- Desktop: palette window listed in Peekaboo / AX; or log line `listening`; or IPC ping
- Android: `adb wait-for-device` + `sys.boot_completed` + package resumed
- iOS: sim booted + app `RunningForeground`
- Web: Playwright `networkidle` or specific test id visible

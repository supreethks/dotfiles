# QA Package Schema

## Directory

```text
qa-packages/<YYYYMMDDTHHMMSS>-<gitsha7>-<platform>/
  manifest.json
  REPORT.md
  journeys/<journey-id>/
    steps.jsonl
    screenshots/
  video/
  logs/
  SHA256SUMS
```

## manifest.json

```json
{
  "schema_version": 1,
  "created_at": "ISO-8601",
  "git": { "sha": "", "branch": "", "dirty": false, "base_ref": "" },
  "platform": "desktop|website|android|ios",
  "environment": {
    "kind": "tart|emulator|simulator|browser",
    "name": "<from .adversarial-qa.json tart_vm>",
    "os_version": "",
    "notes": "warm long-lived sandbox reused"
  },
  "binary": {
    "path": "",
    "sha256": "",
    "signed": false,
    "build": "debug"
  },
  "tools": { "tart": "", "ffmpeg": "", "adb": "", "peekaboo": "", "runner": "" },
  "journeys": [{ "id": "smoke", "result": "pass|fail|infra", "video": "video/smoke.mp4" }],
  "verdict": "APPROVED|REJECTED|INCONCLUSIVE",
  "counts": { "defects": 0, "observations": 0, "infra_flakes": 0 }
}
```

## steps.jsonl (one JSON object per line)

```json
{"t":"ISO","n":1,"action":"primary_launch","detail":"<from QA_PRIMARY_LAUNCH_VALUE>","expect":"main UI visible","result":"pass","screenshot":"screenshots/001-ready.png"}
```

## REPORT.md sections (required)

1. Summary + `VERDICT:`
2. Environment & binary hash
3. Journey results table
4. Defects (blocking)
5. Observations (non-blocking)
6. Infra / Inconclusive notes
7. Artifact index (video + screenshots)

## SHA256SUMS

`cd` package root → `find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 shasum -a 256`

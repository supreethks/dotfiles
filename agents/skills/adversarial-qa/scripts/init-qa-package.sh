#!/usr/bin/env bash
# Initialize a QA verification package directory and skeleton files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
eval "$("$SCRIPT_DIR/resolve-qa-config.sh")" || true

PLATFORM="${1:?platform required: desktop|website|android|ios}"
BASE_REF="${2:-HEAD}"
ROOT="${QA_PACKAGE_ROOT:-qa-packages}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: must run inside a git repo (or set paths manually)." >&2
  exit 1
fi

SHA=$(git rev-parse --short=7 HEAD)
TS=$(date -u +"%Y%m%dT%H%M%SZ")
DIR="${ROOT}/${TS}-${SHA}-${PLATFORM}"
mkdir -p "$DIR"/journeys "$DIR"/video "$DIR"/logs

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
DIRTY=false
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then DIRTY=true; fi

cat > "$DIR/manifest.json" <<EOF
{
  "schema_version": 1,
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project": "${QA_PROJECT:-}",
  "git": {
    "sha": "$(git rev-parse HEAD)",
    "short": "$SHA",
    "branch": "$BRANCH",
    "dirty": $DIRTY,
    "base_ref": "$BASE_REF"
  },
  "platform": "$PLATFORM",
  "environment": {
    "kind": "",
    "name": "${QA_TART_VM:-}",
    "os_version": "",
    "notes": "warm long-lived sandbox reused; config=${QA_CONFIG_PATH:-none}"
  },
  "binary": {
    "path": "",
    "sha256": "",
    "signed": false,
    "build": "debug"
  },
  "tools": {},
  "journeys": [],
  "verdict": "PENDING",
  "counts": { "defects": 0, "observations": 0, "infra_flakes": 0 }
}
EOF

cat > "$DIR/REPORT.md" <<EOF
# QA Verification Report

- **Package**: \`$DIR\`
- **Project**: ${QA_PROJECT:-unset}
- **Platform**: $PLATFORM
- **Git**: $SHA (\`$BRANCH\`) base \`$BASE_REF\`
- **Config**: ${QA_CONFIG_PATH:-none}
- **VERDICT**: PENDING

## Environment

- Kind / name: ${QA_TART_VM:-}
- Binary path / sha256:
- Signed: no (debug OK)
- Primary launch: ${QA_PRIMARY_LAUNCH_KIND:-} ${QA_PRIMARY_LAUNCH_VALUE:-}

## Journey results

| Journey | Result | Video |
|---------|--------|-------|
| smoke | pending | |
| prd | pending | |

## Defects (blocking)

_None yet._

## Observations (non-blocking)

_None yet._

## Infra / Inconclusive

_None yet._

## Artifact index

- Videos: \`video/\`
- Screenshots: \`journeys/*/screenshots/\`
- Logs: \`logs/\`
EOF

echo "$DIR"

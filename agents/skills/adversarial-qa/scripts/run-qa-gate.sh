#!/usr/bin/env bash
# Orchestrate adversarial QA gate (global): detect platforms, load repo config, init packages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_REF="${1:-HEAD~1}"

# Load per-repo config (no hardcoded project VM names)
# shellcheck disable=SC1091
eval "$("$SCRIPT_DIR/resolve-qa-config.sh")"
ROOT="${QA_PACKAGE_ROOT:-qa-packages}"

echo "======================================================"
echo " Adversarial QA Gate (global · smoke + PRD acceptance)"
echo " Base: $BASE_REF"
echo " Config: ${QA_CONFIG_PATH:-<none — set .adversarial-qa.json>}"
echo " Project: ${QA_PROJECT:-<unset>} | Tart VM: ${QA_TART_VM:-<unset>}"
echo " Journey timeout: 5m | Video: always | Exploratory: nightly only"
echo "======================================================"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run inside the product git repository." >&2
  exit 1
fi

CHANGED=$(git diff --name-only "$BASE_REF" -- 2>/dev/null || git diff --name-only --)
PLATFORMS=()

if [ -n "${QA_PLATFORMS:-}" ]; then
  IFS=',' read -r -a PLATFORMS <<< "$QA_PLATFORMS"
else
  if echo "$CHANGED" | grep -qE 'src-tauri/|tauri\.conf|electron|src/components/|src/App\.(tsx|jsx|vue)|apps/.+/src/|desktop/'; then
    PLATFORMS+=("desktop")
  fi
  if echo "$CHANGED" | grep -qE 'website/|\.astro$|\.html$'; then
    PLATFORMS+=("website")
  fi
  if echo "$CHANGED" | grep -qE 'android/|\.kt$'; then
    PLATFORMS+=("android")
  fi
  if echo "$CHANGED" | grep -qE 'ios/|\.swift$|\.storyboard$|\.xib$'; then
    PLATFORMS+=("ios")
  fi
fi

if [ ${#PLATFORMS[@]} -gt 0 ]; then
  PLATFORMS=($(printf '%s\n' "${PLATFORMS[@]}" | awk 'NF && !seen[$0]++'))
fi

if [ ${#PLATFORMS[@]} -eq 0 ]; then
  echo "No product UI/binary surfaces in diff; adversarial-qa skipped."
  exit 0
fi

for p in "${PLATFORMS[@]}"; do
  p=$(echo "$p" | tr '[:upper:]' '[:lower:]' | xargs)
  if [ "$p" = "desktop" ] && [ -z "${QA_TART_VM:-}" ]; then
    echo "Error: desktop QA selected but no tart_vm configured." >&2
    echo "Add .adversarial-qa.json with \"tart_vm\", or export QA_TART_VM=<warm-vm-name>." >&2
    echo "See ~/.agents/skills/adversarial-qa/references/adversarial-qa.example.json" >&2
    exit 1
  fi
done

mkdir -p "$ROOT"
PACKAGE_DIRS=()
for p in "${PLATFORMS[@]}"; do
  p=$(echo "$p" | tr '[:upper:]' '[:lower:]' | xargs)
  DIR=$("$SCRIPT_DIR/init-qa-package.sh" "$p" "$BASE_REF")
  PACKAGE_DIRS+=("$DIR")
  echo "Initialized package: $DIR"
  case "$p" in
    desktop) echo "  Persona: $SCRIPT_DIR/../prompts/qa_desktop_tart.txt" ;;
    website) echo "  Persona: $SCRIPT_DIR/../prompts/qa_website_browser.txt" ;;
    android)
      echo "  Persona: $SCRIPT_DIR/../prompts/qa_android_emulator.txt"
      echo "  AVD: ${QA_ANDROID_AVD:-<unset>}  serial: ${QA_ANDROID_SERIAL:-<unset>}  port: ${QA_ANDROID_PORT:-<unset>}"
      ;;
    ios) echo "  Persona: $SCRIPT_DIR/../prompts/qa_ios_simulator.txt" ;;
  esac
done

cat <<EOF

----------------------------------------------------------
Agent runbook (mandatory before merge — any project):
  1. eval "\$(~/.agents/skills/adversarial-qa/scripts/resolve-qa-config.sh)"
  2. Build via \$QA_DEBUG_BUILD_COMMAND (unsigned debug OK).
  3. Desktop: reuse warm Tart \$QA_TART_VM (start only if stopped).
     Android: boot \$QA_ANDROID_AVD on \$QA_ANDROID_SERIAL (ViMark: Vimark_Pixel_8 / emulator-5574).
  4. Video ALWAYS on before first interaction; screenshot every step.
  5. Smoke + PRD acceptance only (references/journey-templates.md).
  6. Primary launch: \$QA_PRIMARY_LAUNCH_KIND = \$QA_PRIMARY_LAUNCH_VALUE
  7. QA_VERDICT=APPROVED|REJECTED|INCONCLUSIVE \\
       $SCRIPT_DIR/finalize-qa-package.sh <package-dir>
  8. Attach package + REPORT to PR and Obsidian Work_Log.

Exit policy:
  APPROVED     → merge OK
  REJECTED     → block merge (Defects)
  INCONCLUSIVE → human acknowledgement required (infra only)
----------------------------------------------------------

Packages:
$(printf '  %s\n' "${PACKAGE_DIRS[@]}")
EOF

if [ -n "${QA_OVERALL_VERDICT:-}" ]; then
  case "$QA_OVERALL_VERDICT" in
    APPROVED) exit 0 ;;
    REJECTED) exit 1 ;;
    INCONCLUSIVE) exit 2 ;;
    *) echo "Unknown QA_OVERALL_VERDICT"; exit 1 ;;
  esac
fi

echo "QA packages prepared. Complete journeys, then finalize with QA_VERDICT."
exit 0

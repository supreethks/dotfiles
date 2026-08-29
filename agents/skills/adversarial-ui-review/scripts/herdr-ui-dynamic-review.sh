#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/prompts" ]; then
  PROMPTS_DIR="${SCRIPT_DIR}/prompts"
elif [ -d "${SCRIPT_DIR}/../prompts" ]; then
  PROMPTS_DIR="$(cd "${SCRIPT_DIR}/../prompts" && pwd)"
else
  echo "Error: prompts directory not found relative to ${SCRIPT_DIR}"
  exit 1
fi

BASE_REF="${1:-HEAD~1}"
REQUESTED_RUNNER="${2:-${LLM_RUNNER:-}}"

select_runner() {
  local choice=""
  if [ -n "$REQUESTED_RUNNER" ]; then
    choice="$REQUESTED_RUNNER"
  elif [ -t 0 ] || [ -t 1 ]; then
    echo "======================================================"
    echo " Select LLM Agent CLI Reviewer (adversarial UI):"
    echo "  1) agy (Google Antigravity CLI)"
    echo "  2) agy-claude (Antigravity CLI with Claude model)"
    echo "  3) cursor-agent (Cursor Agent CLI)"
    echo "  4) codex (Codex CLI)"
    echo "  5) claude (Claude Code CLI)"
    echo "======================================================"
    read -r -p "Enter choice [1-5] (default: 1): " user_input
    case "$user_input" in
      1|"agy") choice="agy" ;;
      2|"agy-claude"|"agy with claude"|"agy_claude"|"claude-agy") choice="agy-claude" ;;
      3|"cursor-agent"|"cursor") choice="cursor-agent" ;;
      4|"codex") choice="codex" ;;
      5|"claude") choice="claude" ;;
      *) choice="agy" ;;
    esac
  else
    if command -v agy >/dev/null 2>&1; then
      choice="agy"
    elif command -v codex >/dev/null 2>&1; then
      choice="codex"
    elif command -v cursor-agent >/dev/null 2>&1; then
      choice="cursor-agent"
    elif command -v claude >/dev/null 2>&1; then
      choice="claude"
    else
      echo "Error: Neither agy, codex, cursor-agent, nor claude CLI was found in PATH." >&2
      exit 1
    fi
  fi

  case "$choice" in
    1|"agy") LLM_RUNNER="agy" ;;
    2|"agy-claude"|"agy_claude"|"agy with claude"|"claude-agy") LLM_RUNNER="agy-claude" ;;
    3|"cursor-agent"|"cursor") LLM_RUNNER="cursor-agent" ;;
    4|"codex") LLM_RUNNER="codex" ;;
    5|"claude") LLM_RUNNER="claude" ;;
    *)
      echo "Unknown runner: $choice. Valid options: agy, agy-claude, cursor-agent, codex, claude." >&2
      exit 1
      ;;
  esac
}

select_runner

DIFF=$(git diff "$BASE_REF" -- 2>/dev/null || git diff --)
if [ -z "$DIFF" ]; then
  echo "No diff found against $BASE_REF."
  exit 0
fi

CHANGED_FILES=$(git diff --name-only "$BASE_REF" -- 2>/dev/null || git diff --name-only --)
REVIEWERS=()

# Optional force: UI_PLATFORMS=desktop,website,android,ios
if [ -n "${UI_PLATFORMS:-}" ]; then
  IFS=',' read -r -a FORCED <<< "$UI_PLATFORMS"
  for p in "${FORCED[@]}"; do
    case "$(echo "$p" | tr '[:upper:]' '[:lower:]' | xargs)" in
      desktop) REVIEWERS+=("reviewer_ui_desktop.txt") ;;
      website|web) REVIEWERS+=("reviewer_ui_website.txt") ;;
      android) REVIEWERS+=("reviewer_ui_android.txt") ;;
      ios) REVIEWERS+=("reviewer_ui_ios.txt") ;;
    esac
  done
else
  if echo "$CHANGED_FILES" | grep -qE 'src-tauri/|tauri\.conf|src/components/|src/App\.(tsx|jsx|vue)|apps/.+/src/'; then
    REVIEWERS+=("reviewer_ui_desktop.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'website/|\.astro$|\.html$'; then
    REVIEWERS+=("reviewer_ui_website.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'android/|\.kt$'; then
    REVIEWERS+=("reviewer_ui_android.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'ios/|\.swift$|\.storyboard$|\.xib$'; then
    REVIEWERS+=("reviewer_ui_ios.txt")
  fi
fi

# Dedupe
if [ ${#REVIEWERS[@]} -gt 0 ]; then
  REVIEWERS=($(printf '%s\n' "${REVIEWERS[@]}" | awk 'NF && !seen[$0]++'))
fi

if [ ${#REVIEWERS[@]} -eq 0 ]; then
  echo "No UI surfaces in diff; adversarial-ui-review skipped."
  exit 0
fi

EVIDENCE_NOTE=""
if [ -n "${UI_EVIDENCE_DIR:-}" ] && [ -d "$UI_EVIDENCE_DIR" ]; then
  EVIDENCE_NOTE=$'\n\n=== UI EVIDENCE FILES ===\n'
  EVIDENCE_NOTE+="$(find "$UI_EVIDENCE_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' -o -name '*.md' -o -name '*.txt' \) | head -40)"
  EVIDENCE_NOTE+=$'\n(Open/inspect these paths when judging visual hierarchy, overflow, and states.)\n'
fi

PAYLOAD="${DIFF}${EVIDENCE_NOTE}"

echo "Running adversarial UI review via [$LLM_RUNNER] with: ${REVIEWERS[*]}"

FEEDBACK=""
ALL_APPROVED=true

run_reviewer() {
  local PROMPT_FILE="$1"
  if [ "$LLM_RUNNER" = "agy" ]; then
    echo "$PAYLOAD" | agy -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --print-timeout 15m0s 2>&1 || true
  elif [ "$LLM_RUNNER" = "agy-claude" ]; then
    echo "$PAYLOAD" | agy -m "Claude 3.7 Sonnet" -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --print-timeout 15m0s 2>&1 || true
  elif [ "$LLM_RUNNER" = "cursor-agent" ]; then
    echo "$PAYLOAD" | cursor-agent -p "$(cat "$PROMPT_FILE")" --output-format text 2>&1 || true
  elif [ "$LLM_RUNNER" = "codex" ]; then
    echo "$PAYLOAD" | codex exec "$(cat "$PROMPT_FILE")" 2>&1 || true
  else
    echo "$PAYLOAD" | claude -p "$(cat "$PROMPT_FILE")" 2>&1 || true
  fi
}

for REV in "${REVIEWERS[@]}"; do
  PROMPT_FILE="${PROMPTS_DIR}/$REV"
  if [ -f "$PROMPT_FILE" ]; then
    echo "Evaluating with $REV..."
    OUT=$(run_reviewer "$PROMPT_FILE")
    if ! echo "$OUT" | grep -q "VERDICT: APPROVED"; then
      ALL_APPROVED=false
      FEEDBACK+=$"

### UI Review: $REV
$OUT"
    else
      echo "  ✔ $REV: APPROVED"
    fi
  fi
done

if [ "$ALL_APPROVED" = true ]; then
  echo "✔ All adversarial UI reviewers approved the diff."
  exit 0
else
  echo -e "\n--- UI REVIEW ISSUES FOUND ---"
  echo "$FEEDBACK"
  if [ -n "${HERDR_SESSION_ID:-}" ]; then
    herdr send --session "$HERDR_SESSION_ID" "$FEEDBACK"
  fi
  exit 1
fi

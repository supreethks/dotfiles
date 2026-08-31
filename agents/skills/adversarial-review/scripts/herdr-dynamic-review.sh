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

# Resolve LLM Agent CLI Runner
select_runner() {
  local choice=""
  if [ -n "$REQUESTED_RUNNER" ]; then
    choice="$REQUESTED_RUNNER"
  elif [ -t 0 ] || [ -t 1 ]; then
    echo "======================================================"
    echo " Select LLM Agent CLI Reviewer:"
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
    # Non-interactive fallback: detect available CLI
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

# Defense against argument injection: separate ref from path with --
DIFF=$(git diff "$BASE_REF" -- 2>/dev/null || git diff --)
if [ -z "$DIFF" ]; then
  echo "No diff found against $BASE_REF."
  exit 0
fi

CHANGED_FILES=$(git diff --name-only "$BASE_REF" -- 2>/dev/null || git diff --name-only --)
REVIEWERS=()

if echo "$CHANGED_FILES" | grep -qE "\.rs$|Cargo\.(toml|lock)"; then
  REVIEWERS+=("reviewer_rust_backend.txt")
fi
if echo "$CHANGED_FILES" | grep -qE "src-tauri|tauri\.conf\.json"; then
  REVIEWERS+=("reviewer_tauri_frontend.txt" "reviewer_desktop_os.txt")
fi
if echo "$CHANGED_FILES" | grep -qE "manifest\.json|extension/"; then
  REVIEWERS+=("reviewer_extension_crossbrowser.txt")
fi
if echo "$CHANGED_FILES" | grep -qE "android/|\.kt$"; then
  REVIEWERS+=("reviewer_android.txt")
fi
if echo "$CHANGED_FILES" | grep -qE "ios/|\.swift$"; then
  REVIEWERS+=("reviewer_mobile_native.txt")
fi
if echo "$CHANGED_FILES" | grep -qE "workers/|wrangler\.(toml|jsonc)|sync/"; then
  REVIEWERS+=("reviewer_cloudflare_sync.txt")
fi

if [ ${#REVIEWERS[@]} -eq 0 ]; then
  REVIEWERS=("reviewer_sec.txt" "reviewer_arch.txt")
fi

echo "Running adversarial review via [$LLM_RUNNER] with: ${REVIEWERS[*]}"

FEEDBACK=""
ALL_APPROVED=true

for REV in "${REVIEWERS[@]}"; do
  PROMPT_FILE="${PROMPTS_DIR}/$REV"
  if [ -f "$PROMPT_FILE" ]; then
    echo "Evaluating with $REV..."
    if [ "$LLM_RUNNER" = "agy" ]; then
      OUT=$(echo "$DIFF" | agy -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --print-timeout 15m0s 2>&1 || true)
    elif [ "$LLM_RUNNER" = "agy-claude" ]; then
      OUT=$(echo "$DIFF" | agy -m "Claude 3.7 Sonnet" -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --print-timeout 15m0s 2>&1 || true)
    elif [ "$LLM_RUNNER" = "cursor-agent" ]; then
      OUT=$(echo "$DIFF" | cursor-agent -p "$(cat "$PROMPT_FILE")" --output-format text 2>&1 || true)
    elif [ "$LLM_RUNNER" = "codex" ]; then
      OUT=$(echo "$DIFF" | codex exec "$(cat "$PROMPT_FILE")" 2>&1 || true)
    else
      OUT=$(echo "$DIFF" | claude -p "$(cat "$PROMPT_FILE")" 2>&1 || true)
    fi

    if ! echo "$OUT" | grep -q "VERDICT: APPROVED"; then
      ALL_APPROVED=false
      FEEDBACK+=$"

### Review: $REV
$OUT"
    else
      echo "  ✔ $REV: APPROVED"
    fi
  fi
done

if [ "$ALL_APPROVED" = true ]; then
  echo "✔ All specialized reviewers approved the diff."
  exit 0
else
  echo -e "\n--- REVIEW ISSUES FOUND ---"
  echo "$FEEDBACK"
  if [ -n "${HERDR_SESSION_ID:-}" ]; then
    herdr send --session "$HERDR_SESSION_ID" "$FEEDBACK"
  fi
  exit 1
fi

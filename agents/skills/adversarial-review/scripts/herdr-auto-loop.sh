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
MAX_ROUNDS="${MAX_ROUNDS:-4}"
ROUND=1

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

# Cross-platform SHA256 helper
compute_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

echo "======================================================"
echo " Starting Autonomous Adversarial Review Loop (via $LLM_RUNNER)"
echo " Base Target: $BASE_REF | Max Iterations: $MAX_ROUNDS"
echo "======================================================"

PREV_DIFF_HASH=""
TEMP_FILES=()

cleanup() {
  if [ "${#TEMP_FILES[@]:-0}" -gt 0 ]; then
    for tf in "${TEMP_FILES[@]}"; do
      if [ -n "$tf" ] && [ -f "$tf" ]; then rm -f "$tf"; fi
    done
  fi
}
trap cleanup EXIT INT TERM

while [ "$ROUND" -le "$MAX_ROUNDS" ]; do
  echo -e "\n[Round $ROUND/$MAX_ROUNDS] Computing current diff against $BASE_REF..."

  DIFF=$(git diff "$BASE_REF" -- 2>/dev/null || git diff --)

  if [ -z "$DIFF" ]; then
    echo "✔ Clean working tree / No diff detected against $BASE_REF. Exiting."
    exit 0
  fi

  # Circuit Breaker: Prevent infinite loop if diff did not change
  CURR_DIFF_HASH=$(echo "$DIFF" | compute_sha256)
  if [ "$CURR_DIFF_HASH" == "$PREV_DIFF_HASH" ]; then
    echo "✖ Error: The diff did not change after builder run. Breaking loop to prevent thrashing."
    exit 1
  fi
  PREV_DIFF_HASH="$CURR_DIFF_HASH"

  # Dynamically determine active stack reviewers based on modified files
  CHANGED_FILES=$(git diff --name-only "$BASE_REF" -- 2>/dev/null || git diff --name-only --)
  REVIEWERS=()

  if echo "$CHANGED_FILES" | grep -qE '\.rs$|Cargo\.(toml|lock)'; then
    REVIEWERS+=("reviewer_rust_backend.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'src-tauri|tauri\.conf\.json'; then
    REVIEWERS+=("reviewer_tauri_frontend.txt" "reviewer_desktop_os.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'manifest\.json|extension/'; then
    REVIEWERS+=("reviewer_extension_crossbrowser.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'android/|\.kt$'; then
    REVIEWERS+=("reviewer_android.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'ios/|\.swift$'; then
    REVIEWERS+=("reviewer_mobile_native.txt")
  fi
  if echo "$CHANGED_FILES" | grep -qE 'workers/|wrangler\.(toml|jsonc)|sync/'; then
    REVIEWERS+=("reviewer_cloudflare_sync.txt")
  fi

  if [ ${#REVIEWERS[@]} -eq 0 ]; then
    REVIEWERS=("reviewer_sec.txt" "reviewer_arch.txt")
  fi

  echo "[Round $ROUND] Running ${#REVIEWERS[@]} adversarial reviewers in parallel via $LLM_RUNNER: ${REVIEWERS[*]}"

  PIDS=()
  TEMP_FILES=()

  for i in "${!REVIEWERS[@]}"; do
    REV="${REVIEWERS[$i]}"
    PROMPT_FILE="${PROMPTS_DIR}/$REV"
    TF=$(mktemp)
    TEMP_FILES+=("$TF")

    if [ "$LLM_RUNNER" = "agy" ]; then
      (echo "$DIFF" | agy -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --print-timeout 15m0s > "$TF" 2>&1 || true) &
    elif [ "$LLM_RUNNER" = "agy-claude" ]; then
      (echo "$DIFF" | agy -m "Claude 3.7 Sonnet" -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --print-timeout 15m0s > "$TF" 2>&1 || true) &
    elif [ "$LLM_RUNNER" = "cursor-agent" ]; then
      (echo "$DIFF" | cursor-agent -p "$(cat "$PROMPT_FILE")" --output-format text > "$TF" 2>&1 || true) &
    elif [ "$LLM_RUNNER" = "codex" ]; then
      (echo "$DIFF" | codex exec "$(cat "$PROMPT_FILE")" > "$TF" 2>&1 || true) &
    else
      (echo "$DIFF" | claude -p "$(cat "$PROMPT_FILE")" > "$TF" 2>&1 || true) &
    fi
    PIDS+=($!)
  done

  # Wait for all parallel reviewers
  for pid in "${PIDS[@]}"; do
    wait "$pid"
  done

  ALL_APPROVED=true
  FEEDBACK_ITEMS=""

  for i in "${!REVIEWERS[@]}"; do
    REV="${REVIEWERS[$i]}"
    TF="${TEMP_FILES[$i]}"
    OUT=$(cat "$TF" 2>/dev/null || echo "")

    if echo "$OUT" | grep -q "VERDICT: APPROVED"; then
      echo "  ✔ $REV: APPROVED"
    else
      ALL_APPROVED=false
      echo "  ✖ $REV: ISSUES FOUND"
      FEEDBACK_ITEMS+=$'\n\n'"=== Reviewer: ${REV} ==="$'\n'"${OUT}"
    fi
  done

  # Clean temporary files for this round
  cleanup
  TEMP_FILES=()

  if [ "$ALL_APPROVED" = true ]; then
    echo -e "\n======================================================"
    echo "✔ SUCCESS: All adversarial reviewers approved the changes!"
    echo "======================================================"
    exit 0
  fi

  FEEDBACK_PAYLOAD="You have received adversarial critique on your latest diff from specialized reviewers.
Review their feedback carefully, edit the files to fix every valid issue, ensure build/tests pass, and do NOT exit until all changes are written.
${FEEDBACK_ITEMS}"

  echo -e "\n[Round $ROUND] Dispatching feedback to Main Builder Agent ($LLM_RUNNER)..."

  if [ -n "${HERDR_SESSION_ID:-}" ]; then
    herdr send --session "$HERDR_SESSION_ID" --await-completion "$FEEDBACK_PAYLOAD"
  elif [ "$LLM_RUNNER" = "agy" ]; then
    echo "$FEEDBACK_PAYLOAD" | agy -p "Fix the code according to the adversarial feedback. Edit files until issues are resolved." --dangerously-skip-permissions --print-timeout 20m0s
  elif [ "$LLM_RUNNER" = "agy-claude" ]; then
    echo "$FEEDBACK_PAYLOAD" | agy -m "Claude 3.7 Sonnet" -p "Fix the code according to the adversarial feedback. Edit files until issues are resolved." --dangerously-skip-permissions --print-timeout 20m0s
  elif [ "$LLM_RUNNER" = "cursor-agent" ]; then
    echo "$FEEDBACK_PAYLOAD" | cursor-agent -p "Fix the code according to the feedback"
  elif [ "$LLM_RUNNER" = "codex" ]; then
    echo "$FEEDBACK_PAYLOAD" | codex exec "Fix the code according to the feedback"
  else
    echo "$FEEDBACK_PAYLOAD" | claude -p "Fix the code according to the feedback"
  fi

  echo "[Round $ROUND] Builder agent completed updates. Re-evaluating diff..."
  ROUND=$((ROUND + 1))
done

echo -e "\n✖ FAILED: Maximum review iterations ($MAX_ROUNDS) reached without unanimous approval."
exit 1

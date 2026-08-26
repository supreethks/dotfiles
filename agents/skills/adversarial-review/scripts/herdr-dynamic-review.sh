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

# Defense against argument injection: separate ref from path with --
DIFF=$(git diff "$BASE_REF" -- 2>/dev/null || git diff --)
if [ -z "$DIFF" ]; then
  echo "No diff found against $BASE_REF."
  exit 0
fi

# Detect available LLM CLI (agy -> codex -> cursor-agent -> claude)
if command -v agy >/dev/null 2>&1 && agy --version >/dev/null 2>&1; then
  LLM_RUNNER="agy"
elif command -v codex >/dev/null 2>&1; then
  LLM_RUNNER="codex"
elif command -v cursor-agent >/dev/null 2>&1; then
  LLM_RUNNER="cursor-agent"
elif command -v claude >/dev/null 2>&1; then
  LLM_RUNNER="claude"
else
  echo "Error: Neither agy, codex, cursor-agent, nor claude CLI was found in PATH."
  exit 1
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
if echo "$CHANGED_FILES" | grep -qE "android/|ios/|\.kt$|\.swift$"; then
  REVIEWERS+=("reviewer_mobile_native.txt")
fi
if echo "$CHANGED_FILES" | grep -qE "workers/|wrangler\.(toml|jsonc)|sync/"; then
  REVIEWERS+=("reviewer_cloudflare_sync.txt")
fi

if [ ${#REVIEWERS[@]} -eq 0 ]; then
  REVIEWERS=("reviewer_sec.txt" "reviewer_arch.txt")
fi

echo "Running adversarial review ($LLM_RUNNER) with: ${REVIEWERS[*]}"

FEEDBACK=""
ALL_APPROVED=true

for REV in "${REVIEWERS[@]}"; do
  PROMPT_FILE="${PROMPTS_DIR}/$REV"
  if [ -f "$PROMPT_FILE" ]; then
    echo "Evaluating with $REV..."
    if [ "$LLM_RUNNER" = "agy" ]; then
      OUT=$(echo "$DIFF" | agy -p "$(cat "$PROMPT_FILE")" --no-context 2>&1 || true)
    elif [ "$LLM_RUNNER" = "codex" ]; then
      OUT=$(echo "$DIFF" | codex exec "$(cat "$PROMPT_FILE")" 2>&1 || true)
    elif [ "$LLM_RUNNER" = "cursor-agent" ]; then
      OUT=$(echo "$DIFF" | cursor-agent -p "$(cat "$PROMPT_FILE")" --output-format text 2>&1 || true)
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
  echo -e "
--- REVIEW ISSUES FOUND ---"
  echo "$FEEDBACK"
  if [ -n "${HERDR_SESSION_ID:-}" ]; then
    herdr send --session "$HERDR_SESSION_ID" "$FEEDBACK"
  fi
  exit 1
fi

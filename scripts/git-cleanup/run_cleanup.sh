#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/cleanup.py"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/cleanup.log"
ERR_FILE="$LOG_DIR/cleanup.err.log"

mkdir -p "$LOG_DIR"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export HOME="/Users/supreethks"

case "${1:-run}" in
  logs|log)
    touch "$LOG_FILE"
    tail -f "$LOG_FILE"
    ;;
  errors|err)
    touch "$ERR_FILE"
    tail -f "$ERR_FILE"
    ;;
  dry-run|--dry-run)
    shift || true
    /usr/bin/python3 "$PYTHON_SCRIPT" --dry-run "$@"
    ;;
  interactive)
    shift || true
    /usr/bin/python3 "$PYTHON_SCRIPT" "$@"
    ;;
  *)
    # Default execution (used by cron, reboot, or background runs)
    # Directs standard output to cleanup.log and standard error to cleanup.err.log
    /usr/bin/python3 "$PYTHON_SCRIPT" "$@" >> "$LOG_FILE" 2>> "$ERR_FILE"
    ;;
esac

#!/usr/bin/env bash
# Hash all package files and optionally set verdict in manifest via env QA_VERDICT.
set -euo pipefail

DIR="${1:?qa package directory required}"
VERDICT="${QA_VERDICT:-}"

if [ ! -d "$DIR" ]; then
  echo "Error: not a directory: $DIR" >&2
  exit 1
fi

(
  cd "$DIR"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS
)

if [ -n "$VERDICT" ]; then
  case "$VERDICT" in
    APPROVED|REJECTED|INCONCLUSIVE|PENDING) ;;
    *) echo "Error: invalid QA_VERDICT=$VERDICT" >&2; exit 1 ;;
  esac
  if command -v python3 >/dev/null 2>&1; then
    QA_VERDICT="$VERDICT" DIR="$DIR" python3 - <<'PY'
import json, os
path = os.path.join(os.environ["DIR"], "manifest.json")
with open(path) as f:
    data = json.load(f)
data["verdict"] = os.environ["QA_VERDICT"]
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
  fi
  # Ensure REPORT carries the verdict line
  if grep -q '^\- \*\*VERDICT\*\*:' "$DIR/REPORT.md" 2>/dev/null; then
    sed -i.bak "s/^- \\*\\*VERDICT\\*\\*:.*/- **VERDICT**: $VERDICT/" "$DIR/REPORT.md" && rm -f "$DIR/REPORT.md.bak"
  else
    echo "- **VERDICT**: $VERDICT" >> "$DIR/REPORT.md"
  fi
fi

echo "Finalized $DIR"
[ -n "$VERDICT" ] && echo "VERDICT: $VERDICT"

#!/usr/bin/env bash
# Resolve per-repo adversarial QA config. Prints KEY=value lines suitable for: eval "$(resolve-qa-config.sh)"
# Precedence: existing non-empty env > .adversarial-qa.json values > defaults for package_root only.
set -euo pipefail

ROOT="${QA_REPO_ROOT:-$PWD}"
CONFIG_PATH="${QA_CONFIG_PATH:-}"

if [ -z "$CONFIG_PATH" ]; then
  dir="$ROOT"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.adversarial-qa.json" ]; then
      CONFIG_PATH="$dir/.adversarial-qa.json"
      break
    fi
    dir=$(dirname "$dir")
  done
fi

export CONFIG_PATH ROOT
python3 - <<'PY'
import json, os, shlex

def emit(key: str, file_val: str, default: str = "") -> None:
    env = os.environ.get(key, "").strip()
    if env:
        print(f"{key}={shlex.quote(env)}")
        return
    val = (file_val or default or "").strip()
    if val:
        print(f"{key}={shlex.quote(val)}")

data = {}
path = os.environ.get("CONFIG_PATH") or ""
if path and os.path.isfile(path):
    with open(path) as f:
        data = json.load(f)
    print(f"QA_CONFIG_PATH={shlex.quote(path)}")

pl = data.get("primary_launch") or {}
an = data.get("android") or {}
ios = data.get("ios") or {}

emit("QA_PROJECT", str(data.get("project") or ""))
emit("QA_TART_VM", str(data.get("tart_vm") or ""))
emit("QA_PACKAGE_ROOT", str(data.get("package_root") or ""), "qa-packages")
emit("QA_DEBUG_BUILD_COMMAND", str(data.get("debug_build_command") or ""))
emit("QA_PRIMARY_LAUNCH_KIND", str(pl.get("kind") or ""))
emit("QA_PRIMARY_LAUNCH_VALUE", str(pl.get("value") or ""))
emit("QA_WEBSITE_URL", str(data.get("website_url") or ""))
emit("QA_ANDROID_PACKAGE", str(an.get("package_id") or ""))
emit("QA_ANDROID_ACTIVITY", str(an.get("main_activity") or ""))
emit("QA_ANDROID_APK_GLOB", str(an.get("apk_path_glob") or ""))
emit("QA_IOS_SCHEME", str(ios.get("scheme") or ""))
emit("QA_IOS_BUNDLE", str(ios.get("bundle_id") or ""))
emit("QA_IOS_SIMULATOR", str(ios.get("simulator_name") or ""))
PY

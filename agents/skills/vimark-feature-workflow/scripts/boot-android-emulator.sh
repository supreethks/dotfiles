#!/usr/bin/env bash
# Boot the ViMark-only Pixel 8 clone on a reserved console port.
set -euo pipefail

AVD_NAME="${VIMARK_AVD_NAME:-Vimark_Pixel_8}"
CONSOLE_PORT="${VIMARK_EMULATOR_PORT:-5574}"
SERIAL="emulator-${CONSOLE_PORT}"
EMULATOR="${ANDROID_HOME:-$HOME/Library/Android/sdk}/emulator/emulator"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

if "$ADB" devices | awk 'NR>1 {print $1}' | grep -qx "$SERIAL"; then
  echo "Already running: $SERIAL ($AVD_NAME)"
  exit 0
fi

"$EMULATOR" -avd "$AVD_NAME" -port "$CONSOLE_PORT" -no-snapshot-load -no-boot-anim "$@" &
"$ADB" -s "$SERIAL" wait-for-device
"$ADB" -s "$SERIAL" shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'
echo "Ready: ANDROID_SERIAL=$SERIAL AVD=$AVD_NAME"

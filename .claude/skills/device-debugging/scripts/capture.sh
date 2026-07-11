#!/bin/bash
# Capture adb logcat to a timestamped file (or --dump the current buffer).
# Handles the gotcha that `adb logcat -c && adb logcat` can hang: the buffer
# clear must run as its own command, never chained into a pipeline.
set -o pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
mkdir -p "${PROJECT_ROOT}/logs"
OUT="${PROJECT_ROOT}/logs/device-$(date +%Y-%m-%d-%H%M%S).log"

if ! adb devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  echo "ERROR: no device connected (adb devices shows none authorized)." >&2
  exit 1
fi

if [ "$1" = "--dump" ]; then
  adb logcat -v threadtime -d > "$OUT"
  echo "Dumped current buffer to $OUT"
  exit 0
fi

echo "Clearing logcat buffer..."
adb logcat -c   # deliberately its own command; do not chain
echo "Capturing to $OUT — launch the app and reproduce now. Ctrl-C to stop."
trap 'echo; echo "Capture stopped: $OUT"' INT
adb logcat -v threadtime > "$OUT"

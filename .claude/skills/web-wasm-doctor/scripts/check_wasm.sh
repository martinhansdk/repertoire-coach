#!/bin/bash
# Verify (and with --fix, repair) the vendored web WASM artifacts against
# pubspec.yaml. See SKILL.md in this directory.
set -o pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PUBSPEC="${PROJECT_ROOT}/pubspec.yaml"
WEB="${PROJECT_ROOT}/web"
STAMP="${WEB}/.wasm-versions"
FIX=0
[ "$1" = "--fix" ] && FIX=1

ver() { grep -E "^  $1:" "$PUBSPEC" | head -1 | sed -E 's/.*\^?([0-9]+\.[0-9]+\.[0-9]+).*/\1/'; }
DRIFT_VER="$(ver drift)"
SQLITE_VER="$(ver sqlite3)"
if [ -z "$DRIFT_VER" ] || [ -z "$SQLITE_VER" ]; then
  echo "ERROR: could not read drift/sqlite3 versions from pubspec.yaml" >&2
  exit 2
fi

DRIFT_URL="https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VER}/drift_worker.dart.js"
SQLITE_URL="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE_VER}/sqlite3.wasm"

stamped() { grep -E "^$1=" "$STAMP" 2>/dev/null | cut -d= -f2; }

status=0
report() { # name pubspecVer stampVer file url
  local name="$1" want="$2" have="$3" file="$4" url="$5"
  if [ ! -f "$file" ]; then
    echo "MISSING  $name: $file does not exist (want $want)"; status=1
  elif [ -z "$have" ]; then
    echo "UNKNOWN  $name: deployed version not recorded (want $want)."
    echo "         If you see LinkErrors, run with --fix."
  elif [ "$have" != "$want" ]; then
    echo "MISMATCH $name: deployed $have, pubspec wants $want"; status=1
  else
    echo "OK       $name: $want"
  fi
  [ $status -ne 0 ] && echo "         download: $url"
}

report "drift_worker.dart.js" "$DRIFT_VER" "$(stamped drift)" "${WEB}/drift_worker.dart.js" "$DRIFT_URL"
report "sqlite3.wasm"        "$SQLITE_VER" "$(stamped sqlite3)" "${WEB}/sqlite3.wasm" "$SQLITE_URL"

if [ $FIX -eq 1 ]; then
  echo "--- fixing ---"
  curl -fSL -o "${WEB}/drift_worker.dart.js" "$DRIFT_URL" || { echo "download failed: $DRIFT_URL (check the release's asset name in a browser)"; exit 3; }
  curl -fSL -o "${WEB}/sqlite3.wasm" "$SQLITE_URL" || { echo "download failed: $SQLITE_URL (check the release's asset name in a browser)"; exit 3; }
  printf 'drift=%s\nsqlite3=%s\n' "$DRIFT_VER" "$SQLITE_VER" > "$STAMP"
  echo "Downloaded matching artifacts and recorded versions in web/.wasm-versions"
  echo "Now restart the dev server with cache clear:"
  echo "  bash .claude/skills/web-wasm-doctor/scripts/restart_web.sh --clear-cache"
elif [ $status -ne 0 ]; then
  echo "Run with --fix to download matching artifacts."
fi
exit $status

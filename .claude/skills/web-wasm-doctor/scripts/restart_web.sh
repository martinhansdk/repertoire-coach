#!/bin/bash
# Fully restart the Flutter web dev server (fixes corrupted hot-reload state).
# --clear-cache additionally removes .dart_tool/build (use after WASM swaps).
set -o pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

CONTAINER=$(docker ps --filter "publish=8080" --format "{{.ID}}")
if [ -n "$CONTAINER" ]; then
  echo "Killing dev server container $CONTAINER"
  docker kill "$CONTAINER" >/dev/null
else
  echo "No container publishing :8080 found (server may already be down)"
fi

if [ "$1" = "--clear-cache" ]; then
  echo "Clearing .dart_tool/build"
  rm -rf "${PROJECT_ROOT}/.dart_tool/build"
fi

echo "Starting fresh dev server (wait for 'lib/main.dart is being served')..."
exec "${PROJECT_ROOT}/scripts/run-web.sh"

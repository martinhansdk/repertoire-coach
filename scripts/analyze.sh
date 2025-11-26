#!/bin/bash
set -o pipefail

# Flutter analyze script with concise output and detailed logging
# Usage: ./scripts/analyze.sh

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/analyze-${TIMESTAMP}.log"

echo "Running flutter analyze..."

# Run inside docker and capture all output to log file
# Use root user in CI to avoid permission issues with mounted volumes
if [ -n "$CI" ]; then
  DOCKER_USER="--user root"
  DOCKER_ENV="-e CI=true"
else
  DOCKER_USER=""
  DOCKER_ENV=""
fi

docker run --rm $DOCKER_USER $DOCKER_ENV \
  -v "${PROJECT_ROOT}:/app" \
  repertoire-coach-builder \
  sh -c '
    if [ -n "$CI" ]; then
      git config --global --add safe.directory /opt/flutter
    fi
    flutter pub get
    flutter analyze
  ' > "$LOGFILE" 2>&1

EXIT_CODE=$?

# Show concise summary
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ Flutter analyze passed"
else
  echo "✗ Flutter analyze failed (exit code $EXIT_CODE)"
  echo "Last 20 lines of output:"
  tail -20 "$LOGFILE"
fi

echo "Full log: $LOGFILE"
exit $EXIT_CODE

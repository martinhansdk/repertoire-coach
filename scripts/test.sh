#!/bin/bash
set -o pipefail

# Flutter test script with concise output and detailed logging
# Usage: ./scripts/test.sh

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/test-${TIMESTAMP}.log"

echo "Running flutter test..."

# Run inside docker and capture all output to log file
# Use root user in CI to avoid permission issues with mounted volumes
if [ -n "$CI" ]; then
  DOCKER_USER="--user root"
else
  DOCKER_USER=""
fi

docker run --rm $DOCKER_USER \
  -v "${PROJECT_ROOT}:/app" \
  repertoire-coach-builder \
  sh -c '
    flutter pub get
    flutter test
  ' > "$LOGFILE" 2>&1

EXIT_CODE=$?

# Show concise summary
if [ $EXIT_CODE -eq 0 ]; then
  # Count passing tests
  PASS_COUNT=$(grep -c "All tests passed" "$LOGFILE" 2>/dev/null || echo "0")
  echo "✓ Flutter tests passed"
else
  echo "✗ Flutter tests failed (exit code $EXIT_CODE)"
  echo "Last 20 lines of output:"
  tail -20 "$LOGFILE"
fi

echo "Full log: $LOGFILE"
exit $EXIT_CODE

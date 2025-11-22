#!/bin/bash
set -e
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

# Run inside docker with script logic
docker run --rm \
  -v "${PROJECT_ROOT}:/app" \
  repertoire-coach-builder \
  sh -c '
    echo "Running flutter pub get..."
    flutter pub get
    echo ""
    echo "Running flutter test..."
    flutter test
  ' 2>&1 | tee "$LOGFILE"

# Capture exit code (tee passes through the exit code of the first command)
exit ${PIPESTATUS[0]}

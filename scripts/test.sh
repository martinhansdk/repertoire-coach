#!/bin/bash
set -e
set -o pipefail

# Flutter test script with concise output and detailed logging
# Usage: ./scripts/test.sh [--verbose]

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Parse arguments
VERBOSE=false
if [ "$1" = "--verbose" ]; then
  VERBOSE=true
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="logs/test-${TIMESTAMP}.log"

echo "Running flutter test..."

# Run flutter test and capture output
if docker run --rm \
  -v "$(pwd):/app" \
  repertoire-coach-builder \
  sh -c 'flutter pub get >/dev/null 2>&1 && flutter test' \
  > "$LOGFILE" 2>&1; then

  # Success - parse test results
  SUMMARY=$(tail -1 "$LOGFILE" 2>/dev/null || echo "")

  # Extract counts from summary line (format: "00:10 +82 -3: All tests passed!")
  PASSED=$(echo "$SUMMARY" | grep -oP '\+\K[0-9]+' || echo "0")
  FAILED=$(echo "$SUMMARY" | grep -oP '\-\K[0-9]+' || echo "0")
  SKIPPED=$(grep -c "skip: true\|Skip:" "$LOGFILE" 2>/dev/null || echo "0")

  if [ "$VERBOSE" = true ]; then
    cat "$LOGFILE"
  fi

  if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Tests complete - $PASSED passed, $SKIPPED skipped, $FAILED failed"
    exit 0
  else
    echo -e "${YELLOW}⚠${NC} Tests complete - $PASSED passed, $SKIPPED skipped, $FAILED failed"
    echo "  See $LOGFILE for details"
    exit 1
  fi
else
  # Failure - test execution failed
  if [ "$VERBOSE" = true ]; then
    cat "$LOGFILE"
  fi

  # Try to parse test results even on failure
  FAILED=$(grep -oP '00:[0-9]+ \+[0-9]+ \-\K[0-9]+' "$LOGFILE" 2>/dev/null | tail -1 || echo "?")

  echo -e "${RED}✗${NC} Tests failed - $FAILED test(s) failed"
  echo "  See $LOGFILE for details"
  exit 1
fi

#!/bin/bash
set -e
set -o pipefail

# Flutter analyze script with concise output and detailed logging
# Usage: ./scripts/analyze.sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="logs/analyze-${TIMESTAMP}.log"

echo "Running flutter analyze..."

# Run flutter analyze and capture output
if docker run --rm \
  -v "$(pwd):/app" \
  repertoire-coach-builder \
  sh -c 'flutter pub get >/dev/null 2>&1 && flutter analyze' \
  > "$LOGFILE" 2>&1; then

  # Success - no issues found
  echo -e "${GREEN}✓${NC} Analysis complete - No issues found"
  exit 0
else
  # Failure - count issues
  ISSUE_COUNT=$(grep -c "error •\|warning •\|info •" "$LOGFILE" 2>/dev/null || echo "unknown")

  if [ "$ISSUE_COUNT" != "unknown" ] && [ "$ISSUE_COUNT" -gt 0 ]; then
    echo -e "${RED}✗${NC} Analysis failed - $ISSUE_COUNT issues found"
  else
    echo -e "${RED}✗${NC} Analysis failed"
  fi

  echo "  See $LOGFILE for details"
  exit 1
fi

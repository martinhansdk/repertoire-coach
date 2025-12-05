#!/bin/bash

# Generate test coverage report
# Usage: ./scripts/coverage.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Generating test coverage..."

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_DIR/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOG_FILE="$PROJECT_DIR/logs/coverage-$TIMESTAMP.log"

# Run tests with coverage (pub get is run automatically if needed)
docker run --rm \
  -v "$PROJECT_DIR":/workspace \
  -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "flutter pub get > /dev/null 2>&1 && flutter test --coverage" 2>&1 | tee "$LOG_FILE"

# Check if coverage was generated
if [ -f "$PROJECT_DIR/coverage/lcov.info" ]; then
  echo -e "${GREEN}✓${NC} Coverage report generated: coverage/lcov.info"
  echo "Full log: $LOG_FILE"

  # Calculate coverage percentage if lcov is available
  if command -v lcov &> /dev/null; then
    COVERAGE_SUMMARY=$(lcov --summary "$PROJECT_DIR/coverage/lcov.info" 2>&1 | grep "lines......" | awk '{print $2}')
    echo -e "${GREEN}Coverage: $COVERAGE_SUMMARY${NC}"
  fi

  exit 0
else
  echo -e "${RED}✗${NC} Coverage generation failed"
  echo "Full log: $LOG_FILE"
  exit 1
fi

#!/bin/bash
set -e

# Flutter validation script - runs analyze and test
# Usage: ./scripts/validate.sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run analyze
if ! "$SCRIPT_DIR/analyze.sh"; then
  echo ""
  echo -e "${RED}✗${NC} Validation failed"
  exit 1
fi

echo ""

# Run tests
if ! "$SCRIPT_DIR/test.sh"; then
  echo ""
  echo -e "${RED}✗${NC} Validation failed"
  exit 1
fi

echo ""
echo -e "${GREEN}✓${NC} Validation passed"
exit 0

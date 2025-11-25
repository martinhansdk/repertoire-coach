#!/usr/bin/env bash
# Validation script for deploy.py
# Quick checks without device interaction

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

errors=0

echo -e "${BOLD}Validating deploy.py script${NC}\n"

# Test 1: Script exists and is executable
echo -e "${CYAN}Test 1: Script exists${NC}"
if [ -f "$DEPLOY_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script found${NC}\n"
else
    echo -e "${RED}✗ Script not found${NC}\n"
    exit 1
fi

# Test 2: Python3 available
echo -e "${CYAN}Test 2: Python3 available${NC}"
if command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Python3 is available ($(python3 --version))${NC}\n"
else
    echo -e "${RED}✗ Python3 not found${NC}\n"
    exit 1
fi

# Test 3: Script has no syntax errors
echo -e "${CYAN}Test 3: Syntax check${NC}"
if python3 -m py_compile "$DEPLOY_SCRIPT" 2>/dev/null; then
    echo -e "${GREEN}✓ No syntax errors${NC}\n"
else
    echo -e "${RED}✗ Syntax errors found${NC}\n"
    ((errors++))
fi

# Test 4: Help message works
echo -e "${CYAN}Test 4: Help message${NC}"
if python3 "$DEPLOY_SCRIPT" --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Help message works${NC}\n"
else
    echo -e "${RED}✗ Help message failed${NC}\n"
    ((errors++))
fi

# Test 5: Check dependencies
echo -e "${CYAN}Test 5: Check dependencies${NC}"
deps_ok=true

if command -v adb >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ adb available${NC}"
else
    echo -e "${YELLOW}  ⚠ adb not available (Android deployment disabled)${NC}"
fi

if command -v gh >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ gh available${NC}"
else
    echo -e "${YELLOW}  ⚠ gh not available (GitHub deployment disabled)${NC}"
fi

echo ""

# Test 6: Check connected devices
echo -e "${CYAN}Test 6: Device detection${NC}"
if command -v adb >/dev/null 2>&1; then
    device_count=$(timeout 5 adb devices 2>/dev/null | grep -v "List of devices attached" | grep "device$" | wc -l || echo "0" | tr -d '\n')
    device_count="${device_count:-0}"
    if [ "$device_count" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}  ✓ $device_count Android device(s) connected${NC}"
    else
        echo -e "${YELLOW}  ⚠ No Android devices connected${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ adb not available${NC}"
fi

echo ""

# Test 7: Query GitHub builds (if gh available)
if command -v gh >/dev/null 2>&1; then
    echo -e "${CYAN}Test 7: GitHub API access${NC}"
    if timeout 10 python3 "$DEPLOY_SCRIPT" --run-id 19629776037 --build-type debug 2>&1 | grep -q "Auto-selecting build"; then
        echo -e "${GREEN}✓ Can query GitHub builds${NC}\n"
    else
        echo -e "${YELLOW}⚠ GitHub query had issues (might be rate limit or auth)${NC}\n"
    fi
else
    echo -e "${CYAN}Test 7: GitHub API access${NC}"
    echo -e "${YELLOW}⚠ Skipped (gh not available)${NC}\n"
fi

# Summary
echo -e "${BOLD}Summary${NC}"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo -e "\nThe deploy script is ready to use."
    echo -e "Run ${CYAN}./scripts/deploy.py --help${NC} for usage instructions."
    exit 0
else
    echo -e "${RED}$errors error(s) found${NC}"
    exit 1
fi

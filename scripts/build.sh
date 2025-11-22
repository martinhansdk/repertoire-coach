#!/bin/bash
set -e
set -o pipefail

# Flutter build script with concise output and detailed logging
# Usage: ./scripts/build.sh [android|web|ios] [--debug|--release]

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
PLATFORM=$1
BUILD_MODE=${2:-"--debug"}

if [ -z "$PLATFORM" ]; then
  echo "Usage: ./scripts/build.sh [android|web|ios] [--debug|--release]"
  exit 1
fi

if [[ ! "$PLATFORM" =~ ^(android|web|ios)$ ]]; then
  echo "Error: Platform must be one of: android, web, ios"
  exit 1
fi

if [[ ! "$BUILD_MODE" =~ ^(--debug|--release)$ ]]; then
  echo "Error: Build mode must be --debug or --release"
  exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
MODE=$(echo "$BUILD_MODE" | sed 's/--//')
LOGFILE="logs/build-${PLATFORM}-${MODE}-${TIMESTAMP}.log"

echo "Building Flutter app for $PLATFORM ($MODE mode)..."

# Build command based on platform
case $PLATFORM in
  android)
    BUILD_CMD="flutter pub get >/dev/null 2>&1 && flutter build apk $BUILD_MODE"
    ;;
  web)
    BUILD_CMD="flutter pub get >/dev/null 2>&1 && flutter build web $BUILD_MODE"
    ;;
  ios)
    BUILD_CMD="flutter pub get >/dev/null 2>&1 && flutter build ios $BUILD_MODE --no-codesign"
    ;;
esac

# Run build and capture output
if docker run --rm \
  -v "$(pwd):/app" \
  repertoire-coach-builder \
  sh -c "$BUILD_CMD" \
  > "$LOGFILE" 2>&1; then

  # Success
  echo -e "${GREEN}✓${NC} Build complete for $PLATFORM ($MODE)"
  echo "  Output: build/$PLATFORM/"
  exit 0
else
  # Failure
  echo -e "${RED}✗${NC} Build failed for $PLATFORM ($MODE)"
  echo "  See $LOGFILE for details"
  exit 1
fi

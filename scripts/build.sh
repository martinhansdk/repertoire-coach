#!/bin/bash
set -e
set -o pipefail

# Flutter build script with concise output and detailed logging
# Usage: ./scripts/build.sh [android|web|ios] [--debug|--release]

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
mkdir -p "${PROJECT_ROOT}/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
MODE=$(echo "$BUILD_MODE" | sed 's/--//')
LOGFILE="${PROJECT_ROOT}/logs/build-${PLATFORM}-${MODE}-${TIMESTAMP}.log"

echo "Building Flutter app for $PLATFORM ($MODE mode)..."

# Build command based on platform
case $PLATFORM in
  android)
    BUILD_CMD="flutter build apk $BUILD_MODE"
    ;;
  web)
    BUILD_CMD="flutter build web $BUILD_MODE"
    ;;
  ios)
    BUILD_CMD="flutter build ios $BUILD_MODE --no-codesign"
    ;;
esac

# Run inside docker with script logic
docker run --rm \
  -v "${PROJECT_ROOT}:/app" \
  repertoire-coach-builder \
  sh -c "
    echo 'Running flutter pub get...'
    flutter pub get
    echo ''
    echo 'Running flutter build...'
    $BUILD_CMD
  " 2>&1 | tee "$LOGFILE"

# Capture exit code (tee passes through the exit code of the first command)
exit ${PIPESTATUS[0]}

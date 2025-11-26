#!/bin/bash
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
  sh -c "
    flutter pub get
    $BUILD_CMD
  " > "$LOGFILE" 2>&1

EXIT_CODE=$?

# Show concise summary
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ Build succeeded for $PLATFORM ($MODE)"
else
  echo "✗ Build failed for $PLATFORM ($MODE) (exit code $EXIT_CODE)"
  echo "Last 20 lines of output:"
  tail -20 "$LOGFILE"
fi

echo "Full log: $LOGFILE"
exit $EXIT_CODE

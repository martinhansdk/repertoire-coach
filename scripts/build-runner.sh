#!/bin/bash
# Run build_runner for code generation (e.g., mocks, database code)
# Usage: scripts/build-runner.sh [--watch]

set -o pipefail

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Parse arguments
WATCH_MODE=false
if [ "$1" = "--watch" ]; then
  WATCH_MODE=true
fi

# Create logs directory
mkdir -p "${PROJECT_ROOT}/logs"
mkdir -p "${PROJECT_ROOT}/.pub-cache"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/build-runner-${TIMESTAMP}.log"

echo "Running build_runner..."

if [ "$WATCH_MODE" = true ]; then
  echo "Starting in watch mode (Ctrl+C to stop)..."
  # Watch mode - show output in terminal
  docker run --rm \
    -e PUB_CACHE=/app/.pub-cache \
    -v "${PROJECT_ROOT}":/app \
    -v "${PROJECT_ROOT}/.pub-cache":/app/.pub-cache \
    -w /app \
    ghcr.io/cirruslabs/flutter:stable \
    sh -c 'flutter pub get > /dev/null 2>&1 && flutter pub run build_runner watch --delete-conflicting-outputs'
else
  # Run build_runner in Docker
  docker run --rm \
    -e PUB_CACHE=/app/.pub-cache \
    -v "${PROJECT_ROOT}":/app \
    -v "${PROJECT_ROOT}/.pub-cache":/app/.pub-cache \
    -w /app \
    ghcr.io/cirruslabs/flutter:stable \
    sh -c 'flutter pub get > /dev/null 2>&1 && flutter pub run build_runner build --delete-conflicting-outputs' > "$LOGFILE" 2>&1

  EXIT_CODE=$?

  # Show concise summary
  if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Build runner completed successfully"
  else
    echo "✗ Build runner failed (exit code $EXIT_CODE)"
    echo "Last 20 lines of output:"
    tail -20 "$LOGFILE"
  fi

  echo "Full log: $LOGFILE"
  exit $EXIT_CODE
fi

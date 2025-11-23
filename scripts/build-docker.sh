#!/bin/bash
# Build the Flutter Docker image
# This only needs to be run once, or when Dockerfile.build changes

set -o pipefail

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/docker-build-${TIMESTAMP}.log"

echo "Building Flutter Docker image..."

# Build and capture all output to log file, show progress
docker build \
  -f "${PROJECT_ROOT}/Dockerfile.build" \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t repertoire-coach-builder \
  "${PROJECT_ROOT}" 2>&1 | tee "$LOGFILE" | grep -E "^#[0-9]+ \[(CACHED|DONE|internal|exporting|naming|writing|unpacking)|^#[0-9]+ \[[0-9]+/[0-9]+\] (FROM|RUN|COPY|ARG|ENV)|Successfully|naming to"

EXIT_CODE=${PIPESTATUS[0]}

# Show concise summary
echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ Docker image built successfully: repertoire-coach-builder"
else
  echo "✗ Docker build failed (exit code $EXIT_CODE)"
  echo "Last 20 lines of output:"
  tail -20 "$LOGFILE"
fi

echo "Full log: $LOGFILE"
exit $EXIT_CODE

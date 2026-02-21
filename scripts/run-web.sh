#!/bin/bash
# Run Flutter web development server
# Accessible at http://localhost:8080

set -o pipefail

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"
mkdir -p "${PROJECT_ROOT}/.pub-cache"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/web-run-${TIMESTAMP}.log"

echo "Starting Flutter web server..."
echo "Getting dependencies and building web assets (this may take a minute)..."
echo "Server will be available at: http://localhost:8080"
echo ""

# Load environment variables from .env if it exists
DART_DEFINES=""
if [ -f "${PROJECT_ROOT}/.env" ]; then
  echo "Loading Supabase credentials from .env file..."
  export $(grep -v '^#' "${PROJECT_ROOT}/.env" | xargs)
  if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
    DART_DEFINES="--dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
    echo "✓ Supabase configured (cloud mode enabled)"
  fi
else
  echo "⚠ No .env file found - running in offline-only mode"
fi
echo ""

# Run Flutter web server and log output
# First get dependencies, then run the web server
docker run --rm \
  -e PUB_CACHE=/app/.pub-cache \
  -v "${PROJECT_ROOT}":/app \
  -v "${PROJECT_ROOT}/.pub-cache":/app/.pub-cache \
  -w /app \
  -p 8080:8080 \
  ghcr.io/cirruslabs/flutter:stable \
  bash -c "flutter pub get && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0 --web-renderer html $DART_DEFINES" 2>&1 | tee "$LOGFILE" | grep -E "Launching|Syncing files|Running|Building|successfully|Failed|Error|Warning|is being served at|Ready|Resolving dependencies|Got dependencies|Waiting for connection"

EXIT_CODE=${PIPESTATUS[0]}

# Show summary
echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ Web server stopped"
else
  echo "✗ Web server failed (exit code $EXIT_CODE)"
  echo "Last 20 lines of output:"
  tail -20 "$LOGFILE"
fi

echo "Full log: $LOGFILE"
exit $EXIT_CODE

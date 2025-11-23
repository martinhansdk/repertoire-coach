#!/bin/bash
# Run Flutter web development server
# Accessible at http://localhost:8080

set -o pipefail

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/web-run-${TIMESTAMP}.log"

echo "Starting Flutter web server..."
echo "Getting dependencies and building web assets (this may take a minute)..."
echo "Server will be available at: http://localhost:8080"
echo ""

# Run Flutter web server and log output
# First get dependencies, then run the web server
docker run --rm \
  -v "${PROJECT_ROOT}":/app \
  -p 8080:8080 \
  repertoire-coach-builder \
  bash -c "flutter pub get && flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0" 2>&1 | tee "$LOGFILE" | grep -E "Launching|Syncing files|Running|Building|successfully|Failed|Error|Warning|is being served at|Ready|Resolving dependencies|Got dependencies|Waiting for connection"

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

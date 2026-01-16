#!/bin/bash
set -o pipefail

# Build Flutter web app for production deployment to Cloudflare Pages
# This script reads Supabase credentials from .env and bakes them into the build

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables from .env if it exists (local development)
# In CI, these should already be set as environment variables
if [ -f "${PROJECT_ROOT}/.env" ]; then
  export $(cat "${PROJECT_ROOT}/.env" | grep -v '^#' | xargs)
fi

# Validate required variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set"
  echo "Either create .env file or set environment variables"
  exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"

# Generate timestamp for log file
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
LOGFILE="${PROJECT_ROOT}/logs/build-web-release-${TIMESTAMP}.log"

echo "Building Flutter web app for production..."
echo "Supabase URL: $SUPABASE_URL"

# Run build inside docker with dart-define arguments
# Use cirruslabs/flutter image (same as run-web.sh) for consistency
# Clean up artifacts inside Docker to avoid permission issues
docker run --rm \
  -v "${PROJECT_ROOT}":/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "
    # Clean up any existing build artifacts that might have wrong permissions
    rm -rf .dart_tool build

    flutter pub get > /dev/null 2>&1
    flutter build web --release \
      --dart-define=SUPABASE_URL=$SUPABASE_URL \
      --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

    # Copy Cloudflare Pages configuration files
    if [ -f public/_headers ]; then
      cp public/_headers build/web/_headers
    fi
    if [ -f public/_redirects ]; then
      cp public/_redirects build/web/_redirects
    fi
  " > "$LOGFILE" 2>&1

EXIT_CODE=$?

# Show concise summary
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ Build succeeded"
  echo "Build output: build/web/"
  echo ""
  echo "Next steps for Cloudflare Pages:"
  echo "1. Push this repo to GitHub (if not already)"
  echo "2. Go to Cloudflare Dashboard > Pages"
  echo "3. Connect your GitHub repository"
  echo "4. Set build command: scripts/build-web-cloudflare.sh"
  echo "5. Set build output directory: build/web"
  echo "6. Deploy!"
else
  echo "✗ Build failed (exit code $EXIT_CODE)"
  echo "Last 20 lines of output:"
  tail -20 "$LOGFILE"
fi

echo "Full log: $LOGFILE"
exit $EXIT_CODE

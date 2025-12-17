#!/bin/bash
# Build APK with Supabase credentials from .env file

set -e

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables from .env
if [ ! -f "${PROJECT_ROOT}/.env" ]; then
  echo "Error: .env file not found"
  echo "Please create .env with SUPABASE_URL and SUPABASE_ANON_KEY"
  exit 1
fi

source "${PROJECT_ROOT}/.env"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL or SUPABASE_ANON_KEY not set in .env"
  exit 1
fi

echo "Building Android APK with Supabase credentials..."
echo "Supabase URL: ${SUPABASE_URL:0:30}..."

docker run --rm \
  -v "${PROJECT_ROOT}":/workspace \
  -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  flutter build apk --debug \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo ""
echo "✓ Build complete!"
echo "APK location: build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "To deploy to your device, run:"
echo "  ./scripts/deploy.py --local --build-type debug"

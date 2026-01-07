#!/bin/bash
set -e

# Build script for Cloudflare Pages CI/CD
# This script is run by Cloudflare Pages during deployment
#
# Environment variables (set in Cloudflare Pages dashboard):
# - SUPABASE_URL: Your Supabase project URL
# - SUPABASE_ANON_KEY: Your Supabase anonymous key
#
# Build configuration in Cloudflare Pages:
# - Build command: scripts/build-web-cloudflare.sh
# - Build output directory: build/web
# - Root directory: (leave blank)

echo "Starting Cloudflare Pages build..."

# Validate required environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in Cloudflare Pages environment variables"
  exit 1
fi

echo "Environment variables configured ✓"

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify Flutter installation
flutter --version

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build web app with Supabase credentials baked in
echo "Building web app..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Copy Cloudflare Pages configuration files
echo "Copying Cloudflare configuration..."
if [ -f public/_headers ]; then
  cp public/_headers build/web/_headers
fi
if [ -f public/_redirects ]; then
  cp public/_redirects build/web/_redirects
fi

echo "Build complete! Output in build/web/"

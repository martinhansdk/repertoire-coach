#!/bin/bash
set -e

# Sync local keystore to GitHub secrets
# This ensures GitHub builds use the same signing key as local builds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$REPO_ROOT/android"
KEYSTORE_FILE="$ANDROID_DIR/upload-keystore.jks"
KEY_PROPERTIES="$ANDROID_DIR/key.properties"

echo "Syncing local keystore to GitHub secrets..."
echo "This will make GitHub builds use your local signing key."
echo ""

# Check if keystore exists
if [ ! -f "$KEYSTORE_FILE" ]; then
    echo "Error: Local keystore not found at $KEYSTORE_FILE"
    exit 1
fi

if [ ! -f "$KEY_PROPERTIES" ]; then
    echo "Error: key.properties not found at $KEY_PROPERTIES"
    exit 1
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required"
    echo "Install with: sudo apt install gh"
    exit 1
fi

# Encode keystore
echo "Encoding keystore..."
KEYSTORE_BASE64=$(base64 -w 0 "$KEYSTORE_FILE")

# Read key.properties
echo "Reading key.properties..."
STORE_PASSWORD=$(grep "storePassword=" "$KEY_PROPERTIES" | cut -d'=' -f2)
KEY_PASSWORD=$(grep "keyPassword=" "$KEY_PROPERTIES" | cut -d'=' -f2)
KEY_ALIAS=$(grep "keyAlias=" "$KEY_PROPERTIES" | cut -d'=' -f2)

if [ -z "$STORE_PASSWORD" ] || [ -z "$KEY_PASSWORD" ] || [ -z "$KEY_ALIAS" ]; then
    echo "Error: Could not read passwords/alias from key.properties"
    exit 1
fi

echo ""
echo "Ready to update GitHub secrets:"
echo "  - ANDROID_KEYSTORE_BASE64 (keystore file)"
echo "  - ANDROID_KEYSTORE_PASSWORD"
echo "  - ANDROID_KEY_PASSWORD"
echo "  - ANDROID_KEY_ALIAS"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Update secrets
echo "Updating secrets..."
echo "$KEYSTORE_BASE64" | gh secret set ANDROID_KEYSTORE_BASE64
echo "$STORE_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD
echo "$KEY_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD
echo "$KEY_ALIAS" | gh secret set ANDROID_KEY_ALIAS

echo ""
echo "✓ GitHub secrets updated successfully"
echo ""
echo "Next steps:"
echo "1. Trigger a new GitHub Actions build"
echo "2. GitHub builds will now use your local signing key"
echo "3. You can upgrade between local and GitHub builds without losing data"

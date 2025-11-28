#!/bin/bash
set -e

echo "=========================================="
echo "Android Release Signing Setup"
echo "=========================================="
echo ""
echo "This script will help you set up Android release signing for CI/CD."
echo ""

# Check if keystore already exists
if [ -f "android/upload-keystore.jks" ]; then
    echo "⚠️  Warning: android/upload-keystore.jks already exists!"
    read -p "Do you want to create a new keystore? This will overwrite the existing one. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Using existing keystore."
        exit 0
    fi
fi

echo "Step 1: Generate keystore"
echo "--------------------------"
echo ""

# Prompt for passwords
read -sp "Enter keystore password (min 6 chars): " STORE_PASSWORD
echo
read -sp "Confirm keystore password: " STORE_PASSWORD_CONFIRM
echo

if [ "$STORE_PASSWORD" != "$STORE_PASSWORD_CONFIRM" ]; then
    echo "❌ Passwords don't match!"
    exit 1
fi

if [ ${#STORE_PASSWORD} -lt 6 ]; then
    echo "❌ Password must be at least 6 characters!"
    exit 1
fi

read -sp "Enter key password (min 6 chars, can be same as keystore password): " KEY_PASSWORD
echo
read -sp "Confirm key password: " KEY_PASSWORD_CONFIRM
echo

if [ "$KEY_PASSWORD" != "$KEY_PASSWORD_CONFIRM" ]; then
    echo "❌ Passwords don't match!"
    exit 1
fi

if [ ${#KEY_PASSWORD} -lt 6 ]; then
    echo "❌ Password must be at least 6 characters!"
    exit 1
fi

echo ""
echo "Enter certificate details (or press Enter for defaults):"
read -p "Your name: " CERT_NAME
read -p "Organization: " CERT_ORG
read -p "City: " CERT_CITY
read -p "State/Province: " CERT_STATE
read -p "Country (2-letter code, e.g., US): " CERT_COUNTRY

# Set defaults
CERT_NAME=${CERT_NAME:-"Repertoire Coach"}
CERT_ORG=${CERT_ORG:-"Repertoire Coach"}
CERT_CITY=${CERT_CITY:-"Unknown"}
CERT_STATE=${CERT_STATE:-"Unknown"}
CERT_COUNTRY=${CERT_COUNTRY:-"US"}

# Generate keystore
echo ""
echo "Generating keystore..."
keytool -genkey -v \
    -keystore android/upload-keystore.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias upload \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=$CERT_NAME, OU=$CERT_ORG, O=$CERT_ORG, L=$CERT_CITY, ST=$CERT_STATE, C=$CERT_COUNTRY"

echo "✅ Keystore generated: android/upload-keystore.jks"
echo ""

# Create key.properties for local builds
echo "Step 2: Create key.properties"
echo "------------------------------"
echo ""
cat > android/key.properties <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
EOF
echo "✅ Created android/key.properties (for local builds)"
echo ""

# Convert keystore to base64 for GitHub Secrets
echo "Step 3: Prepare for GitHub Secrets"
echo "-----------------------------------"
echo ""
KEYSTORE_BASE64=$(base64 -i android/upload-keystore.jks | tr -d '\n')

echo "Add these secrets to your GitHub repository:"
echo ""
echo "Go to: Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo "Secret 1: ANDROID_KEYSTORE_BASE64"
echo "Value:"
echo "$KEYSTORE_BASE64"
echo ""
echo "Secret 2: ANDROID_KEYSTORE_PASSWORD"
echo "Value: $STORE_PASSWORD"
echo ""
echo "Secret 3: ANDROID_KEY_PASSWORD"
echo "Value: $KEY_PASSWORD"
echo ""
echo "Secret 4: ANDROID_KEY_ALIAS"
echo "Value: upload"
echo ""

# Save to file for easy copying
cat > android/github-secrets.txt <<EOF
Add these secrets to GitHub repository:
Settings → Secrets and variables → Actions → New repository secret

ANDROID_KEYSTORE_BASE64:
$KEYSTORE_BASE64

ANDROID_KEYSTORE_PASSWORD:
$STORE_PASSWORD

ANDROID_KEY_PASSWORD:
$KEY_PASSWORD

ANDROID_KEY_ALIAS:
upload
EOF

echo "✅ Secrets also saved to android/github-secrets.txt"
echo ""
echo "⚠️  IMPORTANT: Keep these secrets safe!"
echo "⚠️  DO NOT commit android/key.properties or android/github-secrets.txt to git"
echo "⚠️  DO NOT share these secrets publicly"
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Add the secrets to GitHub (see above)"
echo "2. Update .github/workflows/build.yml to use the secrets"
echo "3. Test a release build locally: ./scripts/build.sh android --release"
echo "4. Test a CI build by pushing to main branch"
echo ""

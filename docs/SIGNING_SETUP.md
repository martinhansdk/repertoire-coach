# Android Release Signing Setup

This guide explains how to set up consistent Android release signing for CI/CD builds.

## Problem

Without proper signing configuration, each CI build uses a different debug keystore, causing signature mismatches. This forces users to uninstall and reinstall the app (losing all data) every time they install a new build.

## Solution

Set up a single release keystore that's used consistently for all release builds.

## Setup Steps

### 1. Generate Keystore (One-time setup)

Run the setup script:

```bash
./scripts/setup-signing.sh
```

This script will:
- Generate a keystore file (`android/upload-keystore.jks`)
- Create `android/key.properties` for local builds
- Convert the keystore to base64 for GitHub Secrets
- Output the secrets you need to add to GitHub

**Important:** The keystore and key.properties files are already in `.gitignore` and should NEVER be committed to the repository!

### 2. Add Secrets to GitHub

Go to your repository on GitHub:
1. Navigate to **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add each of the following secrets (values provided by the setup script):

| Secret Name | Description |
|-------------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias (usually "upload") |

### 3. Update CI Workflow

**Note:** The workflow file (`.github/workflows/build.yml`) needs to be updated to use these secrets. Since workflow files require special permissions, you'll need to apply these changes manually.

Add the following steps to the `build-android` job in `.github/workflows/build.yml`, **before** the "Build Android APK (Release)" step:

```yaml
    - name: Decode keystore
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      run: |
        echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/upload-keystore.jks

    - name: Create key.properties
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      run: |
        cat > android/key.properties <<EOF
        storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
        keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
        keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
        storeFile=upload-keystore.jks
        EOF
```

**Complete example** of the updated `build-android` job:

```yaml
  build-android:
    needs: build-docker
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Log in to GitHub Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Pull pre-built Docker image
      run: |
        docker pull ${{ needs.build-docker.outputs.image-tag }}
        docker tag ${{ needs.build-docker.outputs.image-tag }} repertoire-coach-builder

    - name: Build Android APK (Debug)
      run: ./scripts/build.sh android --debug

    - name: Upload APK artifact
      uses: actions/upload-artifact@v4
      with:
        name: android-debug-apk
        path: build/app/outputs/flutter-apk/app-debug.apk
        retention-days: 7

    # NEW: Decode keystore for release builds
    - name: Decode keystore
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      run: |
        echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/upload-keystore.jks

    # NEW: Create key.properties for release builds
    - name: Create key.properties
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      run: |
        cat > android/key.properties <<EOF
        storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
        keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
        keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
        storeFile=upload-keystore.jks
        EOF

    - name: Build Android APK (Release)
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      run: ./scripts/build.sh android --release

    - name: Upload Release APK artifact
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      uses: actions/upload-artifact@v4
      with:
        name: android-release-apk
        path: build/app/outputs/flutter-apk/app-release.apk
        retention-days: 30
```

### 4. Test Local Release Build

After running the setup script, test a local release build:

```bash
./scripts/build.sh android --release
```

The release APK should be signed with your keystore.

### 5. Test CI Build

Push to the main branch and check that the CI release build succeeds and uses proper signing.

## How It Works

### Local Builds

1. `android/key.properties` contains signing credentials (gitignored)
2. `android/app/build.gradle` reads key.properties if it exists
3. Release builds use the release signing config
4. If key.properties doesn't exist, falls back to debug signing

### CI Builds

1. Keystore is stored as base64 in GitHub Secrets
2. CI workflow decodes the keystore to `android/upload-keystore.jks`
3. CI workflow creates `android/key.properties` from secrets
4. Build uses the same keystore every time
5. Temporary files are not committed

## Verification

After setup, verify that release builds are properly signed:

```bash
# Build a release APK
./scripts/build.sh android --release

# Check the signature
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk

# The certificate fingerprint should match your keystore
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

Both commands should show the same certificate details.

## Upgrading Instead of Clean Install

With consistent signing:
- ✅ Upgrade preserves app data
- ✅ No need to uninstall between builds
- ✅ `deploy.py` upgrade works automatically

Without consistent signing (old behavior):
- ❌ Signature mismatch on every build
- ❌ Must uninstall (loses data) before installing
- ❌ `deploy.py` requires `--clean-install` flag

## Security Notes

**DO NOT:**
- ❌ Commit `android/upload-keystore.jks` to git
- ❌ Commit `android/key.properties` to git
- ❌ Commit `android/github-secrets.txt` to git
- ❌ Share keystore or passwords publicly
- ❌ Use the same keystore for multiple apps

**DO:**
- ✅ Keep keystore backed up securely (e.g., password manager, encrypted storage)
- ✅ Store passwords in GitHub Secrets
- ✅ Use different keystores for different apps
- ✅ Keep keystore for the lifetime of the app

**Important:** If you lose the keystore, you CANNOT update your app on Google Play Store. You'll have to publish as a new app with a different package name. Back it up safely!

## Rotating Keys

If you need to change the signing key:

1. Generate new keystore: `./scripts/setup-signing.sh`
2. Update GitHub Secrets with new values
3. **Important:** All users will need to uninstall and reinstall (signature change)
4. For Play Store apps, you'll need to contact Google Support

Avoid rotating keys unless absolutely necessary (security breach, lost keystore, etc.).

## Troubleshooting

### "Keystore was tampered with, or password was incorrect"

- Check that passwords in GitHub Secrets match the keystore
- Re-run `./scripts/setup-signing.sh` to regenerate

### "Signature does not match the previously installed version"

- Old situation (expected): Different keystores between builds
- After setup (shouldn't happen): Check that CI is using the secrets correctly

### Release build still uses debug signing

- Verify `android/key.properties` exists
- Check that `android/app/build.gradle` was updated correctly
- Look for errors in build logs

### CI build fails with signing error

- Verify all 4 secrets are added to GitHub
- Check that base64 encoding is correct (no line breaks)
- Look at CI logs for specific error messages

## References

- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Android: Sign your app](https://developer.android.com/studio/publish/app-signing)
- [GitHub Actions: Using secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)

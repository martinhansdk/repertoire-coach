# Deploy Script Documentation

## Overview

The `deploy.py` script automates deployment of Android and iOS builds to connected devices. It supports both local builds and GitHub Actions artifacts.

## Features

- Interactive build selection menu
- Download and deploy from GitHub Actions
- Deploy local builds
- Auto-select single builds or when run-id + build-type specified
- Force uninstall before install (for switching debug/release)
- Color-coded output with progress indicators
- Comprehensive error handling

## Requirements

### For Android Deployment
- `adb` (Android Debug Bridge)
  - Linux: `sudo apt-get install android-tools-adb`
  - macOS: `brew install android-platform-tools`
- Connected Android device with USB debugging enabled

### For iOS Deployment
- `ideviceinstaller` or `ios-deploy`
  - macOS: `brew install ideviceinstaller`
- Connected iOS device via USB
- Only supported on macOS

### For GitHub Actions Artifacts
- `gh` (GitHub CLI)
  - Linux: `sudo apt install gh`
  - macOS: `brew install gh`
- Authenticated: `gh auth login`

## Usage

### Interactive Mode

```bash
# Show all available builds (local + GitHub)
./scripts/deploy.py

# Show only local builds
./scripts/deploy.py --local

# Show only GitHub builds
./scripts/deploy.py --github

# Filter by platform
./scripts/deploy.py --platform ios
```

### Non-Interactive Mode

```bash
# Deploy specific GitHub run (auto-selects if unique)
./scripts/deploy.py --run-id 19629776037 --build-type debug

# Deploy specific GitHub run with force reinstall
./scripts/deploy.py --run-id 19629776037 --build-type release --force

# Deploy local build for iOS
./scripts/deploy.py --platform ios --local
```

## Options

- `--platform {android,ios}` - Platform to deploy (default: android)
- `--local` - Use local build
- `--github` - Use GitHub Actions artifact
- `--run-id RUN_ID` - Specific GitHub Actions run ID
- `--build-type {debug,release}` - Build type filter
- `--force` - Uninstall existing app before installing
- `--help` - Show help message

## Examples

### Deploy Latest GitHub Debug Build

```bash
./scripts/deploy.py --github --build-type debug
```

### Deploy Specific Run

```bash
# Find run ID first
gh run list --workflow="Build Flutter App"

# Deploy specific run
./scripts/deploy.py --run-id 19629776037 --build-type debug
```

### Switch from Debug to Release

```bash
# Force uninstall debug and install release
./scripts/deploy.py --run-id 19629776037 --build-type release --force
```

### Deploy Local Build

```bash
# Build first
scripts/build.sh android --debug

# Deploy
./scripts/deploy.py --local
```

## How It Works

### GitHub Artifact Download

1. Queries GitHub Actions for successful workflow runs
2. Lists artifacts for selected run
3. Downloads artifact (ZIP format)
4. Extracts APK/IPA from artifact
5. Deploys to connected device

### Build Detection

**Android Local Builds:**
- Searches `build/app/outputs/flutter-apk/` for APK files
- Detects debug/release from filename

**iOS Local Builds:**
- Searches `build/ios/ipa/` for IPA files

**GitHub Builds:**
- Lists recent successful workflow runs
- Filters by artifact name (android-debug-apk, android-release-apk, etc.)

### Auto-Selection

The script auto-selects a build without showing menu when:
- Only one build is available
- Both `--run-id` and `--build-type` are specified

Otherwise, shows interactive menu.

## Troubleshooting

### No Devices Connected

**Android:**
```bash
# Check devices
adb devices

# If empty, check:
# - USB debugging enabled on device
# - Device authorized (check device screen)
# - USB cable is data cable (not charge-only)

# Restart adb server
adb kill-server && adb start-server
```

**iOS:**
```bash
# Check devices
ideviceinstaller --list-apps

# If fails:
# - Device must be unlocked
# - Trust this computer on device
# - Check USB connection
```

### Installation Failed: Signature Mismatch

This occurs when trying to install a release build over a debug build (or vice versa).

**Solution:**
```bash
# Use --force to uninstall first
./scripts/deploy.py --run-id 19629776037 --build-type release --force
```

### GitHub Artifact Not Found

**Check:**
1. Run ID is correct: `gh run list --workflow="Build Flutter App"`
2. Run completed successfully
3. Artifacts haven't expired (90 days default)
4. You're authenticated: `gh auth status`

### Build Not Found

**For local builds:**
```bash
# Build first
scripts/build.sh android --debug
```

**For GitHub builds:**
- Check workflow completed successfully
- Wait for workflow to finish if still running

## Testing

The script was successfully tested with:
- Run ID: 19629776037
- Build types: debug and release
- Connected device: RF8M60TZSLR (Android)

### Verification Commands

```bash
# Check if app is installed
adb shell pm list packages | grep repertoire

# Get app info
adb shell dumpsys package com.repertoirecoach.repertoire_coach | grep versionName

# Uninstall manually if needed
adb uninstall com.repertoirecoach.repertoire_coach
```

## Exit Codes

- `0` - Success
- `1` - Error (deployment failed, no builds found, etc.)

## Notes

- Temporary files are automatically cleaned up after deployment
- GitHub artifact downloads are streamed (not kept after deployment)
- The script detects color support automatically
- Progress feedback during download/install operations
- Comprehensive error messages with suggestions

## Package Name

The app package name is: `com.repertoirecoach.repertoire_coach`

This is used for:
- Installation checks
- Uninstall operations
- Verification

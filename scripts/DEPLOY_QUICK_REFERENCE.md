# Deploy Script Quick Reference

## Most Common Commands

### Deploy Latest Debug Build from GitHub
```bash
./scripts/deploy.py --github --build-type debug
```

### Deploy Specific GitHub Build (Non-Interactive)
```bash
# Find run ID first
gh run list --workflow="Build Flutter App" | head -5

# Deploy
./scripts/deploy.py --run-id <RUN_ID> --build-type debug
```

### Deploy and Replace Existing App
```bash
# Use --force to uninstall first (useful when switching debug ↔ release)
./scripts/deploy.py --run-id <RUN_ID> --build-type release --force
```

### Deploy Local Build
```bash
# Build first
./scripts/build.sh android --debug

# Deploy
./scripts/deploy.py --local
```

### Interactive Menu (All Options)
```bash
./scripts/deploy.py
```

## Quick Checks

### Validate Script
```bash
./scripts/validate_deploy.sh
```

### Check Connected Devices
```bash
adb devices
```

### Check if App is Installed
```bash
adb shell pm list packages | grep repertoire
```

### Uninstall Manually
```bash
adb uninstall com.repertoirecoach.repertoire_coach
```

## Command-Line Flags

| Flag | Values | Description |
|------|--------|-------------|
| `--platform` | android, ios | Target platform (default: android) |
| `--local` | - | Use local build |
| `--github` | - | Use GitHub build |
| `--run-id` | NUMBER | Specific GitHub run ID |
| `--build-type` | debug, release | Build type filter |
| `--force` | - | Uninstall before install |

## Troubleshooting

### No Devices Found
```bash
# Android
adb kill-server && adb start-server
adb devices

# Check USB debugging is enabled on device
# Check device is authorized (check device screen)
```

### Signature Mismatch Error
```bash
# Use --force flag
./scripts/deploy.py --run-id <RUN_ID> --build-type release --force
```

### GitHub Authentication
```bash
gh auth login
gh auth status
```

## Examples with Real Run ID

These examples use the verified run ID from testing:

```bash
# Debug build
./scripts/deploy.py --run-id 19629776037 --build-type debug

# Release build (force reinstall)
./scripts/deploy.py --run-id 19629776037 --build-type release --force
```

## Full Documentation

See [`DEPLOY_README.md`](./DEPLOY_README.md) for complete documentation.

## Package Name

`com.repertoirecoach.repertoire_coach`

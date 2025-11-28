# Gradle Cache Fix for CI

## Issue
Gradle caching in GitHub Actions CI doesn't work - cache misses on every run and fails to save cache after builds.

Reference: [Issue #18](https://github.com/martinhansdk/repertoire-coach/issues/18)

## Root Cause
The Android build jobs run Flutter/Gradle inside Docker containers with volume mounts. Files created inside the Docker container may have permission issues that prevent the GitHub Actions cache action from reading and saving them properly.

## Solution

### Required Changes to `.github/workflows/build.yml`

#### 1. Update Cache Configuration

**For `build-android-debug` job (lines 74-82):**
```yaml
    - name: Cache Gradle packages
      uses: actions/cache@v4
      with:
        path: |
          ~/.gradle/caches
          ~/.gradle/wrapper
          android/.gradle
        key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
        restore-keys: |
          ${{ runner.os }}-gradle-
        save-always: true
```

**For `build-android-release` job (lines 134-142):**
```yaml
    - name: Cache Gradle packages
      uses: actions/cache@v4
      with:
        path: |
          ~/.gradle/caches
          ~/.gradle/wrapper
          android/.gradle
        key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
        restore-keys: |
          ${{ runner.os }}-gradle-
        save-always: true
```

**Changes made:**
- Added `android/.gradle` to cache paths (project-specific Gradle cache)
- Added `save-always: true` to ensure cache saves even on build failures

#### 2. Add Permission Fix Steps

**For `build-android-debug` job, add after line 105:**
```yaml
    - name: Fix Gradle cache permissions
      if: always()
      run: |
        sudo chown -R $(whoami):$(id -gn) $HOME/.gradle 2>/dev/null || true
        echo "Gradle cache directory contents:"
        ls -la $HOME/.gradle/ 2>/dev/null || echo "No Gradle directory found"
```

**For `build-android-release` job, add after line 178:**
```yaml
    - name: Fix Gradle cache permissions
      if: always()
      run: |
        sudo chown -R $(whoami):$(id -gn) $HOME/.gradle 2>/dev/null || true
        echo "Gradle cache directory contents:"
        ls -la $HOME/.gradle/ 2>/dev/null || echo "No Gradle directory found"
```

**Purpose:**
- Ensures the GitHub Actions runner has read permissions on all cached files
- Allows the cache action to successfully save the Gradle cache
- Runs with `if: always()` to execute even if the build fails

## Why This Works

1. **`save-always: true`**: Forces cache to save even if there are warnings or failures
2. **Permission fix**: Ensures all files created by Docker are readable by the cache action
3. **Additional cache path**: Includes project-specific Gradle cache that may be missed by global cache
4. **Diagnostic output**: Helps verify cache contents for debugging

## Testing

After applying these changes:

1. First workflow run:
   - Cache should be created and saved
   - "Cache Gradle packages" step should show "Cache not found" (expected)

2. Second workflow run:
   - Cache should be restored successfully
   - Build should be noticeably faster
   - "Cache Gradle packages" step should show "Cache restored from key: linux-gradle-xxx"

## Alternative Minimal Fix

If you prefer the simplest possible fix, just add this single step after each Android build:

```yaml
    - name: Ensure cache can be saved
      if: always()
      run: sudo chown -R $USER $HOME/.gradle || true
```

This addresses the core permission issue without other enhancements.

## Related Files
- `.github/workflows/build.yml` - Main workflow file that needs changes
- `android/build.gradle` - Part of Gradle cache key
- `android/gradle/wrapper/gradle-wrapper.properties` - Part of Gradle cache key

## References
- [GitHub Actions Cache Documentation](https://github.com/actions/cache)
- [Issue #18: Gradle caching does not work on CI](https://github.com/martinhansdk/repertoire-coach/issues/18)
- Referenced failing run: https://github.com/martinhansdk/repertoire-coach/actions/runs/19759520524/job/56617992948

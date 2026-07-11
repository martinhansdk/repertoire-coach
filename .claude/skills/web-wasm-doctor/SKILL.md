---
name: web-wasm-doctor
description: >
  Diagnose and fix Flutter web runtime problems in this repo: Drift/sqlite3
  WASM version mismatches and corrupted dev-server state. Use when the web
  app shows a blank page, when the browser console shows "LinkError: Import
  ... 'dispatch_xFunc': function import requires a callable" or "LinkError:
  Import object field 'dispatch_xFunc' is not a Function", when the page is
  stuck after "Using WasmStorageImplementation", when the dev server stops
  responding after repeated reloads (common under Playwright), or after any
  upgrade of the drift or sqlite3 packages in pubspec.yaml.
---

# Flutter Web WASM Doctor

The web platform loads two vendored runtime artifacts from `web/`:
`drift_worker.dart.js` and `sqlite3.wasm`. They MUST exactly match the
`drift:` and `sqlite3:` package versions in `pubspec.yaml`. Mismatches fail
at runtime only, with the LinkErrors quoted above or a blank page.

## Decision tree

1. **LinkError mentioning `dispatch_xFunc` (either variant), or blank page
   after "Using WasmStorageImplementation"** → WASM version mismatch.
   Run: `bash .claude/skills/web-wasm-doctor/scripts/check_wasm.sh`
   - It compares pubspec versions against the recorded versions of the
     deployed files and prints exact download URLs.
   - `--fix` downloads the matching artifacts and records their versions.
   - After replacing WASM files: restart with cache clear (step 3).

2. **Just upgraded `drift:` or `sqlite3:` in pubspec.yaml** → same as (1);
   run `check_wasm.sh --fix` proactively before testing.

3. **Blank page / unresponsive server after many reloads or Playwright
   runs** (no LinkError) → corrupted hot-reload state. Run:
   `bash .claude/skills/web-wasm-doctor/scripts/restart_web.sh --clear-cache`
   Then wait for "lib/main.dart is being served" in the output before
   loading http://localhost:8080 in a FRESH browser tab.

## Prevention

- Prefer pressing `r` (hot reload) in the server console over browser
  refresh.
- The version stamp lives in `web/.wasm-versions`; `check_wasm.sh` maintains
  it. If the stamp is missing (e.g. files predate this skill), the script
  cannot verify the deployed files — treat any mismatch symptom as real and
  re-download with `--fix`.
- Never serve Flutter web with a plain HTTP server; only
  `scripts/run-web.sh`.

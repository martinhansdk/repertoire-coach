# CLAUDE.md — Repertoire Coach

Choir practice app: Flutter (Android primary, iOS, web) + Riverpod + Drift
(local, offline-first) + Supabase (remote). Clean architecture:
presentation → domain → data.

Deep documentation (read on demand, don't guess):

| Topic | Document |
|---|---|
| Requirements & user workflows | REQUIREMENTS.md |
| Architecture, DB schema, tech stack | ARCHITECTURE.md |
| **Sync design & invariants** | docs/SYNC_ARCHITECTURE.md |
| Testing standards | TESTING_GUIDELINES.md |
| Docker & deployment | DOCKER.md |
| On-device debugging (logcat, background audio) | `.claude/skills/device-debugging/` |
| Task list | TODO.md |

## CRITICAL: Flutter runs in Docker only

Flutter is NOT installed on the host. Never run `flutter ...` directly.

Preferred: the Flutter MCP server (structured JSON output, cached results):

| Task | Tool |
|---|---|
| Validation (analyze + test) | `mcp__flutter__run_validation` |
| Tests / analysis | `mcp__flutter__flutter_test` / `flutter_analyze` |
| Query cached failures | `mcp__flutter__get_test_results` (failedOnly: true), `get_analyze_results` |
| Build / pub | `mcp__flutter__flutter_build` / `flutter_pub` |
| Debug parser issues | `mcp__flutter__get_raw_log` |

Fallback scripts (also used by CI): `scripts/validate.sh`, `test.sh`,
`analyze.sh`, `build.sh`, `mocks.sh` (regenerates mockito mocks). Don't
hand-roll `docker run` commands when these exist. The MCP server itself lives
in `flutter-mcp-server/` — fix its parsers when a tool misbehaves
(`get_raw_log` shows the unparsed output).

## Validate before every commit (mandatory)

1. `mcp__flutter__run_validation`
2. Pass → commit and push. Fail → query details
   (`get_test_results failedOnly: true`, `get_analyze_results severity: error`),
   fix, revalidate. Never commit red.
3. **Then watch CI to completion** (`gh run watch <id> --exit-status`) and fix
   any failures before moving on to the next task. Local validation does not
   cover everything CI does — iOS/Android/web builds and the Sync integration
   workflow (real Supabase stack) run only there.

## Sync code: read the invariants first

Before touching anything under `lib/core/sync/`, `lib/core/services/sync_service.dart`,
the remote data sources, or synced-table migrations, read
**docs/SYNC_ARCHITECTURE.md** — its Invariants section is load-bearing.
Non-negotiables:

- Repositories NEVER write to Supabase. Local-only writes, marked unsynced;
  the sync layer owns all remote I/O. Do not reintroduce inline pushes.
- Deletion is a tombstone (`deleted = true`), never inferred from absence.
- `updated_at` is client-set edit time (UTC). No server triggers, no
  push-time stamping. Local soft-deletes stamp their deletion time.
- markSynced is conditional on the snapshotted timestamp; upserts never
  overwrite newer unsynced local rows.
- Remote sync queries must page (`fetchAllRows`) with a total ordering and
  chunk `IN` lists (`fetchAllRowsChunkedIn`) — see
  `lib/data/datasources/remote/postgrest_pagination.dart`.
- New sync bug? Add the invariant to docs/SYNC_ARCHITECTURE.md and a
  `REGRESSION:` test BEFORE fixing.

For the full working procedure — bug-fix protocol, schema-change checklist,
running all three test suites, seed reproduction — use the **sync-change**
skill (`.claude/skills/sync-change/`).

## Web development server

`scripts/run-web.sh` → http://localhost:8080 (loads `.env` credentials,
hot reload, logs to `logs/`). Never serve Flutter web with a plain HTTP
server. Prefer pressing `r` in the server console over browser refresh.

For blank pages, `LinkError: ... dispatch_xFunc` messages, dev-server
corruption after reloads, or after upgrading `drift:`/`sqlite3:` → use the
**web-wasm-doctor** skill (`.claude/skills/web-wasm-doctor/`); its
`check_wasm.sh --fix` and `restart_web.sh --clear-cache` scripts handle
diagnosis and repair.

## Other MCP servers

**Supabase** (`mcp__supabase__*`): list_tables, list_migrations,
execute_sql, get_logs, get_advisors, search_docs, and more.
**It is READ-ONLY** — `apply_migration`/`execute_sql` writes fail. Write
migrations as `.sql` files in `supabase/migrations/` and note in the commit
message that they must be run manually in the Supabase dashboard. Run
`get_advisors (type: "security")` after schema changes.

**Playwright** (`mcp__playwright__*`): browser automation; test credentials
in `email-credentials.txt`. Flutter renders to canvas, so DOM selectors
mostly don't work — use `browser_snapshot` where semantics are exposed,
coordinates otherwise; prefer Flutter integration tests for UI coverage and
Playwright only for auth flows and navigation checks.

## Debugging discipline

- Recognize when code reading is not enough: if you can't confirm which
  branch executes, keep re-reading the same files, or can't verify a
  hypothesis — stop and gather runtime evidence (`adb logcat -s flutter` on a
  real device captures every debugPrint/ErrorReporter call).
- **Write the failing test before fixing the bug.** Reproduce → confirm it
  fails → fix → confirm it passes. Commit test + fix together.

## Git

- Auto-commit routine changes without being asked: docs, config, completed
  discrete features, behavior-preserving refactors.
- Conventional commits, atomic, reference issues when applicable. Include
  `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Keep docs in sync with code: update TODO.md when completing tasks,
  ARCHITECTURE.md for architectural decisions, REQUIREMENTS.md when user
  workflows change.

## Deployment

`./scripts/deploy.py` — interactive menu, or `--run-id <id>` for GitHub
Actions builds, `--local --build-type debug` for local. Needs `adb`
(Android), `ideviceinstaller`/`ios-deploy` (iOS), `gh` (Actions downloads).
Details in DOCKER.md.

## Conventions

- Files: `feature_name.dart`, `..._provider.dart`, `..._model.dart`,
  `..._test.dart`.
- DB: plural snake_case tables (`choir_members`), snake_case columns,
  FKs as `table_id`.
- Tests are not optional; standards and coverage targets live in
  TESTING_GUIDELINES.md.

## Project facts worth knowing

- Choirs own shared content (concerts → songs → tracks + audio); any member
  edits content, only the owner manages membership.
- Marker sets belong to tracks and can be shared with the choir or private
  (`is_shared`); markers live inside `marker_sets.markers_json` — the set is
  the unit of sync and conflict.
- Concerts are date-sorted (upcoming first); no manual ordering.
- Out of scope by decision: practice statistics, pitch adjustment.

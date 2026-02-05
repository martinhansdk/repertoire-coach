# Working with Claude on Repertoire Coach

This document provides context and guidelines for working with Claude Code (or any AI assistant) on this project.

## ⚠️ CRITICAL: Flutter Must Run in Docker

**NEVER run Flutter commands directly on the host machine. Flutter is NOT installed on the host.**

All Flutter commands MUST be executed inside Docker containers. Use the **Flutter MCP Server** (preferred) or the provided scripts.

### Primary Method: Flutter MCP Server (Preferred)

This project includes a custom Flutter MCP server maintained in `flutter-mcp-server/`. Claude should use these MCP tools for all Flutter operations:

```
# Validation (analyze + test)
mcp__flutter__run_validation

# Individual operations
mcp__flutter__flutter_analyze      # Run static analysis
mcp__flutter__flutter_test         # Run tests
mcp__flutter__flutter_build        # Build for platforms

# Query cached results
mcp__flutter__get_test_results     # Get test failures/details
mcp__flutter__get_analyze_results  # Get analysis issues

# Other operations
mcp__flutter__flutter_pub          # Run pub commands (get, upgrade, outdated)
mcp__flutter__get_raw_log          # Debug parser issues
```

**Why MCP over scripts:**
- Structured output (JSON) that's easier for Claude to parse
- Cached results for quick re-queries without re-running
- Better error filtering and deduplication
- No shell output parsing needed

### Alternative: Shell Scripts

Scripts exist in `scripts/` and should be maintained for CI and manual use:

```bash
scripts/validate.sh    # Runs analyze + test in Docker
scripts/test.sh        # Runs tests in Docker
scripts/analyze.sh     # Runs analyze in Docker
scripts/build.sh       # Builds app in Docker
scripts/mocks.sh       # Generates mockito mocks (build_runner)
```

### Never Do This

```bash
# WRONG - This will fail (Flutter not installed on host):
flutter pub get
flutter test
flutter analyze
flutter build

# ALSO WRONG - Don't use raw docker commands when MCP/scripts exist:
docker run --rm -v $(pwd):/workspace ... flutter test
```

**Running the Web Server (for development/testing):**
```bash
# Run Flutter web development server with hot reload
scripts/run-web.sh

# The server will be available at: http://localhost:8080
# Press Ctrl+C to stop the server
```

The `run-web.sh` script:
- Automatically loads Supabase credentials from `.env`
- Runs `flutter pub get` to ensure dependencies are up to date
- Starts the Flutter development server with hot reload support
- Logs output to `logs/web-run-{timestamp}.log`

**IMPORTANT:** Do NOT use simple HTTP servers (like `python3 -m http.server`) to serve Flutter web builds. Flutter's development server provides:
- Hot reload for faster development
- Proper MIME types and headers
- Source maps for debugging
- WebSocket support for development tools

**CRITICAL: Drift WASM Version Matching**

The web platform uses WebAssembly files that **MUST** match the exact package versions in `pubspec.yaml`:

```bash
# ALWAYS check pubspec.yaml versions first:
grep "drift:" pubspec.yaml     # Example: drift: ^2.29.0
grep "sqlite3:" pubspec.yaml   # Example: sqlite3: ^2.9.4
```

Then download matching WASM files to `web/` directory:

| Package | Version | WASM File | Download From |
|---------|---------|-----------|---------------|
| `drift: ^2.29.0` | 2.29.0 | `drift_worker.dart.js` | [drift v2.29.0 release](https://github.com/simolus3/drift/releases/tag/drift-2.29.0) |
| `sqlite3: ^2.9.4` | 2.9.4 | `sqlite3.wasm` | [sqlite3.dart v2.9.4 release](https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-2.9.4) |

**Common Errors from Version Mismatches:**
- `LinkError: Import #18 'dart' 'dispatch_xFunc': function import requires a callable` → drift_worker.dart.js version mismatch
- `LinkError: Import object field 'dispatch_xFunc' is not a Function` → sqlite3.wasm version mismatch
- Blank page with "Using WasmStorageImplementation" but no UI → WASM files not loading or version mismatch

**After changing WASM files:**
```bash
# 1. Stop the dev server (Ctrl+C or docker kill)
# 2. Clear build cache if issues persist
rm -rf .dart_tool/build
# 3. Restart dev server
scripts/run-web.sh
```

This applies to:
- Claude Code (you)
- All specialized agents (flutter-master-coder, flutter-test-architect, etc.)
- Any script or automation

If you need to run Flutter commands, either:
1. Use the provided scripts (`scripts/validate.sh`, `scripts/test.sh`, etc.)
2. Run the command in a Docker container explicitly
3. Ask the user to run the command if you're unsure

## Troubleshooting Flutter Web Development Server

### Blank Page / App Won't Load in Browser

**Symptoms:**
- Browser shows Flutter loading animation, then goes blank
- Page stays white/blank even after waiting
- Works in Playwright initially but fails after multiple reloads

**Cause:**
Flutter's development server hot reload state can become corrupted after multiple page reloads, navigations, or browser refreshes. This is especially common when testing with automation tools like Playwright.

**Solution:**
Fully restart the Docker container running the web server:

```bash
# 1. Find and kill the container
docker ps --filter "publish=8080" --format "{{.ID}}" | xargs docker kill

# 2. Restart the web server
./scripts/run-web.sh

# 3. Wait for server to be fully ready (shows "lib/main.dart is being served")
# Then load http://localhost:8080 in a fresh browser tab
```

**Why this works:**
- Hot reload can accumulate state corruption over time
- Full container restart clears all cached state
- Gives you a completely fresh development server instance

**Prevention:**
- Avoid excessive page reloads during development
- Use hot reload (press 'r' in the server console) instead of browser refresh when possible
- Restart the server if you notice any strange behavior

## Project Context Summary

### What This App Does
A collaborative mobile/desktop app for choir members to practice their vocal parts. Users organize into choirs, share concerts and songs with multiple voice tracks, and maintain personal practice metadata (section markers, playback positions).

### Key Architectural Decisions

**Why Choir-Based Architecture?**
- Initially designed as single-user, evolved to multi-user collaborative model
- Choirs are user groups with an owner who manages membership
- Content (concerts, songs, audio) is shared among choir members
- Personal metadata (sections, playback positions) stays private per-user

**Why Supabase + PostgreSQL instead of Firebase?**
- **Cost concerns**: More predictable pricing, lower at scale
- **Vendor lock-in concerns**: Open source, can self-host
- **Relational model**: Foreign keys, complex queries, data integrity
- **Row Level Security**: Database-level access control perfect for choir permissions

**Why Riverpod for state management?**
- Compile-time safety (fewer runtime crashes)
- Great for async data (Supabase queries)
- Easy testing
- Modern Flutter best practices

**Why Flutter?**
- Cross-platform: Android (primary), iOS, Web
- Android Auto support via native integration
- Good audio support (just_audio package)

### Important Requirements

**Concert Organization:**
- Concerts have dates and are automatically sorted (upcoming first, then past)
- No custom manual ordering - date-based only
- Users see all concerts from all their choirs

**Audio & Sharing:**
- Audio files are shared among choir members (uploaded once, accessible to all)
- Any choir member can add/edit concerts and songs
- Only choir owner can manage membership

**Personal Data:**
- Section markers are private per-user but follow the song everywhere
- Playback positions are saved per user per song
- Last accessed concert is tracked per user

**Removed Features:**
- Practice session tracking/statistics - won't be implemented
- Adjustable playback speed - won't be implemented
- Pitch adjustment - won't be implemented

## Project Structure

```
repertoire-coach/
├── REQUIREMENTS.md      # Detailed feature requirements and workflows
├── ARCHITECTURE.md      # Technical design, database schema, data models
├── TODO.md             # Development tasks organized by phase
├── DOCKER.md           # Docker setup for builds and Supabase
├── README.md           # Project overview
├── flutter-mcp-server/ # Custom MCP server for Flutter operations (maintained by Claude)
├── scripts/            # Shell scripts for CI and manual use
├── Dockerfile.build    # Flutter build container
├── docker-compose.supabase.yml  # Self-hosted Supabase stack
└── lib/                # Flutter source
```

## Flutter MCP Server

The project includes a custom MCP (Model Context Protocol) server in `flutter-mcp-server/` that Claude maintains. This server provides structured Flutter tooling that's easier to work with than parsing shell output.

### Server Location
```
flutter-mcp-server/
├── src/
│   ├── server.py         # Main MCP server
│   ├── cache.py          # Result caching
│   └── parsers/          # Output parsers
│       ├── test_parser.py
│       └── analyze_parser.py
├── README.md             # Server documentation
└── pyproject.toml        # Python dependencies
```

### When to Update the MCP Server

Claude should fix or improve the MCP server when:
- A tool returns unexpected results or fails to parse output correctly
- A useful operation isn't available as an MCP tool
- The caching behavior needs adjustment
- New Flutter features require new tooling

### Available Tools

| Tool | Purpose |
|------|---------|
| `flutter_test` | Run tests with structured output |
| `flutter_analyze` | Run analysis with structured issues |
| `flutter_build` | Build for platforms |
| `flutter_pub` | Run pub commands |
| `run_validation` | Combined analyze + test |
| `get_test_results` | Query cached test results |
| `get_analyze_results` | Query cached analysis results |
| `list_test_runs` | List recent test runs |
| `get_raw_log` | Debug parser issues |

### Debugging MCP Issues

If an MCP tool behaves unexpectedly:
1. Use `get_raw_log` to see the actual Flutter output
2. Check the parser in `flutter-mcp-server/src/parsers/`
3. Fix the parser and test with the raw output

## Playwright MCP Server

The Playwright MCP server is installed for browser automation and web testing. Test account credentials are stored in `email-credentials.txt`.

### Available Tools

| Tool | Purpose |
|------|---------|
| `mcp__playwright__browser_navigate` | Navigate to URL |
| `mcp__playwright__browser_snapshot` | Get accessibility snapshot (preferred over screenshot) |
| `mcp__playwright__browser_click` | Click elements |
| `mcp__playwright__browser_type` | Type into fields |
| `mcp__playwright__browser_take_screenshot` | Capture screenshots |

### Limitations with Flutter Web

**Important:** Flutter renders to a canvas element, not traditional DOM elements. This makes Playwright harder to use because:
- Most elements aren't accessible as individual DOM nodes
- `browser_snapshot` returns limited accessibility info
- Click coordinates may be needed instead of element selectors
- Text input may require focusing the canvas first

For Flutter web testing, consider:
1. Using Flutter's integration_test package instead
2. Using Playwright only for auth flows and navigation verification
3. Relying on accessibility semantics where Flutter exposes them

## Supabase MCP Server

The Supabase MCP server provides direct access to inspect and manage the Supabase backend.

### Available Tools

| Tool | Purpose |
|------|---------|
| `mcp__supabase__list_tables` | List all tables in schemas |
| `mcp__supabase__list_migrations` | List applied migrations |
| `mcp__supabase__apply_migration` | Apply new DDL migrations |
| `mcp__supabase__execute_sql` | Run SQL queries (read/write) |
| `mcp__supabase__get_logs` | Get service logs (api, auth, postgres, etc.) |
| `mcp__supabase__get_advisors` | Check security/performance advisories |
| `mcp__supabase__search_docs` | Search Supabase documentation |
| `mcp__supabase__generate_typescript_types` | Generate types from schema |
| `mcp__supabase__list_edge_functions` | List Edge Functions |
| `mcp__supabase__get_project_url` | Get API URL |
| `mcp__supabase__get_publishable_keys` | Get API keys |

### Common Uses

```
# Inspect current schema
mcp__supabase__list_tables (schemas: ["public"])

# Check RLS policies are working
mcp__supabase__get_advisors (type: "security")

# Debug auth issues
mcp__supabase__get_logs (service: "auth")

# Run a query
mcp__supabase__execute_sql (query: "SELECT * FROM choirs LIMIT 5")

# Apply schema changes
mcp__supabase__apply_migration (name: "add_new_column", query: "ALTER TABLE...")
```

### Important Notes

- **The Supabase MCP is read-only.** `apply_migration` and `execute_sql` will fail with
  "read-only mode".  Write migrations as `.sql` files in `supabase/migrations/` and note
  in the commit message that they must be run manually in the Supabase dashboard.
- `get_advisors` is useful after schema changes to catch missing RLS policies
- The database schema is documented in ARCHITECTURE.md

## Working with Claude on This Project

### Starting a New Session

When starting a new session with Claude, provide context:

```
I'm working on the choir practice app. Please read REQUIREMENTS.md
and ARCHITECTURE.md to understand the project context.
```

Or reference specific sections:
```
Looking at the database schema in ARCHITECTURE.md, I need help
implementing the RLS policies for concerts.
```

### Useful Prompts for This Project

**Architecture Questions:**
```
Why did we choose [technology/pattern] over [alternative]?
How does [feature] work in our architecture?
What's the data flow for [user workflow]?
```

**Implementation Help:**
```
Implement the [usecase] following the clean architecture in ARCHITECTURE.md
Create the Riverpod provider for [feature]
Write the RLS policy for [table] according to our security requirements
```

**Database Work:**
```
Generate the SQL migration for [feature] following our schema in ARCHITECTURE.md
Create the Supabase query for [workflow] from REQUIREMENTS.md
```

**Debugging:**
```
I'm getting [error] when [doing X]. Our architecture uses [pattern],
what could be wrong?
```

### What Claude Knows About This Project

Claude has full context of:
- ✅ All requirements and user workflows (REQUIREMENTS.md)
- ✅ Complete technical architecture (ARCHITECTURE.md)
- ✅ Database schema and RLS policies
- ✅ Development phases and tasks (TODO.md)
- ✅ Docker setup for builds and deployment
- ✅ Technology choices and reasoning
- ✅ Data models and relationships
- ✅ Security requirements

### Key Things to Remember When Asking Claude

1. **Reference the docs**: Claude can read all markdown files, so reference them
   - "According to ARCHITECTURE.md, we use..."
   - "REQUIREMENTS.md says users should be able to..."

2. **Be specific about context**:
   - Bad: "How do I query songs?"
   - Good: "How do I query songs for a specific concert using our PostgreSQL schema?"

3. **Mention constraints**:
   - "Following our clean architecture pattern..."
   - "Using Riverpod for state management..."
   - "Respecting the RLS policies defined in ARCHITECTURE.md..."

4. **Ask about decisions**:
   - "Why did we choose X over Y?" (if reasoning isn't clear)
   - Claude can explain the trade-offs

5. **Request updates to docs**:
   - "Update TODO.md to mark [task] as complete"
   - "Add this decision to ARCHITECTURE.md"

## Development Workflow with Claude

### Phase 1: Planning
```
I want to implement [feature]. Can you:
1. Break it down into subtasks
2. Update TODO.md with these tasks
3. Identify which files need to be created/modified
```

### Phase 2: Implementation
```
Implement [specific task] from TODO.md following our architecture.
Make sure to:
- Follow the data models in ARCHITECTURE.md
- Use Riverpod providers
- Handle errors appropriately
- **ALWAYS write comprehensive tests** (unit, widget, and/or integration tests)
```

**IMPORTANT: Testing is Mandatory**
- Every feature implementation MUST include tests
- Write tests for all new code (domain entities, repositories, providers, widgets)
- Tests should cover happy paths, edge cases, and error scenarios
- Aim for high test coverage to ensure code quality and prevent regressions

### Phase 3: Review
```
Review this implementation of [feature] against REQUIREMENTS.md.
Does it meet all the requirements? Any security concerns with RLS?
```

### Phase 4: Documentation
```
I've implemented [feature]. Update:
- TODO.md to mark tasks complete
- Add any new architecture decisions to ARCHITECTURE.md if needed
```

## Common Patterns in This Project

### Clean Architecture Layers
```
Presentation (UI) → Domain (Use Cases) → Data (Repositories/Data Sources)
```

Ask Claude to follow this when implementing features.

### Riverpod Provider Pattern
```dart
// Read-only data
final concertsProvider = FutureProvider<List<Concert>>(...);

// Mutable state
final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(...);
```

### Supabase Query Pattern
```dart
final response = await supabase
  .from('table')
  .select('*, related_table!inner(*)')
  .eq('field', value);
```

### RLS Policy Pattern
All tables use Row Level Security. Users can only access:
- Their own private data (sections, playback_states)
- Data from choirs they're members of (choirs, concerts, songs)

## Testing with Claude

**⚠️ Tests Are NOT Optional**
Every implementation MUST include tests. Do not consider a feature "complete" without comprehensive test coverage.

**For complete testing standards and guidelines, see [TESTING_GUIDELINES.md](TESTING_GUIDELINES.md).**

**Test Types to Include:**

**Unit Tests:**
```
Write unit tests for [use case] following Flutter testing best practices.
Include edge cases from REQUIREMENTS.md.
Test all domain entities, use cases, and repository implementations.
```

**Widget Tests:**
```
Write widget tests for all UI components.
Test user interactions, state changes, and rendering.
Verify proper display of data in different states (loading, error, success, empty).
```

**Integration Tests:**
```
Write integration tests for [user workflow] from REQUIREMENTS.md.
Test the complete flow from UI to Supabase.
```

**RLS Testing:**
```
Write tests to verify RLS policies for [table].
Ensure users can't access data outside their choirs.
```

**Test Coverage Goals:**
- Domain layer: 100% (entities, use cases)
- Data layer: 90%+ (repositories, models)
- Presentation layer: 80%+ (widgets, providers)

## Pre-Commit Validation (MANDATORY)

**⚠️ CRITICAL: Always validate before committing**

Before any commit, Claude MUST run validation to verify the code is correct.

### Quick Validation with MCP (Recommended)

Use the Flutter MCP server for validation:
```
mcp__flutter__run_validation
```

This returns structured JSON with:
- `success`: Overall pass/fail
- `analyze.summary`: Error/warning/info counts
- `test.summary`: Passed/failed/skipped counts

**If validation fails**, query details:
```
# Get test failures
mcp__flutter__get_test_results  (with failedOnly: true)

# Get analysis issues
mcp__flutter__get_analyze_results  (filter by severity, file, etc.)
```

### Alternative: Shell Scripts

For CI or manual validation, scripts are available:
```bash
scripts/validate.sh    # Runs analyze + test
scripts/analyze.sh     # Analyze only
scripts/test.sh        # Tests only (--verbose for details)
```

Scripts write detailed logs to `logs/` directory.

### Validation Workflow

1. **Run validation:**
   ```
   mcp__flutter__run_validation
   ```

2. **If validation passes, commit:**
   ```bash
   git add <files>
   git commit -m "message"
   git push
   ```

3. **If validation fails, query details:**
   ```
   mcp__flutter__get_test_results (failedOnly: true)
   mcp__flutter__get_analyze_results (severity: "error")
   ```

**Why This Matters:**
- CI runs these same checks - catching issues locally saves time
- Multiple fix commits clutter the history
- Shows proper software engineering discipline
- Prevents breaking the build for other developers
- MCP structured output is easier to parse than script logs

**Examples of Issues This Catches:**
- Type errors (e.g., passing String to bool parameter)
- Unused imports
- Missing const keywords
- Compilation errors
- Broken tests from code changes

## Troubleshooting with Claude

**When stuck:**
```
I'm trying to [do X] but getting [error Y].
Our setup uses [tech stack from ARCHITECTURE.md].
What could be wrong?
```

**Architecture questions:**
```
How should [feature] fit into our clean architecture?
Which layer should handle [responsibility]?
```

**Database questions:**
```
What's the correct SQL query to [do X] given our schema in ARCHITECTURE.md?
Do I need a new index for this query?
```

## Updating Documentation

Always ask Claude to update docs when:
- Completing tasks: `Update TODO.md to mark [tasks] as complete`
- Making architectural decisions: `Document this decision in ARCHITECTURE.md`
- Adding features: `Update REQUIREMENTS.md if this changes user workflows`
- Changing tech: `Update ARCHITECTURE.md with the new approach`

## Git Workflow with Claude

### When Claude Should Auto-Commit

Claude should **automatically commit** after completing these types of changes (without being asked):
- Documentation updates (README, REQUIREMENTS, ARCHITECTURE, TODO, etc.)
- Project naming changes
- Configuration file changes
- Completing discrete features or tasks
- Refactoring that doesn't change functionality

The user shouldn't need to ask for commits on routine changes - just do it!

### Creating Commits

Claude can help with commits:
```
Create a commit for the changes we just made to [feature].
Use conventional commit format.
```

Claude includes co-author attribution by default:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Deployment

### Deploying to Physical Devices

The project includes a comprehensive deployment script (`scripts/deploy.py`) that can:
- Deploy Android/iOS builds from GitHub Actions or local builds
- Provide interactive menu or accept CLI arguments
- Auto-detect connected devices
- Download and install builds automatically

**Usage:**
```bash
# Interactive menu (auto-detects builds)
./scripts/deploy.py

# Deploy specific GitHub Actions run
./scripts/deploy.py --run-id 12345

# Deploy local build
./scripts/deploy.py --local --build-type debug
```

**Requirements:**
- Android: `adb` (Android SDK Platform Tools)
- iOS: `ideviceinstaller` or `ios-deploy`
- GitHub deploys: `gh` (GitHub CLI)

See DOCKER.md for complete deployment documentation.

## What Claude Can Do

- ✅ Run Flutter analyze, test, and build via MCP server
- ✅ Query test failures and analysis issues
- ✅ Generate mocks with `scripts/mocks.sh`
- ✅ Deploy to connected devices via `scripts/deploy.py`
- ✅ Maintain the Flutter MCP server (`flutter-mcp-server/`)

## What Claude Can't Do (Yet)

- Run the Flutter app interactively (hot reload, debugging)
- Deploy to app stores (Google Play, App Store)
- Set up actual Supabase projects (can provide SQL and config)
- Sign Android/iOS builds for production

For these, you'll need to follow the instructions Claude provides.

## Project-Specific Conventions

### File Naming
- Features: `feature_name.dart`
- Providers: `feature_name_provider.dart`
- Models: `feature_name_model.dart`
- Tests: `feature_name_test.dart`

### Code Style
- Follow Flutter style guide
- Use meaningful variable names
- Document complex logic
- Keep functions small and focused

### Database Naming
- Tables: plural, snake_case (`choir_members`)
- Columns: snake_case (`created_at`)
- Foreign keys: `table_id` (`choir_id`)

### Git Commits
- Use conventional commits
- Reference issue numbers if applicable
- Keep commits atomic (one logical change)

## Tips for Effective Collaboration

1. **Start broad, then narrow**: Ask architectural questions before implementation details
2. **Validate against docs**: Ask Claude to verify implementations against REQUIREMENTS.md
3. **Iterate**: Don't expect perfect code first try, refine iteratively
4. **Update docs**: Keep documentation in sync with code changes
5. **Ask "why"**: Understanding decisions helps maintain the project

## Quick Reference

- **Requirements**: See REQUIREMENTS.md
- **Architecture**: See ARCHITECTURE.md
- **Tasks**: See TODO.md
- **Testing Guidelines**: See TESTING_GUIDELINES.md
- **Docker & Deployment**: See DOCKER.md
- **Android Device Debugging**: See DEVICE_DEBUGGING.md
- **Flutter MCP Server**: `flutter-mcp-server/` (maintained by Claude)
- **Shell Scripts**: `scripts/` (for CI and manual use)
- **Deploy to Device**: `./scripts/deploy.py` (see DOCKER.md)
- **Generate Mocks**: `scripts/mocks.sh`
- **Database Schema**: ARCHITECTURE.md → Database Schema section
- **Tech Stack**: ARCHITECTURE.md → Technology Stack section
- **User Workflows**: REQUIREMENTS.md → User Workflows section

### Key MCP Tools

| Task | MCP Tool |
|------|----------|
| Full validation | `mcp__flutter__run_validation` |
| Run tests | `mcp__flutter__flutter_test` |
| Run analysis | `mcp__flutter__flutter_analyze` |
| Get test failures | `mcp__flutter__get_test_results` |
| Get analysis issues | `mcp__flutter__get_analyze_results` |
| Build app | `mcp__flutter__flutter_build` |

## Example Session

```
You: I want to implement the "create choir" feature

Claude: I'll help implement choir creation. Looking at REQUIREMENTS.md,
users should be able to create a choir and become its owner. According
to ARCHITECTURE.md, we're using clean architecture. Let me create:
1. Domain entity (Choir)
2. Use case (CreateChoir)
3. Repository interface
4. Riverpod provider
5. UI screen

Should I proceed?

You: Yes, and update TODO.md when done

Claude: [implements feature and updates docs]
```

## Conclusion

This project has comprehensive documentation. Claude can be most helpful when:
- You reference the existing docs
- You're specific about what you need
- You ask Claude to maintain the documentation
- You validate implementations against requirements

The architecture is well-defined, so focus on implementation and testing. Claude can help write code that follows the established patterns and keep documentation up to date.

Happy coding! 🎵

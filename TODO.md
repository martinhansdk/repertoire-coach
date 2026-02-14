# Repertoire Coach - TODO List

## Project Setup
- [x] Initialize git repository
- [x] Create REQUIREMENTS.md
- [x] Create ARCHITECTURE.md
- [x] Create TODO.md
- [x] Create README.md
- [x] Initialize Flutter project
- [x] Setup project structure (folders: core, data, domain, presentation)
- [x] Add dependencies to pubspec.yaml (riverpod, intl, equatable, mockito, build_runner)
- [ ] Setup Supabase project
- [ ] Configure Supabase for Android
- [ ] Configure Supabase for iOS
- [ ] Configure Supabase for Web

## Vertical Slice - Concert List Feature with Local-First Architecture (COMPLETED)
**Status:** ✅ Complete
**Date:** 2025-11-23

Implemented a complete offline-first feature demonstrating the full stack:
- [x] Core layer (constants, theme)
- [x] Domain entities (Choir, Concert)
- [x] Domain repository interface
- [x] Data models (ChoirModel, ConcertModel) with Drift conversions
- [x] Drift SQLite database schema
- [x] Local data source with CRUD operations
- [x] Repository implementation using Drift
- [x] Riverpod providers with proper dependency injection
- [x] Concert card widget
- [x] Concert list screen with loading/error/empty states
- [x] Main app setup with Riverpod integration
- [x] Unit tests for entities (5 tests)
- [x] Unit tests for repository (5 tests)
- [x] Widget tests for concert card (4 tests)
- [x] Widget tests for concert list screen (6 tests)
- [x] App smoke test (1 test)
- [x] Docker build infrastructure with SQLite support

**Test Results:** ✅ 190 tests passing, 22 skipped

**What Works:**
- ✅ Data persists across app restarts (SQLite)
- ✅ App works 100% offline
- ✅ Concerts are automatically sorted (upcoming first, then past)
- ✅ Choir name displayed with each concert
- ✅ Pull-to-refresh functionality
- ✅ Loading, error, and empty states handled
- ✅ Clean architecture demonstrated across all layers
- ✅ Reactive streams - UI updates automatically on data changes

**Next Steps:** Add more features (choirs, songs, tracks) using local-first pattern, then add Supabase cloud sync in Phase 2

## Phase 1: Core Functionality (Local-First)

**Status:** 🟡 Mostly Complete - Core features done, missing playback position persistence

**What Works:**
- ✅ Full choir management (create, view, add/remove members)
- ✅ Concert management (create, edit, delete, sorted by date)
- ✅ Song library (create, edit, delete songs within concerts)
- ✅ Track management (add tracks, edit metadata)
- ✅ Audio playback (play, pause, stop, seek, progress tracking)
- ✅ File import (file picker + Android sharing)
- ✅ Navigation between choirs, concerts, songs
- ✅ All data persists locally in SQLite

**What's Missing:**
- ✅ ~~Playback position auto-save/resume~~ (DONE - 2025-11-27)
- ✅ ~~Quick rewind button (10 seconds)~~ (DONE - 2025-11-27)
- ❌ Filter concerts by choir
- ❌ Default to last accessed concert on launch
- ❌ Section markers (data layer not implemented)

**Next Steps:**
1. ~~Implement playback position persistence~~ ✅ DONE (2025-11-27)
2. ~~Add quick rewind button~~ ✅ DONE (2025-11-27)
3. Add concert filtering
4. Implement last accessed concert tracking

### Data Layer
- [x] Create data models for Concert
- [x] Create data models for Choir
- [x] Create data models for Song
- [x] Create data models for Track
- [x] Create data models for User
- [x] Create data models for UserPlaybackState
- [x] Create data models for Marker/MarkerSet (sections)
- [x] Setup local database (SQLite/drift)
- [x] Add Drift tables for Choir, Concert, Song, Track
- [x] Implement local data source for Concert
- [x] Implement local data source for Choir
- [x] Implement local data source for Song
- [x] Implement local data source for Track
- [x] Implement repository for Concert
- [x] Implement repository for Choir
- [x] Implement repository for Song
- [x] Implement repository for Track
- [x] Implement repository for AudioPlayer
- [ ] Implement local data source for User (if needed for local-first)
- [x] Implement local data source for UserPlaybackState
- [ ] Implement local data source for Markers/Sections

### Domain Layer
- [x] Define domain entities (Concert, Choir, Song, Track, Marker, User, UserPlaybackState)
- [x] Create repository interface for Concert
- [x] Create repository interface for Choir
- [x] Create repository interface for Song
- [x] Create repository interface for Track
- [x] Create repository interface for AudioPlayer
- [x] Implement use cases for Concert (implicit in repository):
  - [x] Get concerts for choir (sorted by date)
  - [x] Get all concerts for user (across all choirs, sorted by date)
  - [x] Get concert by ID
  - [x] Create concert (within choir)
  - [x] Update concert (rename, change date)
  - [x] Delete concert
- [x] Implement use cases for Choir:
  - [x] Create choir
  - [x] Get user's choirs
  - [x] Add member to choir (owner only)
  - [x] Remove member from choir (owner only)
  - [x] Update choir name
- [x] Implement use cases for Song:
  - [x] Add song (to concert)
  - [x] Delete song
  - [x] Update song
  - [x] Get all songs in concert
  - [x] Get song by ID
- [x] Implement use cases for Track:
  - [x] Add track to song
  - [x] Delete track
  - [x] Update track
- [x] Implement use cases for Audio Playback:
  - [x] Play/pause/stop
  - [x] Seek to position
  - [x] Track progress
  - [x] Switch tracks/songs
  - [x] Quick rewind (10 seconds)
- [x] Implement use cases for Playback Position:
  - [x] Save playback position automatically (every 5 seconds)
  - [x] Get saved playback position
  - [x] Resume from saved position on track load
- [ ] Implement use case: Update user's last accessed concert

### Presentation Layer - Choir, Concert & Song Management
- [x] Create app shell (navigation, theme, bottom nav)
- [x] Concert list screen (shows all user's concerts sorted by date: upcoming, then past)
- [x] Concert card widget
- [x] Concert provider with Riverpod
- [x] Choir list screen
- [x] Choir card widget
- [x] Create choir dialog
- [x] Choir detail screen (view members, concerts)
- [x] Manage choir members screen (owner only)
- [x] Add member dialog
- [x] Choir provider with Riverpod
- [x] Create concert dialog (with date picker)
- [x] Edit concert dialog (with date picker)
- [x] Song list screen (list view within concert)
- [x] Song detail screen
- [x] Create song dialog
- [x] Edit song dialog
- [x] Song provider with Riverpod
- [x] Add track dialog (file picker integration)
- [x] Edit track dialog
- [x] Track provider with Riverpod
- [x] Audio player screen with playback controls
- [x] File storage service and provider
- [x] Android sharing integration (receive_sharing_intent)
- [ ] Filter concerts by choir
- [ ] Default to most recently accessed concert on app launch

### Audio Playback (Local Files)
- [x] Setup audio player service (AudioPlayerRepositoryImpl with just_audio)
- [x] Implement basic playback controls (play, pause, stop)
- [x] Seek functionality
- [x] Progress tracking (via PlaybackInfo streams)
- [x] Playback UI (AudioPlayerScreen with controls)
- [x] File import functionality (FileStorageService + file_picker)
- [x] Android sharing integration (receive_sharing_intent)
- [x] Quick rewind button (10 seconds) - Added 2025-11-27
- [x] Save playback position automatically (every 5 seconds while playing) - Added 2025-11-27
- [x] Resume from saved position on track load - Added 2025-11-27

## Phase 2: Cloud Integration

**Status:** 🟡 In Progress - Step 2 (Authentication) Complete
**Started:** 2025-12-16
**Current Step:** Step 2 Complete, Ready for Step 3 (Remote Data Sources)

### Step 1: Supabase Setup (External - Manual)
- [ ] Create Supabase project (manual step - documented in plan)
- [ ] Setup PostgreSQL database schema (SQL provided in ARCHITECTURE.md lines 200-324)
- [ ] Implement Row Level Security policies (SQL provided in ARCHITECTURE.md lines 376-578)
  - ⚠️ **PENDING (2026-02-03):** `users_select_for_member_lookup` policy has NOT been applied yet.
    Run in Supabase SQL editor:
    `CREATE POLICY "users_select_for_member_lookup" ON users FOR SELECT TO authenticated USING (true);`
    Without this, adding choir members by email always returns "No account found".
- [ ] Setup Supabase Storage buckets with policies (SQL provided in plan)
- [ ] Enable Email/Password authentication

### Step 2: Authentication Layer ✅ COMPLETE (2025-12-16)
- [x] Add supabase_flutter dependency (^2.5.0)
- [x] Create SupabaseService singleton for client management
- [x] Create Environment configuration for credentials
- [x] Create AuthRepository interface (domain layer)
- [x] Create AuthRepositoryImpl (data layer)
- [x] Implement SignInScreen with validation
- [x] Implement SignUpScreen with validation
- [x] Create AuthWrapper for routing (sign in vs main app)
- [x] Create auth providers (AuthActions, currentUserProvider, isAuthenticatedProvider)
- [x] Update main.dart with conditional initialization
- [x] Graceful fallback to offline-only mode
- [x] Extract HomeScreen for reuse

**What Works:**
- ✅ App compiles successfully (0 errors, 0 warnings)
- ✅ Auth code passes static analysis
- ✅ Offline-first design preserved
- ✅ Two modes: offline-only (no credentials) or cloud-enabled (with Supabase)

**Outstanding Issues:**
- ⚠️ **No automated tests written** - Test environment issues prevented writing unit/widget tests
  - Attempted to write AuthRepositoryImpl unit tests but Supabase types difficult to mock
  - MCP test runner returning "0 tests" despite code compiling
  - Manual testing with real Supabase recommended
  - Integration tests would be more valuable than mocked unit tests
- ⚠️ Uses print() statements instead of proper logging (5 lint warnings)
- ⚠️ User record creation in users table not tested (happens after sign up)

**Next Actions:**
1. Manual: Complete Step 1 (Supabase project setup) using plan documentation
2. Begin Step 3: Remote Data Sources implementation

### Step 3: Remote Data Sources (Next Up)
- [ ] Create BaseRemoteDataSource with error handling
- [ ] Create RemoteChoirDataSource (CRUD operations via Supabase PostgreSQL)
- [ ] Create RemoteConcertDataSource
- [ ] Create RemoteSongDataSource
- [ ] Create RemoteTrackDataSource
- [ ] Create RemoteMarkerDataSource
- [ ] Create RemoteUserPlaybackStateDataSource
- [ ] Update all data models to implement fromJson/toJson for Supabase
- [ ] Write unit tests for each remote data source (mock Supabase client)
- [ ] Verify JSON serialization matches PostgreSQL schema

### Step 4: Repository Updates (Multi-Source Pattern)
- [ ] Update ConcertRepositoryImpl to accept both local and remote data sources
- [ ] Update ChoirRepositoryImpl for multi-source
- [ ] Update SongRepositoryImpl for multi-source
- [ ] Update TrackRepositoryImpl for multi-source
- [ ] Update MarkerRepositoryImpl for multi-source
- [ ] Implement offline-first pattern (always read from local, sync in background)
- [ ] Update providers to inject both local and remote data sources
- [ ] Determine sync mode based on auth state
- [ ] Write tests for offline/online mode behavior

### Step 5: Sync Engine (Partial - Remote-to-Local Complete)
- [ ] Add SyncQueue table to database schema (for offline operations)
- [ ] Create SyncOperation, SyncConflict, SyncStatus models
- [ ] Create SyncQueue service for offline queue management
- [x] Create SyncService for remote-to-local sync (lib/core/services/sync_service.dart)
- [ ] Implement syncToCloud() - upload local changes
- [x] Implement syncFromCloud() - download remote changes (syncFromRemote method)
- [ ] Implement conflict resolution (last write wins based on updated_at)
- [x] Create sync providers for UI integration (lib/presentation/providers/sync_provider.dart)
- [ ] Add periodic background sync (every 5 minutes)
- [ ] Create sync status indicator widget
- [ ] Handle network connectivity changes
- [x] Write comprehensive sync tests (unit + integration) - test/core/services/sync_service_test.dart

### Step 6: Storage Integration (Audio Files)
- [x] Create CloudStorageService for Supabase Storage operations (AudioStorageService)
- [x] Add storageUrl and storagePath fields to Track model (audioUrl, storagePath, durationMs)
- [x] Make audio files mandatory when adding tracks
- [x] Implement uploadTrackAudio() via AudioStorageService (supports both mobile file paths and web bytes)
- [ ] Update FileStorageService with saveDownloadedFile() method
- [ ] Implement ensureTrackCached() in TrackRepository (download on demand)
- [x] Update file import flow to trigger background upload (uploads immediately on track creation)
- [ ] Update audio player to ensure file cached before playing
- [ ] Implement cache management (delete old files if storage full)
- [x] Write tests for storage service (589/590 tests passing)

### Step 7: Real-time Subscriptions (Production-Ready)

**Overview:** Push-based real-time updates via Supabase Realtime for multi-device and multi-user collaboration.

**Architecture:**
```
Supabase Postgres → Realtime Channel → RealtimeService → Local DB → UI Refresh
```

**Components to Build:**

1. **RealtimeService** (~200 lines)
   - [ ] Create RealtimeService class with SupabaseClient dependency
   - [ ] Implement subscribe(userId) to connect to realtime channel
   - [ ] Implement unsubscribe() for cleanup
   - [ ] Handle reconnection on network drops
   - [ ] Handle app backgrounding/foregrounding

2. **Table Subscriptions** (one subscription per table)
   - [ ] Subscribe to `choirs` table (INSERT/UPDATE/DELETE)
   - [ ] Subscribe to `choir_members` table (membership changes)
   - [ ] Subscribe to `concerts` table
   - [ ] Subscribe to `songs` table
   - [ ] Subscribe to `tracks` table (including new audio uploads)
   - [ ] Subscribe to `marker_sets` table (shared marker sets between users)
   - [ ] Subscribe to `markers` table

3. **Change Handlers** (apply individual changes to local DB)
   - [ ] Handle INSERT: upsert new record to local database
   - [ ] Handle UPDATE: upsert updated record to local database
   - [ ] Handle DELETE: soft-delete or remove from local database
   - [ ] Invalidate relevant Riverpod providers after changes

4. **Provider Integration** (~50 lines)
   - [ ] Create realtimeServiceProvider
   - [ ] Create realtimeListenerProvider (watches auth, manages subscription lifecycle)
   - [ ] Wire change handlers to invalidate choirsProvider, concertsProvider, etc.

5. **Supabase Configuration** (migration)
   - [ ] Enable Realtime on tables: `ALTER PUBLICATION supabase_realtime ADD TABLE songs;`
   - [ ] Verify RLS policies work with Realtime (filters by user automatically)

6. **Conflict Resolution**
   - [ ] Implement last-write-wins based on updated_at timestamp
   - [ ] Handle case where user edits locally while remote change arrives
   - [ ] Queue local changes when offline, apply after reconnection

7. **Testing**
   - [ ] Unit tests for RealtimeService (mock Supabase channel)
   - [ ] Integration tests for change handlers
   - [ ] Manual test: two browsers, add song in one, appears in other
   - [ ] Manual test: network disconnect/reconnect

**Estimated Effort:** 40+ hours for production-ready implementation

**Notes:**
- Marker sets CAN be shared between users (not just private per-user)
- RLS policies filter realtime events automatically per user
- Consider starting with MVP (trigger full sync on any change) then optimize

### Error Reporting ✅ COMPLETE (2026-02-04)
- [x] Created `error_logs` table with INSERT-only RLS (`user_id` defaults to `auth.uid()`)
- [x] Created `ErrorReporter` service (fire-and-forget, silently drops when offline)
- [x] Hooked `FlutterError.onError` and `runZonedGuarded` for uncaught errors
- [x] Instrumented sign_in, sign_up, create_choir, add_member, audio_player catch blocks
- [x] Added unit tests (`test/core/services/error_reporter_test.dart`)
- ⚠️ **Migration `006_create_error_logs.sql` must be run manually** — Supabase MCP is read-only

**Query errors on the dashboard:**
```sql
SELECT * FROM error_logs ORDER BY created_at DESC;
```

### Step 8: User Management UI
- [ ] Update ProfileScreen to display email and edit name
- [ ] Add SettingsScreen with sync settings (auto-sync, WiFi-only)
- [ ] Add cache management UI (clear cached audio files)
- [x] Update ChoirMembersScreen with email lookup (2026-02-03: member names/emails displayed, add-by-email with inline lookup errors, password-manager autofill on sign-in/sign-up)
- [ ] Add "Leave choir" button for non-owners
- [ ] Create ConnectionStatusBanner widget (online/offline/syncing)
- [ ] Add manual sync button in settings
- [ ] Write widget tests for new screens

### Step 9: Migration Strategy
- [ ] Create MigrationService to sync existing local data to cloud
- [ ] Create MigrationScreen with progress UI
- [ ] Trigger migration on first successful sign in
- [ ] Mark migration as completed in local storage
- [ ] Handle migration failures gracefully
- [ ] Write tests for migration logic

### Step 10: Testing & Integration
- [ ] Write integration tests for auth flow
- [ ] Write integration tests for sync flow
- [ ] Write integration tests for storage flow
- [ ] Write integration tests for realtime collaboration
- [ ] Manual testing: new user sign up
- [ ] Manual testing: existing user migration
- [ ] Manual testing: multi-device sync
- [ ] Manual testing: offline/online transitions
- [ ] Manual testing: real-time collaboration
- [ ] Performance testing with large datasets
- [ ] Validate all tests pass (target 70%+ coverage)


## Favorite Tracks Feature

**Status:** ✅ Complete
**Started:** 2026-02-14
**Completed:** 2026-02-14

**Goal:** Replace the top-level Concerts page with a Favorite Tracks page, allowing users quick access to frequently-used tracks.

### Database & Migration
- [x] Create Supabase migration `007_create_favorites_table.sql`
- [x] Add FavoriteTracks table to Drift database schema
- [ ] Apply migration to Supabase (manual step - requires Supabase dashboard access)

### Domain Layer
- [x] Create `FavoriteTrack` entity with denormalized fields (trackName, songTitle, choirName)
- [x] Create `FavoriteTrackRepository` interface

### Data Layer
- [x] Create `FavoriteTrackModel` (Drift-compatible)
- [x] Create `LocalFavoriteTrackDataSource` (Drift operations)
- [x] Create `RemoteFavoriteTrackDataSource` (Supabase operations with joins)
- [x] Create `FavoriteTrackRepositoryImpl` (offline-first pattern)

### Presentation Layer
- [x] Create `favorite_track_provider.dart` with providers:
  - [x] `favoritesProvider` - all user's favorites
  - [x] `isFavoriteProvider` - check if track is favorited
  - [x] `favoriteCountProvider` - for startup logic
  - [x] `favoriteTrackActionsProvider` - add/remove/toggle actions
- [x] Create `FavoriteTracksScreen` (list of favorites with empty/error states)
- [x] Create `FavoriteTrackCard` widget (displays song title, track name, choir name)
- [x] Update `AudioPlayerScreen` - add favorite toggle button in app bar
- [x] Update `TrackCard` - add favorite toggle button
- [x] Update `HomeScreen`:
  - [x] Replace ConcertListScreen with FavoriteTracksScreen in bottom nav
  - [x] Implement startup logic (show Favorites if any exist, else Choirs)
  - [x] Update navigation icons (Concerts → Favorites)

### Sync & Cloud
- [x] Offline-first favoriting (saves locally, syncs when online)
- [ ] Update `sync_provider.dart` to include favorites sync (future enhancement)
- [x] Handle sync conflicts (remote wins pattern)

### Cleanup
- [x] Delete `concert_list_screen.dart`
- [x] Delete `concert_list_screen_test.dart`
- [x] Delete `concert_list_screen_test.mocks.dart`
- [x] Remove concert list imports from home_screen.dart

### Testing
- [x] Unit tests for FavoriteTrack entity
- [x] Unit tests for FavoriteTrackModel
- [x] Widget tests for FavoriteTracksScreen
- [x] Widget tests for FavoriteTrackCard
- [x] All tests passing (747/803 passed, 56 skipped, 0 failed)

### Documentation
- [x] Update ARCHITECTURE.md (database schema, indexes, query examples)
- [x] Update REQUIREMENTS.md (favorite tracks feature, navigation changes, user workflows)
- [x] Mark this task complete in TODO.md

**Actual Effort:** ~4 hours (data layer) + ~2 hours (UI layer) = ~6 hours

**What Works:**
- ✅ Favorites sync across devices via Supabase
- ✅ Smart startup: shows Favorites page if user has any, else Choirs page
- ✅ Favorite/unfavorite from: audio player, track list, favorites page
- ✅ Denormalized display: song title (most prominent), track name, choir name
- ✅ Tapping a favorite opens audio player immediately
- ✅ All concert functionality preserved in Choir Detail screen
- ✅ Offline-first: works without network connection
- ✅ Pull-to-refresh on favorites page

**Test Results:** ✅ 747 tests passing, 0 failed, 56 skipped

## Phase 3: Advanced Playback Features

### Section Marking
- [ ] UI for marking section start
- [ ] UI for marking section end
- [ ] Save section to database (local + cloud)
- [ ] Name/edit section functionality
- [ ] Delete section functionality

### Section Practice
- [ ] Display list of sections for current track
- [ ] Select section to practice
- [ ] Loop section continuously
- [ ] Visual indicator of section boundaries during playback

### Enhanced Playback UI
- [ ] Waveform visualization (optional)
- [ ] Section markers on progress bar
- [ ] Jump to section from progress bar

## Phase 4: Multi-Platform

### iOS
- [ ] Test on iOS devices
- [ ] Fix iOS-specific issues
- [ ] iOS audio session handling
- [ ] Background audio on iOS

### Web/Desktop
- [ ] Test web build
- [ ] Responsive design for desktop
- [ ] Web-specific audio handling
- [ ] Deploy web version

### Cross-Device Sync
- [ ] Test sync across multiple devices
- [ ] Conflict resolution (if needed)
- [ ] Sync status indicators

## Phase 5: Android Auto

### Native Android Development
- [ ] Create Android module in Flutter project
- [ ] Implement MediaBrowserService
- [ ] Implement MediaSession
- [ ] Build media hierarchy (browsable concerts and songs)
- [ ] Expose concerts as folders in Android Auto
- [ ] Default to most recently accessed concert
- [ ] Handle playback commands from Auto

### Platform Channel Integration
- [ ] Create platform channel between Flutter and Android
- [ ] Expose concert and song library to native Android
- [ ] Send playback commands from native to Flutter
- [ ] Update native MediaSession from Flutter playback state
- [ ] Sync last accessed concert between Flutter and native

### Testing & Refinement
- [ ] Test with Android Auto simulator
- [ ] Test in actual vehicle (if possible)
- [ ] Optimize UI for car display
- [ ] Follow Android Auto design guidelines

## Polish & Release Preparation

## Testing (Ongoing Priority)

**Current Status (as of 2025-12-05):**
- Overall: 56.3% line coverage (up from 42%) ✅
- Tests: 381 passing, 21 skipped
- Domain: 100% (excellent) ✅
- Data: 70%+ (good) ✅
- Presentation: 50%+ (moderate) ⚠️
- CI: Automated coverage reporting with GitHub Actions summary

**See [TESTING_GUIDELINES.md](TESTING_GUIDELINES.md) for complete testing standards.**

**Coverage Script:**
```bash
# Generate coverage locally
./scripts/coverage.sh

# Coverage is automatically run in CI and displayed in workflow summary
```

### Recent Improvements (2025-12-05)
- [x] ~~Test `choir_list_screen.dart`~~ ✅ 14 tests added
- [x] ~~Test `choir_detail_screen.dart`~~ ✅ 19 tests added
- [x] ~~Test `song_detail_screen.dart`~~ ✅ 13 tests added
- [x] ~~Test `choir_members_screen.dart`~~ ✅ 19 tests added
- [x] ~~Added CI coverage reporting~~ ✅ GitHub Actions summary
- [x] ~~Created coverage script~~ ✅ `scripts/coverage.sh`

### Remaining Test Gaps

**Priority 1: Data Source Layer**
- [ ] Test `local_song_data_source.dart` (CRUD, soft delete, sync state)
- [ ] Test `local_concert_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_choir_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_track_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_section_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_user_data_source.dart` (CRUD)
- [ ] Test `local_user_playback_state_data_source.dart` (CRUD)

**Priority 2: Provider Layer**
- [ ] Test `concert_provider.dart` (initialization, dependencies, async loading)
- [ ] Test `song_provider.dart`
- [ ] Test `choir_provider.dart`
- [ ] Test `audio_player_provider.dart`
- [ ] Test `file_storage_provider.dart`
- [ ] Test `sync_provider.dart` (when implemented)

**Priority 3: AudioPlayerScreen**
- [ ] Extract `AudioPlaybackNotifier` StateNotifier (improves testability)
- [ ] Extract `TrackNavigationUseCase` (improves testability)
- [ ] Write widget tests for AudioPlayerScreen (play/pause/seek/navigation)

**Priority 4: Skipped Tests**
- [ ] Investigate 21 skipped tests (complex async/dialog timing issues)
- [ ] Fix or document as known limitations
- [ ] Consider alternative testing approaches for problematic scenarios

**Priority 5: Complete Model Tests**
- [ ] Test `choir_model.dart` (serialization, entity conversion)
- [ ] Test `song_model.dart`
- [ ] Test `track_model.dart`
- [ ] Test `section_model.dart`
- [ ] Test `user_playback_state_model.dart`

### Test Infrastructure Improvements

**Create Test Utilities (Reduces Duplication)**
- [ ] Create `test/helpers/test_fixtures.dart` - shared test data
- [ ] Create `test/helpers/test_database_helper.dart` - database setup
- [ ] Create `test/helpers/test_widget_wrapper.dart` - provider overrides

**Improve Code Testability**
- [ ] Extract `AudioPlayerService` interface (enables mocking)
- [ ] Remove `AudioPlayerControls` helper class anti-pattern
- [ ] Remove `FileImportControls` helper class anti-pattern
- [ ] Create `FileStorageService` interface (enables mocking)
- [ ] Separate initialization from construction in `AudioPlayerRepositoryImpl`

### Integration Tests
- [ ] Test complete user workflow: create choir → concert → song → play
- [ ] Test error recovery flows
- [ ] Test concurrent operations

### General Testing Tasks
- [ ] Test error scenarios
- [ ] Performance testing with large libraries

### UI/UX Polish
- [ ] App icon
- [ ] Splash screen
- [ ] Loading states
- [ ] Error states
- [ ] Empty states
- [ ] Animations and transitions
- [ ] Accessibility features

### Documentation
- [ ] User guide / help section
- [ ] API documentation (if applicable)
- [ ] Code documentation / comments

### Release
- [ ] Android release build
- [ ] iOS release build
- [ ] Web deployment
- [ ] Google Play Store listing
- [ ] Apple App Store listing
- [ ] Release notes

## Future Enhancements (Post-Launch)
- [ ] Share songs between users
- [ ] Playlist creation
- [ ] Practice session statistics
- [ ] Adjustable playback speed
- [ ] Pitch adjustment
- [ ] Import from URLs (YouTube, etc.)
- [ ] Export practice logs
- [ ] Multiple language support
- [ ] Dark mode
- [ ] Tablet-optimized UI

## Notes
- Focus on getting core functionality working locally first
- Add cloud features incrementally
- Android Auto is the most complex feature - save for last
- Test on real devices early and often
- Keep the UI simple and intuitive for in-car use

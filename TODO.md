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
- ❌ Playback position auto-save/resume
- ❌ Quick rewind button (10 seconds)
- ❌ Filter concerts by choir
- ❌ Default to last accessed concert on launch
- ❌ Section markers (data layer not implemented)
- ❌ User playback state persistence

**Next Steps:**
1. Implement playback position persistence (most important UX feature)
2. Add quick rewind button
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
- [ ] Implement local data source for UserPlaybackState
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
- [ ] Implement use cases for Playback Position:
  - [ ] Save playback position automatically
  - [ ] Get saved playback position
  - [ ] Resume from saved position
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
- [ ] Quick rewind button (10 seconds)
- [ ] Save playback position automatically (TODO in repository)
- [ ] Resume from saved position on track load (TODO in repository)

## Phase 2: Cloud Integration

### Supabase Setup
- [ ] Create Supabase project
- [ ] Setup PostgreSQL database schema (tables, indexes, triggers)
- [ ] Implement Row Level Security (RLS) policies for all tables
- [ ] Setup Supabase Authentication
- [ ] Implement login/signup screens
- [ ] Setup Supabase Storage buckets
- [ ] Define Storage policies (choir-based access control)

### Data Synchronization
- [ ] Implement remote data sources (PostgreSQL + Supabase Storage)
- [ ] Integrate Supabase client in Flutter app
- [ ] Sync choir data to PostgreSQL (shared among members)
- [ ] Sync choir membership changes
- [ ] Sync concert data to PostgreSQL (within choirs, sorted by date)
- [ ] Sync song metadata to PostgreSQL (within concerts, shared)
- [ ] Upload audio files to Supabase Storage (choir-scoped paths)
- [ ] Sync tracks to PostgreSQL (shared)
- [ ] Sync section markers to PostgreSQL (per-user, private)
- [ ] Sync playback positions to PostgreSQL (per-user, private)
- [ ] Sync user's last accessed concert
- [ ] Download audio files from cloud
- [ ] Implement real-time subscriptions for critical data updates
- [ ] Handle offline/online modes
- [ ] Implement offline queue for pending operations
- [ ] Background sync service

### User Management
- [ ] User profile screen
- [ ] View user's choirs
- [ ] Leave choir functionality
- [ ] Sign out functionality
- [ ] Account settings

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

**Current Status (as of 2025-11-27):**
- Overall: 42% file coverage (28/67 files)
- Domain: 91% (excellent) ✅
- Data: 50% (moderate gaps) ⚠️
- Presentation: 27% (critical gaps) ❌
- 22 tests skipped (13.8% of suite) ⚠️

**See [TESTING_GUIDELINES.md](TESTING_GUIDELINES.md) for complete testing standards.**

### Critical Test Gaps to Address

**Priority 1: Data Source Layer (CRITICAL)**
- [ ] Test `local_song_data_source.dart` (CRUD, soft delete, sync state)
- [ ] Test `local_concert_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_choir_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_track_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_section_data_source.dart` (CRUD, soft delete)
- [ ] Test `local_user_data_source.dart` (CRUD)
- [ ] Test `local_user_playback_state_data_source.dart` (CRUD)

**Priority 2: Provider Layer (CRITICAL)**
- [ ] Test `concert_provider.dart` (initialization, dependencies, async loading)
- [ ] Test `song_provider.dart`
- [ ] Test `choir_provider.dart`
- [ ] Test `audio_player_provider.dart`
- [ ] Test `file_storage_provider.dart`
- [ ] Test `sync_provider.dart` (when implemented)

**Priority 3: AudioPlayerScreen (CRITICAL)**
- [ ] Extract `AudioPlaybackNotifier` StateNotifier (improves testability)
- [ ] Extract `TrackNavigationUseCase` (improves testability)
- [ ] Write widget tests for AudioPlayerScreen (play/pause/seek/navigation)

**Priority 4: Fix Skipped Tests**
- [ ] Fix timer infrastructure issues in widget tests
- [ ] Enable 22 currently skipped tests
- [ ] Document platform-specific test limitations

**Priority 5: Complete Model Tests**
- [ ] Test `choir_model.dart` (serialization, entity conversion)
- [ ] Test `song_model.dart`
- [ ] Test `track_model.dart`
- [ ] Test `section_model.dart`
- [ ] Test `user_playback_state_model.dart`

**Priority 6: Screen Tests**
- [ ] Test `choir_list_screen.dart` (loading/error/empty states, navigation)
- [ ] Test `choir_detail_screen.dart`
- [ ] Test `song_detail_screen.dart`
- [ ] Test `choir_members_screen.dart`

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

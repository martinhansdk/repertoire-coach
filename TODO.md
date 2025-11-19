# Choir Practice App - TODO List

## Project Setup
- [x] Initialize git repository
- [x] Create REQUIREMENTS.md
- [x] Create ARCHITECTURE.md
- [x] Create TODO.md
- [ ] Create README.md
- [ ] Initialize Flutter project
- [ ] Setup project structure (folders: core, data, domain, presentation)
- [ ] Add dependencies to pubspec.yaml (just_audio, riverpod, firebase packages)
- [ ] Setup Firebase project
- [ ] Configure Firebase for Android
- [ ] Configure Firebase for iOS
- [ ] Configure Firebase for Web

## Phase 1: Core Functionality (Local-First)

### Data Layer
- [ ] Create data models (Song, Track, Section, User)
- [ ] Setup local database (SQLite/drift)
- [ ] Implement local repository interfaces
- [ ] Implement local data sources

### Domain Layer
- [ ] Define domain entities
- [ ] Create repository interfaces
- [ ] Implement use cases:
  - [ ] Add song
  - [ ] Delete song
  - [ ] Add track to song
  - [ ] Delete track
  - [ ] Get all songs
  - [ ] Get song by ID

### Presentation Layer - Song Library
- [ ] Create app shell (navigation, theme)
- [ ] Song library screen (list view)
- [ ] Add song dialog/screen
- [ ] Song detail screen
- [ ] Add track functionality (file picker integration)

### Audio Playback (Local Files)
- [ ] Setup audio player service
- [ ] Implement basic playback controls (play, pause, stop)
- [ ] Seek functionality
- [ ] Progress tracking
- [ ] Playback UI (now playing screen)
- [ ] Quick rewind button (10 seconds)

## Phase 2: Cloud Integration

### Firebase Setup
- [ ] Setup Firebase Authentication
- [ ] Implement login/signup screens
- [ ] Setup Cloud Firestore
- [ ] Define Firestore security rules
- [ ] Setup Firebase Storage
- [ ] Define Storage security rules

### Data Synchronization
- [ ] Implement remote data sources (Firestore + Storage)
- [ ] Upload audio files to Firebase Storage
- [ ] Sync song metadata to Firestore
- [ ] Sync tracks to Firestore
- [ ] Download audio files from cloud
- [ ] Handle offline/online modes
- [ ] Background sync service

### User Management
- [ ] User profile screen
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
- [ ] Build media hierarchy (browsable songs)
- [ ] Handle playback commands from Auto

### Platform Channel Integration
- [ ] Create platform channel between Flutter and Android
- [ ] Expose song library to native Android
- [ ] Send playback commands from native to Flutter
- [ ] Update native MediaSession from Flutter playback state

### Testing & Refinement
- [ ] Test with Android Auto simulator
- [ ] Test in actual vehicle (if possible)
- [ ] Optimize UI for car display
- [ ] Follow Android Auto design guidelines

## Polish & Release Preparation

### Testing
- [ ] Write unit tests for core business logic
- [ ] Write widget tests for UI components
- [ ] Integration tests for critical flows
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

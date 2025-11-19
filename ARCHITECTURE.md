# Choir Practice App - Technical Architecture

## Technology Stack

### Frontend Framework
- **Flutter**: Primary development framework
  - Single codebase for Android, iOS, and Web
  - Excellent performance for audio applications
  - Rich ecosystem of audio packages
  - Native compilation for mobile platforms
  - Web compilation for desktop browser access

### Platform-Specific Development
- **Native Android (Kotlin/Java)**: For Android Auto integration
  - MediaBrowserService implementation
  - Android Auto UI adaptation
  - Flutter platform channels for communication

### Backend Services
- **Firebase** (recommended option):
  - **Firebase Authentication**: User login and identity management
  - **Cloud Firestore**: NoSQL database for song metadata, user data, section markers
  - **Firebase Storage**: Cloud storage for audio files
  - **Firebase Functions**: Optional serverless functions for backend logic

Alternative: Custom backend with PostgreSQL + S3-compatible storage

### Audio Playback
- **just_audio** package (recommended):
  - Cross-platform audio playback
  - Seeking, looping, position tracking
  - Background audio support
  - Good performance with large files

Alternative: **audioplayers** package

### State Management
- **Riverpod** (recommended):
  - Modern, compile-safe state management
  - Easy testing
  - Good performance
  - Provider pattern evolution

Alternatives: Provider, Bloc, GetX

## Architecture Patterns

### Application Architecture
- **Clean Architecture** principles:
  - Separation of concerns
  - Testable business logic
  - Framework-independent core logic

### Layer Structure
```
lib/
├── core/               # Shared utilities, constants, base classes
├── data/              # Data layer
│   ├── models/        # Data models (Choir, Concert, Song, Track, Section, User, UserPlaybackState)
│   ├── repositories/  # Repository implementations
│   └── datasources/   # Remote (Firebase) and local (SQLite) data sources
├── domain/            # Business logic layer
│   ├── entities/      # Domain entities
│   ├── repositories/  # Repository interfaces
│   └── usecases/      # Business use cases
├── presentation/      # UI layer
│   ├── screens/       # App screens/pages
│   ├── widgets/       # Reusable widgets
│   └── providers/     # State management providers
└── platform/          # Platform-specific code
    └── android_auto/  # Android Auto integration
```

## Data Models

### Core Entities

#### Choir
```dart
class Choir {
  String id;
  String name;
  String ownerId;  // User who created and manages the choir
  List<String> memberIds;  // All members (including owner)
  DateTime createdAt;
  DateTime updatedAt;
}
```

#### Concert
```dart
class Concert {
  String id;
  String choirId;  // Which choir this concert belongs to
  String name;  // Concert title
  DateTime concertDate;  // Date of the concert (required for sorting)
  DateTime createdAt;
  DateTime updatedAt;
}
```

#### Song
```dart
class Song {
  String id;
  String concertId;  // Concert this song belongs to (which determines choir access)
  String title;
  DateTime createdAt;
  DateTime updatedAt;
  // Note: Tracks are subcollection, Sections are stored separately per-user
}
```

#### Track
```dart
class Track {
  String id;
  String songId;
  String name;  // "Soprano", "Tenor", "Full Choir", etc.
  VoiceType type;  // Enum: soprano, alto, tenor, bass, full, other
  String audioUrl;  // Cloud storage URL
  String? localPath;  // Local cached file path
  int duration;  // Duration in milliseconds
  DateTime createdAt;
}
```

#### Section
```dart
class Section {
  String id;
  String songId;
  String trackId;
  String userId;  // Sections are per-user
  String name;  // User-defined name for section
  int startTime;  // Start position in milliseconds
  int endTime;    // End position in milliseconds
  DateTime createdAt;
}
```

#### User
```dart
class User {
  String id;
  String email;
  String displayName;
  List<String> choirIds;  // Choirs user is a member of
  String? lastAccessedConcertId;  // Most recently accessed concert (per-user)
  DateTime createdAt;
}
```

#### UserPlaybackState
```dart
class UserPlaybackState {
  String id;  // Composite: userId_songId_trackId
  String userId;
  String songId;
  String trackId;
  int position;  // Last playback position in milliseconds
  DateTime updatedAt;
}
```

## Database Schema (Firestore)

### Collections Structure
```
users/
  {userId}/
    - email
    - displayName
    - choirIds  // Array of choir IDs user belongs to
    - lastAccessedConcertId  // Most recent concert (per-user)
    - createdAt

choirs/
  {choirId}/
    - name
    - ownerId  // User who created the choir
    - memberIds  // Array of user IDs (all members)
    - createdAt
    - updatedAt

concerts/
  {concertId}/
    - choirId  // Which choir this belongs to
    - name
    - concertDate  // Date of concert (for sorting)
    - createdAt
    - updatedAt

songs/
  {songId}/
    - concertId  // Concert this belongs to (determines choir access)
    - title
    - createdAt
    - updatedAt

    tracks/ (subcollection)
      {trackId}/
        - name
        - type
        - audioUrl
        - duration
        - createdAt

sections/
  {sectionId}/
    - userId  // Sections are per-user
    - songId
    - trackId
    - name
    - startTime
    - endTime
    - createdAt

playbackStates/
  {stateId}/  // Composite ID: userId_songId_trackId
    - userId
    - songId
    - trackId
    - position  // Last playback position in milliseconds
    - updatedAt
```

### Queries and Indexes

**Common Queries:**
- Get user's choirs: `choirs.where('memberIds', 'array-contains', userId)`
- Get concerts for a choir: `concerts.where('choirId', '==', choirId).orderBy('concertDate')`
- Get all concerts for user (via their choirs): Client-side filtering after fetching concerts for each choir
- Get songs in a concert: `songs.where('concertId', '==', concertId)`
- Get user's sections for a song: `sections.where('userId', '==', userId).where('songId', '==', songId)`
- Get playback state: `playbackStates.doc('${userId}_${songId}_${trackId}')`
- Get user's last accessed concert: Read from `users/{userId}.lastAccessedConcertId`

**Required Firestore Indexes:**
- Composite index: `concerts` collection on `choirId` (ascending) + `concertDate` (ascending)
- Composite index: `sections` collection on `userId` (ascending) + `songId` (ascending)
- Single field index: `choirs.memberIds` (array-contains)

### Security Rules Considerations
- Users can only read/write choirs they are members of
- Only choir owner can modify choir membership
- Users can read/write concerts belonging to their choirs
- Users can read/write songs in concerts belonging to their choirs
- Users can only read/write their own sections and playback states
- Audio files in Storage: accessible to choir members whose concerts contain the song
- Prevent deletion of concerts with songs
- Choir owner cannot remove themselves unless transferring ownership

## Audio Playback Architecture

### Playback State Management
```dart
class AudioPlayerState {
  Track? currentTrack;
  PlaybackStatus status;  // playing, paused, stopped
  Duration position;
  Duration duration;
  Section? loopingSection;  // If looping a section
  bool isLooping;
}
```

### Playback Features Implementation

#### Quick Rewind (10 seconds)
- Get current position
- Subtract 10 seconds (min: 0)
- Seek to new position

#### Section Marking
- Listen to playback position updates
- On "mark start": record current position
- On "mark end": record current position, create Section object
- Save Section to Firestore

#### Section Looping
- Set player to loop mode
- Seek to section start
- Listen to position updates
- When position >= section end, seek back to section start

## Android Auto Integration

### Architecture
- **MediaBrowserService**: Android service that exposes media library
- **MediaSession**: Handles playback commands and state
- **Flutter Platform Channel**: Bridge between Flutter and native Android code

### Media Hierarchy
```
Root
├── Concerts
│   ├── Concert A
│   │   ├── Song 1 (Soprano)
│   │   ├── Song 1 (Alto)
│   │   ├── Song 1 (Tenor)
│   │   ├── Song 2 (Soprano)
│   │   └── ...
│   ├── Concert B
│   │   └── ...
│   └── ...
└── Recent Concert (Most Recently Accessed)
    └── ...
```

### Implementation Approach
1. Create native Android MediaBrowserService
2. Query Flutter app's concerts and song library via platform channel
3. Expose concerts as browsable folders and songs as media items
4. Default to most recently accessed concert
5. Handle playback commands (play, pause, skip, etc.)
6. Update Flutter app state via platform channel

## File Storage Strategy

### Local Storage
- **SQLite**: Cache choir, concert, song, and track metadata for offline access
- **File System**: Cache audio files for offline playback
- **Shared Preferences**: User settings, last accessed concert ID, playback preferences, etc.

### Cloud Storage
- **Firebase Storage** structure:
  ```
  audio_files/
    {choirId}/
      {concertId}/
        {songId}/
          {trackId}.mp3
  ```

### Sync Strategy
1. Choir member imports audio file for a track
2. File saved to local storage temporarily
3. Upload to Firebase Storage in background (choir-scoped path)
4. Save track metadata (including cloud URL) to Firestore
5. Delete local temp file, keep cached version
6. Other choir members: download on-demand or pre-cache
7. Per-user data (sections, playback positions) syncs independently

## Error Handling

### Network Errors
- Graceful degradation to offline mode
- Queue operations for later sync
- Show user-friendly error messages

### Audio Playback Errors
- Handle unsupported formats gracefully
- Retry failed loads
- Fallback to cached versions

### Storage Errors
- Handle quota exceeded scenarios
- Prompt user to free up space
- Manage cache size limits

## Performance Considerations

### Audio Performance
- Preload audio files before playback
- Use efficient audio codecs (MP3, M4A are good)
- Stream large files rather than loading entirely

### UI Performance
- Lazy load song lists
- Virtualized scrolling for large libraries
- Debounce search/filter operations

### Network Performance
- Batch Firestore operations
- Use Firestore offline persistence
- Compress audio uploads if needed
- Show upload/download progress

## Security Considerations

### Authentication
- Firebase Authentication with email/password
- Optional: Google Sign-In, Apple Sign-In
- Secure token management

### Data Privacy
- User songs and sections are private by default
- Firestore security rules enforce user isolation
- Audio files have user-specific access rules

### Storage Security
- Use Firebase Storage security rules
- Signed URLs for audio file access
- No public access to uploaded files

## Testing Strategy

### Unit Tests
- Business logic (use cases)
- Data models
- Repository implementations

### Widget Tests
- UI components
- Screen interactions
- State management

### Integration Tests
- End-to-end user flows
- Firebase integration
- Audio playback scenarios

### Platform-Specific Tests
- Android Auto functionality
- iOS audio session handling

## Development Phases

### Phase 1: Core Functionality
- Basic Flutter app setup
- Choir management UI (create, view, manage members)
- Concert management UI (within choirs, sorted by date)
- Song library UI (within concerts)
- Audio file import
- Local playback (without cloud)
- Playback position saving

### Phase 2: Cloud Integration
- Firebase setup
- User authentication
- Cloud storage for audio (choir-scoped)
- Firestore for shared data (choirs, concerts, songs)
- Firestore for per-user data (sections, playback states)
- Choir membership sync
- Concert and song sync across choir members

### Phase 3: Advanced Playback
- Section marking
- Section saving
- Section looping
- Quick rewind button

### Phase 4: Multi-Platform
- iOS optimization
- Web/desktop version
- Cross-device sync

### Phase 5: Android Auto
- Native Android service
- Platform channel integration
- Android Auto UI
- Testing in car/simulator

## Build & Deployment

### Android
- Target SDK: Latest stable (34+)
- Min SDK: 24 (Android 7.0) for broad compatibility
- Build: `flutter build apk` or `flutter build appbundle`

### iOS
- Target: iOS 13+
- Build: `flutter build ios`
- Requires: Apple Developer account, provisioning profiles

### Web
- Build: `flutter build web`
- Deploy: Firebase Hosting, Netlify, or any static host
- PWA support for offline capability

### CI/CD
- GitHub Actions or GitLab CI
- Automated testing
- Build artifacts for each platform

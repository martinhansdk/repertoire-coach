# Repertoire Coach - Technical Architecture

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
- **Supabase** (open-source Firebase alternative):
  - **PostgreSQL Database**: Relational database for all app data
  - **Supabase Auth**: User authentication and identity management
  - **Supabase Storage**: S3-compatible object storage for audio files
  - **Real-time Subscriptions**: PostgreSQL changes streamed to clients
  - **Row Level Security (RLS)**: Database-level access control for choir-based permissions
  - **Auto-generated APIs**: REST and GraphQL APIs from database schema
  - **Edge Functions**: Optional Deno-based serverless functions

**Why Supabase:**
- Open source (can self-host if needed, no vendor lock-in)
- PostgreSQL provides relational model with foreign keys and complex queries
- More cost-effective at scale than Firebase
- Real-time capabilities similar to Firestore
- Good Flutter support via official `supabase_flutter` package
- Row Level Security maps well to choir-based access control

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

### Internationalization (i18n)
- **Flutter intl** / **flutter_localizations**:
  - Built-in Flutter localization support
  - ARB (Application Resource Bundle) files for translations
  - Type-safe message access
  - Compile-time validation of translation keys
  - Supports plurals, genders, date/time formatting

**Supported Languages**: English (en), Danish (da)

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
│   ├── models/        # Data models (Choir, Concert, Song, Track, MarkerSet, Marker, User, UserPlaybackState)
│   ├── repositories/  # Repository implementations
│   └── datasources/   # Remote (Supabase) and local (SQLite) data sources
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
  // Note: Tracks are separate entities, MarkerSets belong to tracks
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

#### MarkerSet
```dart
class MarkerSet {
  String id;
  String trackId;  // Which track this marker set belongs to
  String name;  // Name of the set (e.g., "Musical Structure", "Bar Numbers")
  bool isShared;  // true = shared with choir, false = private to user
  String createdByUserId;  // User who created this marker set
  DateTime createdAt;
  DateTime updatedAt;
}
```

#### Marker
```dart
class Marker {
  String id;
  String markerSetId;  // Which marker set this belongs to
  String label;  // Marker label (e.g., "intro", "verse 1", "25")
  int positionMs;  // Position in track in milliseconds
  int order;  // Order within the marker set for display
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
  String languagePreference;  // User's preferred language code (e.g., 'en', 'da')
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

## Database Schema (PostgreSQL)

### Table Structure

```sql
-- Users table (managed by Supabase Auth, extended with custom fields)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  display_name VARCHAR(255),
  last_accessed_concert_id UUID,
  language_preference VARCHAR(10) DEFAULT 'en',  -- ISO 639-1 language code
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Choirs table
CREATE TABLE choirs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Choir members junction table (many-to-many relationship)
CREATE TABLE choir_members (
  choir_id UUID NOT NULL REFERENCES choirs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (choir_id, user_id)
);

-- Concerts table
CREATE TABLE concerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  choir_id UUID NOT NULL REFERENCES choirs(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  concert_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Songs table
CREATE TABLE songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concert_id UUID NOT NULL REFERENCES concerts(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tracks table
CREATE TABLE tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL,  -- soprano, alto, tenor, bass, full, other
  audio_url TEXT,
  storage_path TEXT,  -- Path in Supabase Storage
  duration_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Marker sets table (shared or private)
CREATE TABLE marker_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  is_shared BOOLEAN NOT NULL DEFAULT false,
  created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Markers table (positions within marker sets)
CREATE TABLE markers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  marker_set_id UUID NOT NULL REFERENCES marker_sets(id) ON DELETE CASCADE,
  label VARCHAR(255) NOT NULL,
  position_ms INTEGER NOT NULL,
  display_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Playback states table (per-user, private)
CREATE TABLE playback_states (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
  position_ms INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, song_id, track_id)
);

-- Indexes for performance
CREATE INDEX idx_choir_members_user ON choir_members(user_id);
CREATE INDEX idx_choir_members_choir ON choir_members(choir_id);
CREATE INDEX idx_concerts_choir_date ON concerts(choir_id, concert_date);
CREATE INDEX idx_songs_concert ON songs(concert_id);
CREATE INDEX idx_tracks_song ON tracks(song_id);
CREATE INDEX idx_marker_sets_track ON marker_sets(track_id);
CREATE INDEX idx_marker_sets_user ON marker_sets(created_by_user_id);
CREATE INDEX idx_markers_set ON markers(marker_set_id);
CREATE INDEX idx_playback_states_user ON playback_states(user_id);

-- Updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_choirs_updated_at BEFORE UPDATE ON choirs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_concerts_updated_at BEFORE UPDATE ON concerts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_songs_updated_at BEFORE UPDATE ON songs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_marker_sets_updated_at BEFORE UPDATE ON marker_sets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_playback_states_updated_at BEFORE UPDATE ON playback_states
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Common Queries

**Get user's choirs:**
```sql
SELECT c.* FROM choirs c
JOIN choir_members cm ON c.id = cm.choir_id
WHERE cm.user_id = $1
ORDER BY c.name;
```

**Get concerts for user (across all choirs, sorted by date):**
```sql
SELECT con.*, c.name as choir_name FROM concerts con
JOIN choirs c ON con.choir_id = c.id
JOIN choir_members cm ON c.id = cm.choir_id
WHERE cm.user_id = $1
ORDER BY
  CASE WHEN con.concert_date >= CURRENT_DATE THEN 0 ELSE 1 END,
  CASE WHEN con.concert_date >= CURRENT_DATE THEN con.concert_date END ASC,
  CASE WHEN con.concert_date < CURRENT_DATE THEN con.concert_date END DESC;
```

**Get songs in a concert:**
```sql
SELECT * FROM songs
WHERE concert_id = $1
ORDER BY title;
```

**Get marker sets for a track (shared + user's private):**
```sql
SELECT ms.*,
       (SELECT json_agg(m.* ORDER BY m.display_order)
        FROM markers m
        WHERE m.marker_set_id = ms.id) as markers
FROM marker_sets ms
WHERE ms.track_id = $1
  AND (ms.is_shared = true OR ms.created_by_user_id = $2)
ORDER BY ms.is_shared DESC, ms.name;
```

**Get or create playback state:**
```sql
INSERT INTO playback_states (user_id, song_id, track_id, position_ms)
VALUES ($1, $2, $3, $4)
ON CONFLICT (user_id, song_id, track_id)
DO UPDATE SET position_ms = $4, updated_at = NOW()
RETURNING *;
```

### Row Level Security (RLS) Policies

**Users table:**
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY users_select_own ON users
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY users_update_own ON users
  FOR UPDATE USING (auth.uid() = id);
```

**Choirs table:**
```sql
ALTER TABLE choirs ENABLE ROW LEVEL SECURITY;

-- Users can read choirs they're members of
CREATE POLICY choirs_select_member ON choirs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM choir_members
      WHERE choir_id = id AND user_id = auth.uid()
    )
  );

-- Users can create choirs (they become owner)
CREATE POLICY choirs_insert_own ON choirs
  FOR INSERT WITH CHECK (owner_id = auth.uid());

-- Only owner can update choir
CREATE POLICY choirs_update_owner ON choirs
  FOR UPDATE USING (owner_id = auth.uid());

-- Only owner can delete choir
CREATE POLICY choirs_delete_owner ON choirs
  FOR DELETE USING (owner_id = auth.uid());
```

**Choir members table:**
```sql
ALTER TABLE choir_members ENABLE ROW LEVEL SECURITY;

-- Users can read members of choirs they belong to
CREATE POLICY choir_members_select ON choir_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM choir_members cm
      WHERE cm.choir_id = choir_id AND cm.user_id = auth.uid()
    )
  );

-- Only choir owner can add members
CREATE POLICY choir_members_insert ON choir_members
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM choirs
      WHERE id = choir_id AND owner_id = auth.uid()
    )
  );

-- Only choir owner can remove members
CREATE POLICY choir_members_delete ON choir_members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM choirs
      WHERE id = choir_id AND owner_id = auth.uid()
    )
  );
```

**Concerts, Songs, Tracks tables:**
```sql
-- Similar RLS policies: users can read/write if they're choir members
-- (Policies check membership via choir_members join)
```

**Marker Sets and Markers:**
```sql
ALTER TABLE marker_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE markers ENABLE ROW LEVEL SECURITY;

-- Users can read shared marker sets if they're choir members
-- Users can read/write their own private marker sets
CREATE POLICY marker_sets_select ON marker_sets
  FOR SELECT USING (
    is_shared = true AND EXISTS (
      -- Check if user is member of choir that owns the track
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    )
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

-- Choir members can create shared marker sets for their choir's tracks
-- Users can create private marker sets for any track they can access
CREATE POLICY marker_sets_insert ON marker_sets
  FOR INSERT WITH CHECK (
    (is_shared = true AND EXISTS (
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    ))
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

-- Choir members can update shared marker sets
-- Users can only update their own private marker sets
CREATE POLICY marker_sets_update ON marker_sets
  FOR UPDATE USING (
    (is_shared = true AND EXISTS (
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    ))
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

-- Only creators can delete their own marker sets
CREATE POLICY marker_sets_delete ON marker_sets
  FOR DELETE USING (created_by_user_id = auth.uid());

-- Markers inherit access from their marker set
CREATE POLICY markers_select ON markers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id
      AND (
        ms.is_shared = true AND EXISTS (
          SELECT 1 FROM tracks t
          JOIN songs s ON t.song_id = s.id
          JOIN concerts c ON s.concert_id = c.id
          JOIN choir_members cm ON c.choir_id = cm.choir_id
          WHERE t.id = ms.track_id AND cm.user_id = auth.uid()
        )
        OR (ms.is_shared = false AND ms.created_by_user_id = auth.uid())
      )
    )
  );

CREATE POLICY markers_insert ON markers
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id
      AND (
        (ms.is_shared = true AND EXISTS (
          SELECT 1 FROM tracks t
          JOIN songs s ON t.song_id = s.id
          JOIN concerts c ON s.concert_id = c.id
          JOIN choir_members cm ON c.choir_id = cm.choir_id
          WHERE t.id = ms.track_id AND cm.user_id = auth.uid()
        ))
        OR (ms.is_shared = false AND ms.created_by_user_id = auth.uid())
      )
    )
  );

CREATE POLICY markers_update ON markers
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id
      AND (
        (ms.is_shared = true AND EXISTS (
          SELECT 1 FROM tracks t
          JOIN songs s ON t.song_id = s.id
          JOIN concerts c ON s.concert_id = c.id
          JOIN choir_members cm ON c.choir_id = cm.choir_id
          WHERE t.id = ms.track_id AND cm.user_id = auth.uid()
        ))
        OR (ms.is_shared = false AND ms.created_by_user_id = auth.uid())
      )
    )
  );

CREATE POLICY markers_delete ON markers
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id AND ms.created_by_user_id = auth.uid()
    )
  );
```

**Playback States:**
```sql
ALTER TABLE playback_states ENABLE ROW LEVEL SECURITY;

-- Users can only access their own playback states
CREATE POLICY playback_states_own ON playback_states
  FOR ALL USING (user_id = auth.uid());
```

### Data Integrity Constraints

- Foreign keys enforce referential integrity
- CASCADE deletes handle cleanup (e.g., deleting choir removes members, concerts, songs)
- Primary keys prevent duplicates
- NOT NULL constraints on required fields
- Unique constraints on email addresses

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

## Internationalization (i18n)

### Localization Approach
- **Flutter intl package**: Use Flutter's official internationalization support
- **ARB files**: Application Resource Bundle format for translations
- **Generated code**: Type-safe access to translated strings

### File Structure
```
lib/
├── l10n/
│   ├── app_en.arb     # English translations (base)
│   ├── app_da.arb     # Danish translations
│   └── l10n.dart      # Generated localization class
```

### ARB File Format
Example `app_en.arb`:
```json
{
  "@@locale": "en",
  "appTitle": "Repertoire Coach",
  "choirLabel": "Choir",
  "concertLabel": "Concert",
  "songLabel": "Song",
  "playButton": "Play",
  "pauseButton": "Pause",
  "settingsLabel": "Settings",
  "languageLabel": "Language",
  "errorNetworkUnavailable": "Network unavailable. Please check your connection.",
  "validationRequiredField": "This field is required",
  "validationEmailInvalid": "Please enter a valid email address"
}
```

### Language Detection & Storage
1. **First Launch**: Detect device locale using `Platform.localeName`
2. **Fallback**: Default to English if device locale not supported
3. **User Preference**: Store selected language in `users.language_preference` column
4. **Sync**: Language preference syncs across user's devices via Supabase
5. **App Startup**: Load language preference from user profile, apply immediately

### Implementation
```dart
// MaterialApp configuration
MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en', ''),  // English
    Locale('da', ''),  // Danish
  ],
  locale: userLanguagePreference,  // From user profile
  // ...
)
```

### What Gets Translated
- **UI Elements**: All buttons, labels, menu items, tab titles
- **Validation Messages**: Form validation errors
- **Error Messages**: Network errors, auth errors, storage errors
- **System Prompts**: Confirmation dialogs, notifications
- **Date/Time Formatting**: Locale-specific formatting

### What Stays Untranslated
- **User Content**: Choir names, concert names, song titles
- **Marker Labels**: User-created marker labels
- **User Names**: Display names, email addresses

## File Storage Strategy

### Local Storage
- **SQLite**: Cache choir, concert, song, and track metadata for offline access
- **File System**: Cache audio files for offline playback
- **Shared Preferences**: User settings, last accessed concert ID, playback preferences, etc.

### Cloud Storage
- **Supabase Storage** structure:
  ```
  audio_files/
    {choirId}/
      {concertId}/
        {songId}/
          {trackId}.mp3
  ```

- **Storage Policies** (RLS for file access):
  - Only choir members can upload/download audio files for their choir's songs
  - Files organized by choir ID for access control

### Sync Strategy
1. Choir member imports audio file for a track
2. File saved to local storage temporarily
3. Upload to Supabase Storage in background (choir-scoped path)
4. Save track metadata (including storage URL) to PostgreSQL
5. Delete local temp file, keep cached version
6. Other choir members: download on-demand or pre-cache
7. Per-user data (sections, playback positions) syncs via PostgreSQL real-time
8. Real-time subscriptions notify clients of data changes

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
- Batch PostgreSQL operations using transactions
- Implement offline queue for pending operations
- Compress audio uploads if needed
- Show upload/download progress
- Use Supabase real-time sparingly (only for critical updates)

## Security Considerations

### Authentication
- Supabase Auth with email/password
- Optional: Google Sign-In, Apple Sign-In, magic links
- JWT-based authentication
- Secure token management (handled by Supabase)

### Data Privacy
- Private marker sets and playback states are user-specific (enforced by RLS)
- Shared marker sets visible and editable by all choir members (enforced by RLS)
- Choir content shared only among members (enforced by RLS)
- Row Level Security policies enforce data isolation
- Audio files accessible only to choir members (Storage policies)

### Storage Security
- Supabase Storage policies for access control
- Signed URLs for audio file access
- No public access to uploaded files
- Choir-based access enforced at storage level

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
- Supabase integration (database and storage)
- Real-time subscription handling
- Audio playback scenarios

### Platform-Specific Tests
- Android Auto functionality
- iOS audio session handling

## Development Phases

### Phase 1: Core Functionality
- Basic Flutter app setup
- Internationalization setup (Flutter intl, ARB files for English and Danish)
- Choir management UI (create, view, manage members)
- Concert management UI (within choirs, sorted by date)
- Song library UI (within concerts)
- Audio file import
- Local playback (without cloud)
- Playback position saving
- Language preference in settings

### Phase 2: Cloud Integration
- Supabase project setup
- PostgreSQL database schema creation
- Row Level Security policies implementation
- User authentication (Supabase Auth)
- Cloud storage for audio (choir-scoped, Supabase Storage)
- Storage policies for choir-based access
- Real-time subscriptions for data sync
- Choir membership sync
- Concert and song sync across choir members

### Phase 3: Advanced Playback
- Marker set creation and management
- Shared vs private marker sets
- Marker creation during playback
- Marker-based looping
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
- Deploy: Vercel, Netlify, Supabase hosting, or any static host
- PWA support for offline capability

### CI/CD
- GitHub Actions or GitLab CI
- Automated testing
- Build artifacts for each platform

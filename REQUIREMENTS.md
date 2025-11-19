# Choir Practice App - Requirements

## Overview
A mobile and desktop application for practicing choir singing, allowing users to manage songs with multiple voice parts and practice specific sections.

## Platform Requirements

### Primary Targets
- **Android**: Primary platform with Android Auto support for in-car practice
- **iOS**: Secondary platform (bonus)
- **Windows Desktop**: Browser-based or web application

### Technology Stack
- **Flutter**: Cross-platform development for Android, iOS, and Web
- **Native Android**: Platform-specific code for Android Auto integration

## Core Features

### 1. Concert/Category Management
- **Concerts**: Users organize songs into concerts (categories)
- **Concert Properties**: Each concert has a simple title/name
- **Custom Sort Order**: Users can reorder concerts in custom order
- **Many-to-Many Relationship**: Songs can belong to multiple concerts
- **Required Assignment**: Each song must belong to at least one concert
- **Default View**: App opens to the most recently accessed concert
- **Last Accessed Tracking**: System tracks when each concert was last opened/viewed

### 2. Song Library Management
- Users can add songs to their personal library
- Each song can have multiple audio tracks representing different voice parts
- Support for standard choir voice parts: Soprano, Alto, Tenor, Bass
- Support for additional tracks: Full Choir, Piano Accompaniment, etc.
- **Cross-Concert Metadata**: User's section markers and metadata follow the song across all concerts it belongs to

### 3. Audio File Management
- **Import Method**: Users import audio files from their device
- **Supported Formats**: MP3, M4A
- **Cloud Storage**: Audio files sync to cloud storage for access across all devices
- **File Organization**: Files organized by song and track type

### 4. Playback Features
- Select a song from library
- Choose which track/voice part to play
- Standard playback controls (play, pause, seek)
- **Quick Rewind**: Button to go back 10 seconds instantly
- Display current playback position and total duration

### 5. Section Marking & Practice
- **Mark Sections During Playback**: Users can mark start and end points of sections while listening
- **Save Sections**: Marked sections are saved with the song for future reference
- **Section Looping**: Ability to loop/repeat saved sections continuously
- **Per-User Sections**: Section markers are user-specific (different users can mark different sections)

### 6. Data Synchronization
- **Audio Files**: Stored in cloud, accessible across all user devices
- **Song Metadata**: Song names, track information synced to cloud
- **Concert Data**: Concert names, sort order, song assignments synced to cloud
- **Section Markers**: User-specific, synced to cloud across user's devices (follow the song regardless of concert)
- **User Authentication**: Required for syncing data across devices

### 7. Android Auto Integration
- Display concerts and song library in Android Auto interface
- Browse songs by concert
- Show currently playing track and voice part
- Playback controls accessible from car display
- Follow Android Auto safety guidelines for in-car use

## User Workflows

### Creating a Concert
1. User creates a new concert (enters concert name)
2. Concert appears in their concert list
3. User can reorder concerts by dragging or using sort controls
4. Concert syncs to all user's devices

### Adding a Song
1. User selects a concert (or creates a new one)
2. User creates a new song entry (enters song name)
3. User assigns song to one or more concerts
4. User adds audio tracks for different voice parts
5. User imports audio files from device for each track
6. Files upload to cloud storage
7. Song appears in assigned concerts on all user's devices

### Practicing a Song
1. App opens to most recently accessed concert
2. User selects a song from the concert
3. User selects which voice part to practice (e.g., Tenor)
4. User plays the track
5. User can:
   - Use quick rewind to replay difficult parts
   - Mark section start/end points during playback
   - Save sections for later practice (sections follow the song to all concerts)
   - Loop specific sections repeatedly

### Using Saved Sections
1. User opens a song they've practiced before (from any concert)
2. User sees list of saved sections (e.g., "Bridge - measures 32-40")
3. Sections are the same regardless of which concert the song is accessed from
4. User selects a section to practice
5. App loops that section until user stops

### Managing Concerts
1. User can view all concerts in custom sort order
2. User can reorder concerts
3. User can rename concerts
4. User can view all songs in a concert
5. User can add existing songs to additional concerts
6. User can remove songs from concerts (if song belongs to multiple concerts)
7. System tracks last accessed time when user opens a concert

## Technical Requirements

### Performance
- Smooth audio playback without stuttering
- Quick response to rewind/skip commands
- Efficient handling of large audio files

### Storage
- Local caching of frequently used songs
- Efficient cloud storage usage
- Background sync when connected to Wi-Fi

### Offline Support
- Access to previously downloaded songs when offline
- Queue uploads/sync operations for when connection available

### Security
- Secure user authentication
- Private user data (section markers, playlists)
- Secure cloud storage for audio files

## Future Considerations (Not in Initial Version)
- Sharing songs between users
- Playlist creation
- Practice session tracking/statistics
- Adjustable playback speed
- Pitch adjustment
- Multiple language support
- Export practice logs

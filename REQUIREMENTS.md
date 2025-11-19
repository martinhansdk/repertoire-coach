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

### 1. Song Library Management
- Users can add songs to their personal library
- Each song can have multiple audio tracks representing different voice parts
- Support for standard choir voice parts: Soprano, Alto, Tenor, Bass
- Support for additional tracks: Full Choir, Piano Accompaniment, etc.

### 2. Audio File Management
- **Import Method**: Users import audio files from their device
- **Supported Formats**: MP3, M4A
- **Cloud Storage**: Audio files sync to cloud storage for access across all devices
- **File Organization**: Files organized by song and track type

### 3. Playback Features
- Select a song from library
- Choose which track/voice part to play
- Standard playback controls (play, pause, seek)
- **Quick Rewind**: Button to go back 10 seconds instantly
- Display current playback position and total duration

### 4. Section Marking & Practice
- **Mark Sections During Playback**: Users can mark start and end points of sections while listening
- **Save Sections**: Marked sections are saved with the song for future reference
- **Section Looping**: Ability to loop/repeat saved sections continuously
- **Per-User Sections**: Section markers are user-specific (different users can mark different sections)

### 5. Data Synchronization
- **Audio Files**: Stored in cloud, accessible across all user devices
- **Song Metadata**: Song names, track information synced to cloud
- **Section Markers**: User-specific, synced to cloud across user's devices
- **User Authentication**: Required for syncing data across devices

### 6. Android Auto Integration
- Display song library in Android Auto interface
- Show currently playing track and voice part
- Playback controls accessible from car display
- Follow Android Auto safety guidelines for in-car use

## User Workflows

### Adding a Song
1. User creates a new song entry (enters song name)
2. User adds audio tracks for different voice parts
3. User imports audio files from device for each track
4. Files upload to cloud storage
5. Song appears in library on all user's devices

### Practicing a Song
1. User selects a song from library
2. User selects which voice part to practice (e.g., Tenor)
3. User plays the track
4. User can:
   - Use quick rewind to replay difficult parts
   - Mark section start/end points during playback
   - Save sections for later practice
   - Loop specific sections repeatedly

### Using Saved Sections
1. User opens a song they've practiced before
2. User sees list of saved sections (e.g., "Bridge - measures 32-40")
3. User selects a section to practice
4. App loops that section until user stops

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

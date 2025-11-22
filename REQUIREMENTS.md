# Repertoire Coach - Requirements

## Overview
A collaborative mobile and desktop application for practicing choir singing. Users organize into choirs, share concerts and songs with multiple voice parts, and maintain personal practice metadata including section markers and playback positions.

## Platform Requirements

### Primary Targets
- **Android**: Primary platform with Android Auto support for in-car practice
- **iOS**: Secondary platform (bonus)
- **Windows Desktop**: Browser-based or web application

### Technology Stack
- **Flutter**: Cross-platform development for Android, iOS, and Web
- **Native Android**: Platform-specific code for Android Auto integration

## Core Features

### 1. Choir Management (User Groups)
- **Choirs**: Groups of users who share concerts and songs
- **Choir Creation**: Any user can create a choir and becomes its owner
- **Membership Management**: Choir owner can add/remove members
- **Multi-Choir Membership**: Users can be members of multiple choirs
- **Shared Content**: All choir members see the same concerts and songs

### 2. Concert Management
- **Concerts**: Belong to a specific choir, visible to all choir members
- **Concert Properties**: Each concert has a title/name and date
- **Concert Date**: Required field for automatic sorting
- **Automatic Sorting**: Concerts displayed by date:
  - Upcoming concerts first (soonest to farthest)
  - Past concerts after (most recent to oldest)
- **Concert Visibility**: Users see all concerts from all their choirs
- **Collaborative Management**: Any choir member can add/edit/delete concerts
- **Per-User Tracking**: System tracks most recently accessed concert per user

### 3. Song Library Management
- **Shared Songs**: Songs belong to concerts and are shared among all choir members
- **Multiple Tracks**: Each song can have multiple audio tracks for different voice parts
- **Voice Parts**: Support for Soprano, Alto, Tenor, Bass, Full Choir, Piano Accompaniment, etc.
- **Collaborative Management**: Any choir member can add/edit songs and upload tracks
- **Per-User Metadata**: Each user maintains private section markers that follow the song across all contexts

### 4. Audio File Management
- **Import Method**: Choir members import audio files from their device
- **Supported Formats**: MP3, M4A
- **Shared Storage**: Audio files uploaded to cloud storage, accessible to all choir members
- **File Organization**: Files organized by choir, concert, song, and track type

### 5. Playback Features
- Select a song from library
- Choose which track/voice part to play
- Standard playback controls (play, pause, seek)
- **Quick Rewind**: Button to go back 10 seconds instantly
- Display current playback position and total duration
- **Resume Playback**: System saves playback position per user per song for resuming later

### 6. Marker Sets & Practice
- **Marker Sets**: Named collections of position markers for a track (e.g., "Musical Structure", "Bar Numbers", "Lyrics")
- **Shared Marker Sets**: Visible to all choir members, any member can create/edit
  - Examples: "intro", "verse 1", "chorus", "outro" or bar numbers "1", "25", "48"
- **Private Marker Sets**: Per-user marker sets for personal practice notes
  - Examples: "hard part in outro", "sections to review"
- **Mark Positions During Playback**: Users can mark positions while listening and add labels
- **Create Marker Sets**: Users can organize markers into named sets
- **Section Looping**: Select any marker range from any set to loop/repeat continuously
- **Collaborative Editing**: Any choir member can improve/correct shared marker sets

### 7. Data Synchronization
- **Choirs**: Choir data, membership synced to cloud
- **Concerts**: Concert names, dates, song assignments synced to cloud (shared within choir)
- **Songs**: Song metadata, track information synced to cloud (shared within choir)
- **Audio Files**: Stored in cloud, accessible to all choir members
- **Shared Marker Sets**: Marker sets and markers synced to cloud (shared within choir, editable by any member)
- **Per-User Data**: Private marker sets, playback positions, most recently accessed concert synced per user
- **User Authentication**: Required for syncing data across devices

### 8. Android Auto Integration
- Display concerts and song library in Android Auto interface
- Browse songs by concert
- Show currently playing track and voice part
- Playback controls accessible from car display
- Follow Android Auto safety guidelines for in-car use

## User Workflows

### Creating a Choir
1. User creates a new choir (enters choir name)
2. User becomes the choir owner
3. User can invite/add other members by email or user ID
4. Choir syncs to all members' devices

### Managing Choir Membership (Owner Only)
1. Choir owner views member list
2. Owner can add new members
3. Owner can remove members
4. Changes sync to all devices

### Creating a Concert
1. User selects a choir
2. User creates a new concert (enters concert name and date)
3. Concert appears in all choir members' concert lists
4. Concerts automatically sorted by date (upcoming first, then past)
5. Concert syncs to all choir members' devices

### Adding a Song
1. User selects a choir and concert
2. User creates a new song entry (enters song name)
3. User adds audio tracks for different voice parts
4. User imports audio files from device for each track
5. Files upload to cloud storage
6. Song appears in the concert for all choir members

### Practicing a Song
1. App opens to user's most recently accessed concert
2. User selects a song from the concert
3. User selects which voice part to practice (e.g., Tenor)
4. Audio resumes from user's last saved playback position (if any)
5. User plays the track
6. User can:
   - Use quick rewind to replay difficult parts
   - View available marker sets (both shared and private)
   - Create new markers during playback with labels
   - Organize markers into named sets (shared or private)
   - Select marker ranges from any set to loop repeatedly
   - Edit/improve existing shared marker sets
7. Playback position automatically saved for next session

### Using Marker Sets for Practice
1. User opens a song they've practiced before (or any choir song)
2. User sees available marker sets:
   - Shared sets created by choir members (e.g., "Musical Structure", "Bar Numbers")
   - Their own private sets (e.g., "My Practice Sections")
3. User selects a marker set to view (e.g., "Musical Structure")
4. User sees markers within that set (e.g., "intro", "verse 1", "chorus")
5. User selects a range between markers to practice (e.g., from "verse 1" to "chorus")
6. App loops that range until user stops
7. User can switch between different marker sets to navigate the track in different ways

### Browsing Concerts
1. User views all concerts from all their choirs
2. Concerts automatically sorted by date (upcoming first, then past)
3. User can see which choir each concert belongs to
4. User can filter/search concerts
5. System remembers and opens to most recently accessed concert

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
- Private user data (section markers, playback positions)
- Choir-based access control (only members can access choir content)
- Choir owner permissions for member management
- Secure cloud storage for audio files

## Future Considerations (Not in Initial Version)
- Hide/show specific concerts from personal view
- Multiple language support
- Choir owner transfer
- Bulk member management

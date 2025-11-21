# Repertoire Coach

A cross-platform mobile and desktop application designed to help choir members practice their vocal parts. Import songs with multiple voice tracks (Soprano, Alto, Tenor, Bass, etc.), mark tricky sections, and practice on-the-go with Android Auto support.

## Features

- **Multi-Track Song Library**: Organize songs with separate audio tracks for each voice part
- **Smart Practice Tools**:
  - Quick 10-second rewind button
  - Mark and save difficult sections while listening
  - Loop sections repeatedly for focused practice
- **Cloud Sync**: Access your songs and practice markers on all your devices
- **Android Auto Support**: Practice safely while commuting with in-car controls
- **Cross-Platform**: Works on Android, iOS, and Windows desktop (web-based)

## Technology Stack

- **Flutter**: Cross-platform app development
- **Firebase**: Backend services (Authentication, Firestore, Storage)
- **Native Android**: For Android Auto integration
- **just_audio**: High-quality audio playback

## Project Structure

```
choir-app/
├── REQUIREMENTS.md      # Detailed feature requirements
├── ARCHITECTURE.md      # Technical architecture and design decisions
├── TODO.md             # Development task list
├── lib/                # Flutter source code (to be created)
├── android/            # Android-specific code (to be created)
├── ios/                # iOS-specific code (to be created)
└── web/                # Web-specific code (to be created)
```

## Development Phases

1. **Phase 1**: Core local functionality (song library, audio playback)
2. **Phase 2**: Cloud integration and sync
3. **Phase 3**: Advanced playback features (section marking and looping)
4. **Phase 4**: Multi-platform optimization (iOS, Web)
5. **Phase 5**: Android Auto integration

## Getting Started

### Prerequisites

- Docker (for building)
- Android device with USB debugging enabled (for Android testing)
- Git

### Building the App

See [DOCKER.md](DOCKER.md) for detailed Docker setup and build instructions.

**Quick start:**

```bash
# Build Docker image (only needed once)
docker build -f Dockerfile.build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) -t repertoire-coach-builder .

# Build Android APK
sg docker -c "docker run --rm -v $(pwd):/app repertoire-coach-builder flutter build apk --debug"

# Build Web version
sg docker -c "docker run --rm -v $(pwd):/app repertoire-coach-builder flutter build web"
```

### Running the App

**Android:**
```bash
# Install on connected Android device
adb install build/app/outputs/flutter-apk/app-debug.apk

# Or copy build/app/outputs/flutter-apk/app-debug.apk to your phone and install manually
```

**Web (Desktop):**
```bash
# Serve the web build locally
cd build/web
python3 -m http.server 8000
# Open http://localhost:8000 in your browser
```

## Documentation

- [Requirements](REQUIREMENTS.md) - Complete feature requirements and user workflows
- [Architecture](ARCHITECTURE.md) - Technical design, data models, and implementation details
- [TODO](TODO.md) - Development tasks and progress tracking

## Contributing

This is currently a personal project. Contribution guidelines may be added in the future.

## License

(To be determined)

## Contact

(To be added)

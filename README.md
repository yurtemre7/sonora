# Sonora

Sonora is a local music player for Android built with Flutter, featuring a dark mode Material 3 Expressive design with a deep violet/purple theme. It focuses on privacy, zero file duplication, directory-based file sync, and background playback.

> [!NOTE]
> **AI Disclaimer:** This project is built entirely with AI assistance (using Google's Antigravity agentic coding framework). All code, architectures, and features were designed, implemented, and refined through AI-human pair programming.

## Features

- **Material 3 Expressive Design**: Dark mode interface using Outfit and Inter typography, circular vinyl play controls, blurred background art, and custom sliders.
- **Directory Sync Syncing**: Play music files directly from a designated device directory without copying them to internal app folders.
- **Automatic Resume Scanning**: Scans and syncs folder changes silently in the background when the app returns from background state.
- **Instant Launch Optimization**: Startup queries cached data in milliseconds for an instant interactive interface, lazy-loading directory alterations and duration extractions asynchronously.
- **Opus & Wide Audio Format Support**: Plays `.opus`, `.mp3`, `.m4a`, `.wav`, `.ogg`, `.flac`, `.aac`, `.amr`, `.midi`, and other standard formats natively.
- **Custom Playlists**: Create, reorder (via drag-and-drop), and manage custom playlists.
- **Show in Folder**: Directly open the phone's native file explorer to the directory containing a song.
- **Media Controls Notification**: Foreground service integration for media controls (play, pause, skip, seek) directly in the Android notifications drawer.
- **Mute Override**: Built-in volume manager that checks media volume and raises it slightly to ensure audio plays even if the device was muted.

## Architecture

Sonora is structured around clean, decoupled components:

```
lib/
├── models/
│   ├── song.dart       - Song metadata container
│   └── playlist.dart   - Playlist tracking model
├── providers/
│   └── player_provider.dart - State notifier for playback controls
├── screens/
│   ├── home_screen.dart             - Main tab layout (Songs / Playlists)
│   ├── now_playing_screen.dart      - Fullscreen player & seekbar
│   ├── playlist_detail_screen.dart  - Reorderable playlist tracks view
│   ├── queue_screen.dart            - Drag-and-drop queue screen
│   └── settings_screen.dart         - Sync directory & clear settings
├── services/
│   ├── audio_handler.dart       - Custom AudioService background controller
│   ├── music_scanner.dart       - File system scanner & playlist database
│   ├── permission_service.dart  - Dynamic storage & notification requester
│   └── volume_service.dart      - Native platform channel for volume & folder viewing
├── theme/
│   └── app_theme.dart  - Material 3 theme colors & font styles
└── app.dart            - App router & observer orchestrator
```

## Running the Project

Ensure you have Flutter SDK set up on your machine:

1. Clone or navigate to the project directory:
   ```bash
   cd kind-salk
   ```
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Run static analysis to verify codebase health:
   ```bash
   flutter analyze
   ```
4. Build the debug APK:
   ```bash
   flutter build apk --debug
   ```
5. Deploy to a connected Android device or emulator:
   ```bash
   flutter run
   ```

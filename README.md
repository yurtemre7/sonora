# Sonora

Sonora is a local music player built with Flutter, featuring a Material 3 Expressive design with dynamic album-art themes. It focuses on privacy, zero file duplication, directory-based library sync, and background playback. Android is the primary target; Windows builds are also supported.

**Current version:** 1.6.0

> [!NOTE]
> **AI Disclaimer:** This project is built entirely with AI assistance (using Google's Antigravity agentic coding framework). All code, architectures, and features were designed, implemented, and refined through AI-human pair programming.

## Features

### Library & Sync

- **Directory-Based Sync**: Play music directly from a designated folder without copying files into app storage.
- **Incremental Sync**: Skips unchanged files using size and modification timestamps; scanning runs in background isolates.
- **Instant Launch**: Loads cached library data in milliseconds, then refreshes metadata and durations asynchronously.
- **Wide Format Support**: Plays `.mp3`, `.m4a`, `.mp4`, `.aac`, `.flac`, `.ogg`, `.opus`, `.wav`, `.wma`, `.amr`, `.3gp`, `.ts`, `.mkv`, `.mid`, `.midi`, and other standard formats.
- **ID3 Metadata & Artwork**: Parses tags in background isolates and caches album art to disk.
- **Lyrics Detection**: Detects sidecar `.lrc` and `.txt` lyrics files during sync.
- **Manual & Automatic Resync**: Pull-to-refresh on all library tabs, a Sync Now button in settings, and a monthly sync reminder banner (snoozeable for 30 days).
- **Sync Details Panel**: Shows library size, detected audio formats, unique theme count, and lyrics-synced song count in settings.
- **Onboarding**: Four-step first-run flow covering welcome, sync intro, permissions, and folder selection.

### Library Browsing

- **Four Tabs**: Songs, Albums (grid), Artists, and Playlists with a collapsible app bar.
- **Search**: Per-tab filtering with live result counts.
- **Sort Options**: Per-tab sorting with ascending/descending toggle; options include title, artist, duration, recently added, track count, and more. Preferences persist across restarts.
- **Album & Artist Detail Screens**: Blurred artwork backgrounds, play-all and shuffle-all actions, hero transitions, and an artist album carousel.
- **Playlist Detail**: Reorderable tracks, play/shuffle, swipe-to-remove, and delete with confirmation (except Favorites).
- **Quick Shuffle**: One-tap shuffle from home tab headers and detail screens.
- **Custom Playlists**: Create, rename context, reorder via drag-and-drop, and delete with confirmation.
- **Favorites**: Built-in Favorites playlist with toggle from song menus, Now Playing heart button (animated), and playlist detail.
- **Song Context Menu**: Play next, add to queue, add to playlist, remove from playlist, song info, and favorite/unfavorite.
- **Song Info Sheet**: Title, artist, album, duration, file path, format, bitrate, sample rate, file size, and dates.
- **Active Track Highlighting**: Currently playing song is visually marked in library lists.

### Playback

- **Full Transport Controls**: Play/pause, next/previous, seek bar with elapsed/remaining time, shuffle, and repeat (off → all → one).
- **Queue Management**: Up Next tab in Now Playing with drag-to-reorder, swipe-to-remove, and tap-to-jump.
- **Play Next & Add to Queue**: Insert or append tracks from any song menu.
- **Quick Shuffle**: Shuffles a list, picks a random start track, and enables shuffle mode.
- **Volume Slider**: In-app volume control in Now Playing with persisted preference.
- **Sleep Timer**: Presets (5–120 min), custom duration, cancel, +1 min extend via notification action, and volume fade-out in the last 10 seconds. Default duration configurable in settings.
- **Related Tracks**: Now Playing Related tab with "From this album" and "More by artist" sections.
- **Keep Playing on Close**: Optional setting to continue playback when the app is swiped away from recents.

### Now Playing & UI

- **Material 3 Expressive Design**: Outfit and Inter typography, circular controls, blurred background art, and custom sliders.
- **Global Mini Player**: Persistent bottom bar with live progress strip; tap to expand, swipe up/down to open/stop, swipe left/right to skip.
- **Now Playing Sheet**: Full-screen modal with blurred artwork background, player controls, and tabbed content (Lyrics / Up Next / Related).
- **Immersive Mode**: Tap album art to expand to full width; preference persists across sessions.
- **Dynamic Themes (Material You)**: Extracts accent colors from album art with background pre-computation; toggle in settings. Unique theme count shown in sync details with live extraction indicator.
- **Theme Modes**: System, light, and dark with persisted preference.
- **Lyrics**: Synchronized `.lrc` with auto-scroll, active-line highlight, and tap-to-seek; plain `.txt` as scrollable text. Toggleable overlay on artwork or full tab view.
- **Audio Visualizer**: Optional animated wave bars at the bottom of Now Playing.
- **Ambient Glow**: Pulsing radial glow behind artwork while playing.
- **Marquee Text**: Scrolling title, artist, and album labels when text overflows.
- **Swipe Gestures**: Horizontal swipe on artwork for next/previous track.
- **Artist & Album Sheets**: Quick-nav bottom sheets from Now Playing without leaving the player.

### Statistics

- **Listening Statistics Screen**: Five-page swipeable dashboard accessible from settings.
- **Overview**: Total listening time, complete listens, albums/artists/playlists played, first song played, most played song, unique songs, and most active day.
- **Top Charts**: Top 5 songs, albums, artists, and playlists with tap-to-navigate or play.
- **Reset Statistics**: Clear all listening data with confirmation.

### Android Integration

- **Background Playback**: Foreground service with media controls (play, pause, skip, seek) in the notification drawer and on the lock screen.
- **Mute Override**: Raises media volume slightly when muted so playback is never silent.
- **Permissions**: Guided audio, storage (legacy Android), and notification permission flow.

### Settings & About

- **Sync Folder Management**: View and change sync directory, last sync time, and sync duration.
- **Playback Preferences**: Keep playing on close, dynamic theme, audio visualizer, and default sleep timer.
- **About Dialog**: App icon, version, and description.
- **Open Source Licenses**: Built-in Flutter licenses page.
- **Reset Application**: Clears all preferences, library cache, and settings; returns to onboarding.

## Architecture

Sonora is structured around clean, decoupled components with `go_router` for internal navigation:

```
lib/
├── models/
│   ├── song.dart           - Song metadata container
│   ├── playlist.dart       - Playlist model
│   └── grouping.dart       - Album/artist grouping helpers
├── providers/
│   ├── player_provider.dart - Playback, queue, library, and theme color state
│   └── theme_provider.dart  - Theme mode preference
├── routing/
│   ├── app_router.dart     - GoRouter configuration and shell routes
│   ├── app_routes.dart     - Route path constants
│   └── app_navigation.dart - Typed navigation helpers
├── screens/
│   ├── home_screen.dart             - Main tab layout (Songs / Albums / Artists / Playlists)
│   ├── now_playing_screen.dart      - Fullscreen player with lyrics, queue, and related tabs
│   ├── album_detail_screen.dart     - Album track listing
│   ├── artist_detail_screen.dart    - Artist discography
│   ├── playlist_detail_screen.dart  - Reorderable playlist tracks
│   ├── settings_screen.dart         - Sync folder, theme, playback, and app settings
│   ├── stats_screen.dart            - Listening statistics and top charts
│   └── onboarding_screen.dart       - First-run setup flow
├── services/
│   ├── audio_handler.dart    - AudioService background controller
│   ├── music_scanner.dart    - Filesystem scanner and library cache
│   ├── lyrics_service.dart   - LRC/TXT lyrics loading and parsing
│   ├── stats_service.dart    - Play-time and play-count tracking
│   ├── permission_service.dart - Storage and notification permissions
│   └── volume_service.dart   - Native volume management
├── theme/
│   └── app_theme.dart        - Material 3 theme colors and typography
├── utils/
│   ├── color_extractor.dart  - Background album-art color extraction
│   └── logger.dart           - Route and debug logging
├── widgets/                  - Reusable UI (mini player, seek bar, album art, visualizer, etc.)
├── app.dart                  - App bootstrap and lifecycle orchestration
└── main.dart                 - Entry point
```

## Requirements

- [FVM](https://fvm.app/) with Flutter **3.44.6** (pinned in `.fvmrc`)
- Dart SDK **^3.12.2**
- Android SDK **24+** (compile/target SDK 37)
- A connected Android device or emulator for primary development

## Running the Project

1. Clone the repository and enter the project directory:

   ```bash
   git clone https://github.com/yurtemre7/sonora.git
   cd sonora
   ```

2. Install the pinned Flutter version and fetch dependencies:

   ```bash
   fvm install
   fvm flutter pub get
   ```

3. Run static analysis:

   ```bash
   fvm flutter analyze
   ```

4. Deploy to a connected Android device or emulator:

   ```bash
   fvm flutter run
   ```

5. Build a debug APK (optional):

   ```bash
   fvm flutter build apk --debug
   ```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Releases

Release APKs are built automatically via GitHub Actions when a commit to `main` contains `release:` in its message (for example, `release: 1.6.0`). See [CHANGELOG.md](CHANGELOG.md) for version history.

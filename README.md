# Sonora

*🌐 Read this in: [日本語](README_JP.md)*

Sonora is a privacy-first local music player built with Flutter. It features a Material 3 Expressive design with dynamic album-art theming, directory-based library sync, and seamless background playback — all without ever copying or uploading your files. Android is the primary target, with Windows builds also supported.

**Current version:** 1.6.0

> [!NOTE]
> **AI Disclaimer:** This project is built entirely with AI assistance using Google's Antigravity agentic coding framework. All code, architecture decisions, and features were designed, implemented, and refined through AI-human pair programming.

## Screenshots

<p align="center">
  <img src="images/home.png" width="320" alt="Home screen showing the song library" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="images/settings.png" width="320" alt="Settings screen" />
</p>

## Features

### Library & Sync

- **Directory-Based Sync**: Point Sonora at any folder and play your music directly — no files are ever copied into app storage.
- **Incremental Sync**: Unchanged files are skipped using size and modification timestamps, keeping re-scans fast. All scanning runs in background isolates so the UI stays responsive.
- **Instant Launch**: Cached library data is available in milliseconds on startup; metadata and durations refresh asynchronously in the background.
- **Wide Format Support**: Plays `.mp3`, `.m4a`, `.mp4`, `.aac`, `.flac`, `.ogg`, `.opus`, `.wav`, `.wma`, `.amr`, `.3gp`, `.ts`, `.mkv`, `.mid`, `.midi`, and more.
- **ID3 Metadata & Artwork**: Tags are parsed in background isolates and album art is cached to disk for fast loading.
- **Lyrics Detection**: Sidecar `.lrc` and `.txt` lyrics files are automatically detected during sync.
- **Manual & Automatic Resync**: Pull-to-refresh on any library tab, a *Sync Now* button in Settings, and a monthly reminder banner (snoozeable for 30 days).
- **Sync Details Panel**: Displays total library size, detected audio formats, unique dynamic theme count, and the number of lyrics-synced songs.
- **Onboarding**: A four-step first-run flow covering welcome, sync introduction, permissions, and folder selection.

### Library Browsing

- **Four Tabs**: Songs, Albums (grid), Artists, and Playlists — all under a collapsible app bar.
- **Search**: Per-tab live filtering with instant result counts.
- **Sort Options**: Each tab has its own sort order (title, artist, duration, recently added, track count, and more) with an ascending/descending toggle. Preferences survive app restarts.
- **Album & Artist Detail Screens**: Blurred artwork backgrounds, play-all and shuffle-all actions, hero transitions, and an artist album carousel.
- **Playlist Detail**: Drag-to-reorder tracks, play/shuffle actions, swipe-to-remove, and delete with confirmation (protected for Favorites).
- **Quick Shuffle**: One-tap shuffle from any tab header or detail screen.
- **Custom Playlists**: Create, rename, reorder via drag-and-drop, and delete with a confirmation prompt.
- **Favorites**: A built-in Favorites playlist with toggle access from the song context menu and an animated heart button in Now Playing.
- **Song Context Menu**: Play next, add to queue, add to playlist, remove from playlist, view song info, and favorite/unfavorite.
- **Song Info Sheet**: Full metadata at a glance — title, artist, album, duration, file path, format, bitrate, sample rate, file size, and timestamps.
- **Active Track Highlighting**: The currently playing song is visually distinguished in all library lists.

### Playback

- **Full Transport Controls**: Play/pause, next/previous, a seek bar with elapsed and remaining time, shuffle, and repeat (off → all → one).
- **Queue Management**: The *Up Next* tab in Now Playing supports drag-to-reorder, swipe-to-remove, and tap-to-jump.
- **Play Next & Add to Queue**: Insert or append any track from any song menu.
- **Quick Shuffle**: Shuffles the current list, picks a random starting track, and activates shuffle mode in one tap.
- **Volume Slider**: In-app volume control in Now Playing with a persisted preference.
- **Sleep Timer**: Choose from presets (5–120 min) or set a custom duration. Supports cancel, +1 min extension via a notification action, and a gentle volume fade-out in the final 10 seconds. Default duration is configurable in Settings.
- **Related Tracks**: The *Related* tab in Now Playing surfaces *From this album* and *More by this artist* suggestions.
- **Keep Playing on Close**: An optional setting to continue playback when the app is dismissed from the recents screen.

### Now Playing & UI

- **Material 3 Expressive Design**: Outfit and Inter typography, circular controls, blurred background artwork, and custom-styled sliders.
- **Global Mini Player**: A persistent bottom bar with a live progress strip. Tap to expand, swipe up/down to open or stop playback, and swipe left/right to skip tracks.
- **Now Playing Sheet**: A full-screen modal with a blurred artwork background, transport controls, and tabbed content: Lyrics, Up Next, and Related.
- **Immersive Mode**: Tap the album art to expand it to full width. The preference persists across sessions.
- **Dynamic Themes (Material You)**: Accent colors are extracted from album art in the background. The unique theme count is shown in Sync Details with a live extraction indicator. Toggle in Settings.
- **Theme Modes**: System, light, and dark — with your choice persisted.
- **Lyrics**: Synchronized `.lrc` files with auto-scroll, active-line highlight, and tap-to-seek. Plain `.txt` files display as scrollable text. Switch between an overlay on the artwork or a dedicated full tab.
- **Audio Visualizer**: Optional animated wave bars displayed at the bottom of Now Playing.
- **Ambient Glow**: A pulsing radial glow behind the album art while a track is playing.
- **Marquee Text**: Song title, artist, and album labels scroll smoothly when text overflows.
- **Swipe Gestures**: Swipe left or right on the album art to skip tracks.
- **Artist & Album Sheets**: Quick-navigation bottom sheets accessible directly from Now Playing.

### Statistics

- **Listening Dashboard**: A five-page swipeable statistics screen accessible from Settings.
- **Overview**: Total listening time, complete listens, albums/artists/playlists played, first song ever played, most played song, unique song count, and most active listening day.
- **Top Charts**: Your top 5 songs, albums, artists, and playlists — tap any entry to navigate or play.
- **Reset Statistics**: Clear all listening history with a confirmation prompt.

### Android Integration

- **Background Playback**: A foreground service keeps music running with full media controls (play, pause, skip, seek) in the notification drawer and on the lock screen.
- **Mute Override**: Slightly raises media volume when the device is muted so playback is never silently lost.
- **Permission Flow**: A guided setup for audio, storage (legacy Android), and notification permissions.

### Settings

- **Library Sync**: View or change the sync folder, see the last sync time, and check how long the scan took.
- **Playback**: Configure keep-playing-on-close, dynamic themes, the audio visualizer, and the default sleep timer duration.
- **Appearance**: Theme mode, color settings, visualizer style, and local image options.
- **Library Formatting**: Control how song titles are displayed in lists.
- **Privacy & Permissions**: Per-permission explanations and data management options (see below).
- **App Info**: Version, open-source licenses, and a Reset Application option that clears all preferences, library cache, and settings and returns the app to onboarding.

## Privacy & Permissions

Sonora is built with privacy at its core. Here is exactly what each permission is used for:

| Permission | Why it's needed |
|---|---|
| **Storage, Audio & Cover Images** | Scans your selected music folder for audio tracks and local artwork (e.g., `artist.jpg` or `cover.png`). Although Android labels this as "Photos & Media" access, Sonora only ever reads files inside your designated music directory — your personal photo gallery, camera roll, and private images are **never** accessed. |
| **Notifications & Foreground Service** | Displays the media player controls in your notification shade and lock screen. A foreground service is required to keep music playing reliably in the background when the app is not in the foreground. |
| **Wake Lock** | Prevents the device from sleeping mid-playback and cutting off your music. |
| **Internet** | Used solely to fetch the latest release version and changelog from GitHub to notify you of available updates. |

### Your Data is Yours

Sonora operates entirely offline and connects to no external servers, with the single exception of checking GitHub for app updates. All listening statistics, preferences, and playtime data remain strictly on your device and are never transmitted anywhere.

### Deleting Your Data

You have full control. All app settings, statistics, and caches can be wiped instantly at any time from the **Danger Zone** at the bottom of the Info & Support tab in Settings.

## Architecture

Sonora is structured around clean, decoupled components using `go_router` for navigation:

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

- [FVM](https://fvm.app/) with Flutter **3.44.7** (pinned in `.fvmrc`)
- Dart SDK **^3.12.2**
- Android SDK **24+** (compile/target SDK 37)
- A connected Android device or emulator

## Getting Started

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yurtemre7/sonora.git
   cd sonora
   ```

2. **Install the pinned Flutter version and fetch dependencies:**

   ```bash
   fvm install
   fvm flutter pub get
   ```

3. **Run static analysis:**

   ```bash
   fvm flutter analyze
   ```

4. **Run on a connected device or emulator:**

   ```bash
   fvm flutter run
   ```

5. **Build a debug APK** *(optional)*:

   ```bash
   fvm flutter build apk --debug
   ```

## Releases

Release APKs are built automatically via GitHub Actions whenever a commit to `main` includes `release:` in its message (e.g., `release: 1.6.0`). See [CHANGELOG.md](CHANGELOG.md) for the full version history.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

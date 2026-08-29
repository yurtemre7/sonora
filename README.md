# Sonora

*🌐 Read this in: [日本語](README_JP.md)*

Sonora is a privacy-first local music player built with Flutter. It features a Material 3 Expressive design with dynamic album-art and Material You wallpaper theming, directory-based library sync, multi-band equalizer & sound effects (MFX), multi-select batch actions, and seamless background playback — all without ever copying or uploading your files. Android is the primary target, with Windows builds also supported.

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

### Library Browsing & Multi-Select

- **Four Tabs**: Songs, Albums (grid), Artists, and Playlists — all under a collapsible app bar.
- **Multi-Select Batch Actions**: Long-press any song to enter multi-select mode: bulk add to playlist, play next, queue, toggle favorite, or share via native system sheet.
- **Search**: Per-tab live filtering with instant result counts and fast substring matching.
- **Sort Options**: Each tab has its own sort order (title, artist, duration, recently added, track count, and more) with an ascending/descending toggle. Preferences survive app restarts.
- **Album & Artist Detail Screens**: Blurred artwork backgrounds, play-all and shuffle-all actions, hero transitions, and an artist album carousel.
- **Playlist Management**: Drag-to-reorder tracks, play/shuffle actions, swipe-to-remove, M3U playlist import/export, and delete with confirmation.
- **Quick Shuffle**: One-tap shuffle from any tab header or detail screen.
- **Favorites**: Built-in Favorites playlist with toggle access from song tiles, batch actions, and an animated heart button in Now Playing.
- **Song Context Menu & Info**: Play next, add to queue, add to playlist, remove from playlist, open file folder, and view full metadata (bitrate, sample rate, format, path, size).
- **Active Track Highlighting**: Currently playing song is visually distinguished in all library lists.

### Playback & Audio Engine

- **Full Transport Controls**: Play/pause, next/previous, seek bar with elapsed and remaining time, shuffle, and repeat (off → all → one).
- **Queue Management**: The *Up Next* tab in Now Playing supports drag-to-reorder, swipe-to-remove, and tap-to-jump.
- **Audio Equalizer & MFX**: Built-in graphic equalizer presets (Lo-Fi, Warmth, Bass Boost) and customizable multi-band EQ with live pitch and playback speed controls.
- **Sleep Timer**: Choose from presets or set a custom duration. Supports notification actions (+1 min / cancel), "Finish Current Song" mode, and gentle end-of-song volume fade-out.
- **Audio Focus Handling**: Automatic pause on headphone disconnect, configurable ducking, and resume on reconnect.
- **Related Tracks**: Surfaced suggestions for *From this album* and *More by this artist* in Now Playing.
- **Keep Playing on Close**: Optional setting to continue playback when dismissing the app from recents.

### Now Playing & UI

- **Material 3 Expressive Design**: Outfit and Inter typography, circular controls, blurred background artwork, and custom-styled sliders.
- **Global Mini Player**: Persistent bottom bar with live progress strip. Tap to expand, swipe up/down to open/dismiss, and swipe left/right to skip tracks.
- **Now Playing Sheet**: Full-screen modal with blurred artwork background, transport controls, and tabbed content: Lyrics, Up Next, and Related.
- **Multiple Player Layout Styles**: Modern, vinyl record style, or minimalist layout.
- **Unified Color Source & Theming**: 1-tap SegmentedButton controls for Theme Mode (System, Light, Dark) and Color Source (Material You system wallpaper extraction on Android 12+, Dynamic Album Art theming, or Custom Accent Color).
- **AMOLED Pure Black Mode**: Pitch-black backgrounds for OLED displays.
- **Lyrics Display**: Synchronized `.lrc` files with auto-scroll, active-line highlight, and tap-to-seek. Plain `.txt` files display as scrollable text.
- **Audio Visualizer**: Optional animated wave bars at the bottom of the player screen.

### Statistics

- **Listening Dashboard**: A five-page swipeable statistics screen accessible from Settings.
- **Overview**: Total listening time, complete listens, albums/artists/playlists played, first song ever played, most played song, unique song count, and most active listening day.
- **Top Charts**: Top 5 songs, albums, artists, and playlists — tap any entry to navigate or play.
- **Reset Statistics**: Clear listening history with confirmation prompt.

### Android Integration & In-House Native Bridge

- **Background Playback**: Foreground service keeps music running with full media controls in the notification drawer and on the lock screen.
- **Native Platform Bridge**: Direct Kotlin implementation for URL launching, package version info, system file sharing, and hardware-accelerated image cropping/scaling without bloated dependencies.
- **Notification Controls**: Media controls and interactive sleep timer actions (+1 min, End timer) directly in the Android notification shade.

---

## Architecture

Sonora is structured around clean, decoupled components using `go_router` for navigation:

```
lib/
├── models/
│   ├── song.dart            - Song metadata container
│   ├── playlist.dart        - Playlist model
│   └── grouping.dart        - Album/artist grouping helpers
├── providers/
│   ├── player_provider.dart  - Playback, queue, library, audio effects, and sleep timer state
│   ├── settings_provider.dart - App preferences and ThemeColorSource state
│   └── theme_provider.dart   - ThemeMode preference
├── routing/
│   ├── app_router.dart      - GoRouter configuration and shell routes
│   ├── app_routes.dart      - Route path constants
│   └── app_navigation.dart  - Typed navigation helpers
├── screens/
│   ├── home_screen.dart              - Main tab layout (Songs / Albums / Artists / Playlists)
│   ├── now_playing_screen.dart       - Fullscreen player with lyrics, queue, and related tabs
│   ├── album_detail_screen.dart      - Album track listing
│   ├── artist_detail_screen.dart     - Artist discography
│   ├── playlist_detail_screen.dart   - Reorderable playlist tracks and M3U actions
│   ├── settings/                     - Modular settings screens (Appearance, Playback, Sync, Info)
│   ├── stats_screen.dart             - Listening statistics and top charts
│   └── onboarding_screen.dart        - First-run setup flow
├── services/
│   ├── audio_handler.dart            - AudioService background controller
│   ├── music_scanner.dart            - Filesystem scanner and library cache
│   ├── lyrics_service.dart           - LRC/TXT lyrics loading and parsing
│   ├── stats_service.dart            - Play-time and play-count tracking
│   ├── permission_service.dart       - Storage and notification permissions
│   ├── native_bridge.dart            - Native Android Kotlin platform bridge
│   └── sleep_timer_notification_service.dart - Sleep timer notification controller
├── theme/
│   └── app_theme.dart         - Material 3 theme colors, schemes, and typography
├── utils/
│   ├── color_extractor.dart   - Background album-art color extraction
│   └── logger.dart            - Route and debug logging
├── widgets/                   - Reusable UI (mini player, seek bar, album art, visualizer, etc.)
├── app.dart                   - App bootstrap and lifecycle orchestration
└── main.dart                  - Entry point
```

## Requirements

- [FVM](https://fvm.app/) with Flutter **3.47.0** (pinned in `.fvmrc`)
- Dart SDK **^3.13.0**
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

4. **Run tests:**

   ```bash
   fvm flutter test
   ```

5. **Run on a connected device or emulator:**

   ```bash
   fvm flutter run
   ```

6. **Build a release APK:**

   ```bash
   fvm flutter build apk --release
   ```

## Releases

Release APKs are built automatically via GitHub Actions whenever a commit to `main` includes a release prefix in its message (e.g., `release: v1.19.1` or `chore(release): bump to version 1.19.1`). See [CHANGELOG.md](CHANGELOG.md) for the full version history.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

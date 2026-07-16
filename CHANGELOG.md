# Changelog

All notable changes to the Sonora music player project are documented in this file.

## [Unreleased]
### Added
* Add a reusable `ConfirmDeleteDialog` shared widget for destructive actions
* Add a 3-dot action button in the playlist detail AppBar to delete the current playlist
* Show file size and last modified date in the song info bottom sheet
* Toggle back to the main music player view when pressing an active bottom tab button on the now playing screen a second time
* Pre-compute and cache Light/Dark `ThemeData` for all unique album seed colors during library sync/load to prevent UI jank on song changes, and show the unique theme count in sync notifications
* Optimize library sorting by using pre-computed lowercase keys instead of calling `toLowerCase()` repeatedly during sort comparisons

### Fixed
* Fix favorite button state sync in song tile action menu
* Fix song count mismatch in "Add to Playlist" sheet by filtering orphaned song IDs
* Integrate shared confirmation dialog on playlist delete actions (home list and detail screen) and app reset (settings screen)

## [1.4.3] - 2026-07-16
### Fixed
* Update playlists info on "add to playlist" sheet
### Changed
* 1.4.3

## [1.4.2] - 2026-07-15
### Added
* Implement performance optimizations: pre-normalized lowercase keys and lifted filtered lists
* Add library benchmark tests for 100/500/5000/100k song libraries
### Fixed
* Sync audio handler _rawPlaylist after resync and eliminate redundant filtered list recomputation per build frame
### Changed
* Reduce max benchmark size from 100k to 10k songs (more realistic)
* Perf: Cache lowercase keys on Song/AlbumGroup/ArtistGroup; lift filtered list computation to one per rebuild

## [1.4.1] - 2026-07-15
### Added
* Upgrade to android 37, kotlin 2.4.10 and agp 9.3 / gradle 9.6.1
### Changed
* Chore: Update packages

## [1.4.0] - 2026-07-14
### Added
* Make miniplayer global
* Improve routing with deep links for albums, artists and playlists + logging
* Change now playing state after a new song was selected in the related tab
* Add new routing
### Fixed
* Playlist add and delete
* Shuffle not toggled if shuffle play was selected for a list of songs
* Playing 2 songs after each other fast crashed the app
* Let taps go through the audio visualizer
* Reverse swipe on mini player
### Changed
* 1.4.0
* Chore: Improving dialog actions
* Chore: Add logging
* Chore: Safe area on settings and change back icon
* Chore: Improve back icon
* Chore: Fix icon in the Android system media player
* Chore: Fix margins/paddings

## [1.3.2] - 2026-07-13
### Added
* Improve now playing UI once more
* Improve now playing UI
* Add like animation
* Add artist and album onTap on now playing screen
* Add immersive mode
### Fixed
* Marquee text now reset properly upon song change
* Refreshing while having a queue with changes elements, does not reset the queue
### Changed
* 1.3.2
* Chore: Format files

## [1.3.1] - 2026-07-12
### Added
* Add correct app icon at info
* Add simple app icon
### Fixed
* Improve seek bar
* Scroll bar up scrolling buggy behaviour
### Changed
* 1.3.1
* Chore: Format files

## [1.3.0] - 2026-07-12
### Added
* Switch TabBarView to conditional rendering with PageStorageKeys to enable Scrollbars without PrimaryScrollController conflicts
* Display actual app version and build number in settings screen using package_info_plus
### Fixed
* Remove Scrollbar widgets to prevent PrimaryScrollController multi-position crash in TabBarView
### Changed
* Docs: Add AI disclaimer to README.md
* Chore: Set pubspec build number to placeholder +1

## [1.2.2] - 2026-07-12
### Added
* Move RefreshIndicator to individual tab lists for reliable overscroll triggering
* Implement floating app bar and pull-to-refresh library synchronization
* Display sync library details and statistics on settings panel
* Strip featuring artist details from displayTitle in Song model
### Fixed
* Extract dynamic theme color when a song is tapped directly in the list view
* Remove obsolete scroll-to-active logic in queue screen
### Changed
* Refactor: Replace CustomScrollView with NestedScrollView for coordinated app bar collapsing
* Style: Sort dependencies and dev_dependencies alphabetically in pubspec.yaml

## [1.2.1] - 2026-07-11
### Fixed
* Resolve background playback silence and audio focus session conflicts
* Queue shows only one previous song in UI, fix ReorderableListView key

## [1.2.0] - 2026-07-11
### Added
* Add scrollbars, search & sort to albums/artists/playlists tabs

## [1.1.17] - 2026-07-11
### Added
* Animate audio visualizer smoothly to rest when playback pauses
* Implement dynamic Material You themes, animated visualizer, and Sleep Timer with media notification actions
* Implement Android background playback settings, scrollable albums/artists tabs, details screens, and subtle ambient glow
* Add sorting preference saving subtitle to home sort sheet
* Show and style Favorites playlist inside PlaylistSelectorBottomSheet
* Make playlist states reactive and implement a premium bottom-sheet selector
* Add horizontal marquee scrolling text support for long titles and subtitles
### Fixed
* Make audio visualizer wave loop perfectly seamless with integer multiplier frequencies
* Clamp textScaler in MiniPlayer to prevent bottom overflow on high text scaling settings
* Correct Song artwork property usage, remove unnecessary final keywords, and add missing imports
* Resolve ListTile background/splash assertion error inside PlaylistSelectorBottomSheet
* Populate PlayerProvider playlists on app startup and onboarding completion
* Fix quickShuffle original order preservation and make LRC tag regex case-insensitive
### Changed
* Style: Increase audio visualizer height to 80dp, reduce bar count to 20 for wider bars, and raise color opacity to 80%
* Style: Position visualizer at the absolute bottom of now playing screen with rounded phone corner clipping
* Style: Wrap TabBar items in FittedBox to auto-scale on smaller screen widths
* Style: Stretch TabBar segments to fill the outer capsule exactly
* Style: Shrink-wrap TabBar container to wrap tab items exactly
* Style: Center scrollable TabBar items and add horizontal padding to tabs
* Chore: Require hot reload on Dart code changes inside AGENTS.md
* Chore: Add Dart MCP guidelines to workspace AGENTS.md

## [1.1.16] - 2026-07-11
### Changed
* Chore: Add windows support

## [1.1.15] - 2026-07-10

## [1.1.13] - 2026-07-10
### Added
* Support both synchronized LRC and plain text TXT lyrics file loading
* Add tap-to-seek lyrics navigation and restore large thumbnail size
### Changed
* Chore: Add GitHub auto-generated release notes to release tags
* Chore: Revert build-apk runner back to ubuntu-latest
* Chore: Switch build-apk runner to macos-latest for faster builds

## [1.1.11] - 2026-07-10
### Added
* Seek to beginning on back button if song has played more than 3 seconds
### Fixed
* Resolve placeholder sizing collapse when size is double.maxFinite
* Catch just_audio loading interrupted exceptions during rapid track changes
* Maintain AlbumArt placeholder dimensions when sizing is infinite
* Check for lyrics file status change during fast-path cache validation
* Resolve light mode text legibility and prevent vertical layout overflow on small screens

## [1.1.5] - 2026-07-10
### Added
* Detect lyrics file existence during library sync to avoid UI thread I/O checks

## [1.1.4] - 2026-07-10
### Added
* Implement synchronized lrc lyrics overlay with auto-scrolling centering
### Changed
* Chore: Support unreleased commits section in generate_changelog.py
* Chore: Add generate_changelog.py helper script and document usage in AGENTS.md

## [1.1.2] - 2026-07-10
### Changed
* Docs: Remove wavy progress bar mentions from CHANGELOG.md
* Docs: Condense changelog entries for minimal and concise formatting
* Chore: Clarify changelog brevity and code analysis thoroughness in AGENTS.md
* Chore: Document minimal changes and conventional commits guidelines in AGENTS.md

## [1.1.0] - 2026-07-10
### Added
* Implement Material 3 Expressive wavy slider indicator (squirly snake) on NowPlaying SeekBar
* Implement sliding capsule tab bar indicator for premium navigation layout
* Add GitHub Actions workflow to build release APKs on pushes to main containing 'release:'
* Implement manual library synchronization model, age-warning banner prompt on HomeScreen, redesigned Settings sync panel, and fixed status bar icon brightness overlay issues
* Implement premium Material 3 Expressive onboarding experience with PageView sliders and integrated permissions/folder setup
* Add full music actions dropdown menu (Play Next, Add to Queue, Add to Playlist, Song Info, Favorite Song) to PlaylistDetailScreen
* Add sorting by 'Recently Added' based on cached file modification time
* Implement fully incremental file sync check using file size and modification timestamps to skip parsing unchanged files
* Add global GestureDetector in MaterialApp builder to dismiss keyboard on tapping outside inputs
* Add theme mode settings (system/light/dark) with persistence, app info dialog, and licenses page
* Implement vertical and horizontal swipe gestures on bottom MiniPlayer (swipe up/down to open/close player, swipe left/right to skip track)
* Implement song favorite states, default Favorites playlist, player screen actions (info, add to queue, add to playlist), and grammatically correct pluralization count
* Implement search, sort, song info details bottom sheet, linear syncing indicator, and music count header
* Implement ID3 metadata tag parsing, artwork disk caching, and support wide variety of formats including opus
### Fixed
* Fix release workflow: replace indented heredoc with echo lines to prevent bash parsing errors
* Fix blank NowPlayingScreen deadlock: add close buttons when player queue is empty
* Fix quick shuffle visual glitch: force shuffle active state immediately before loading playlist
* Fix playlist sync: maintain local playlist state and map song IDs sequentially to ensure instant updates on dismiss and reorder
* Optimize startup sorting: load sorting settings on app init and pre-sort JSON index cache to prevent visual layout jumps
* Fix bitrate formatting display to show native kbps values directly instead of dividing by 1000
* Optimize audio queue loading with sliding window strategy to prevent lag with 10k+ songs, and remove openFolder feature
* Fix 'Show in Folder' to properly open containing directory using FileProvider and DocumentsUI fallback strategies
* Fix now playing overlay gradient to use theme-aware surface colors instead of hardcoded black (light mode fix)
* Enforce bottom MiniPlayer on playlists detail view and increase bottom padding of Lists and FABs to prevent overlapping with bottom bar
* Fix shuffle bug to update concatenating audio sources dynamically in-place, and add Quick Shuffle buttons to HomeScreen and playlists detail views
* Fix state update on song favorited to reactively sync playlists tab during app lifecycle and clean up remaining song(s) pluralization copies
* Fix analysis warnings, clean unused imports, and optimize tag parsing code
### Changed
* Enable tabular figures font features on elapsed and remaining duration labels inside SeekBar
* Remove wavy progress indicator track and fix SeekBar duration label clamping and negative formatting bugs
* Configure splashBorderRadius on custom TabBar to resolve rectangular overlay outline on tap/longpress
* Reposition Change button directly next to Sync Folder Path inside SettingsScreen
* Chore: Add signature on apk release builds
* Migrate theme preference storage to SharedPreferencesAsync with automatic legacy JSON fallback
* Update app reset handler to completely delete all saved preferences from SharedPreferencesAsync and delete theme preference file
* Update fallback namespace, notification channel ID, and platform MethodChannel to use de.yurtemre.sonora
* Change Android package application ID and namespace to de.yurtemre.sonora
* Replace NowPlayingScreen AnimatedVinyl disk with a premium larger AlbumArt Card
* Stop player background playback when app is swiped away from Android recent tasks screen
* Use modern filled/toggled Material icon states for active shuffle and repeat player control actions
* Support instant optimistic updates and favorite status synchronization inside Favorites playlist
* Migrate all settings and persistence logic to SharedPreferencesAsync
* Save sorting options (sortBy and sortAscending) persistently in settings.json
* Migrate deprecated members to RadioGroup and onReorderItem according to modern Flutter guidelines
* Optimize library sync by offloading dir listing, tag parsing, and artwork caching to background Isolate, and use direct FFI duration parsing to skip player init lag
* Highlight active song in main library Songs tab and add global thicc premium Scrollbars to all long lists
* Update QueueScreen to show positions, dim older tracks, auto-scroll to active track, and highlight the current track cleanly
* Refactor HomeScreen to use Scaffold floatingActionButton and bottomNavigationBar slots so add-playlist FAB auto-adjusts above MiniPlayer
* Round corners of media player sheet, and optimize paddings and FAB margins to fit bottom player bar cleanly
* Enrich existing cached songs with dynamic ID3 tags migration on syncLibrary
* Remove forceCompileSdk from build.gradle.kts
* Replace audiotags with audio_tags_lofty for 16KB Android page alignment compatibility
* Configure dynamic compileSdk upgrade for audiotags plugin compatibility, stage build changes
* Chore: Init
* Initial commit

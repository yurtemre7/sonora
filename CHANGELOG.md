# Changelog

All notable changes to the Sonora music player project are documented in this file.

## [1.1.16] - 2026-07-11
### Added
* Add `copyWith` method to Song model for immutable field updates
* Add `displayTitle` getter to strip artist name duplication from song titles
### Changed
* Enable free scrolling on synchronized lyrics, pause auto-centering after manual scroll for 4 seconds
* Tap lyric line now re-enables auto-scroll and centers the tapped line
* Replace manual Song construction in toggleFavoriteSong with `copyWith`
### Fixed
* Fix lyrics auto-centering: correct scroll target formula accounts for ListView padding
* Fix next button stopping playback with single song in repeat modes
* Remove ProcessingState.completed handler that interfered with just_audio loop wrap

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

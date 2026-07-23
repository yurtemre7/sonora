# Changelog

All notable changes to the Sonora music player project are documented in this file.

## [Unreleased]
### Added
* Full app localization (English, German, Japanese) via Flutter `intl` — all settings screens, favorites, sort sheet, count labels, and dialogs now use `context.l10n`
* Language picker in Library Formatting settings (system default / English / German / Japanese)

## [1.11.2] - 2026-07-23
### Fixed
* Downscale background blur images to 120px in detail screens to eliminate GPU/RAM lag when opening playlists, artists, or albums with high-resolution covers
* Evict stale ImageCache entries when updating playlist cover images so new cropped artwork renders immediately

## [1.11.1] - 2026-07-23
### Fixed
* Render scanned local artist cover artwork (`artist.png`/`artist.jpg`) inside the artist detail screen header and background blur
* Unify home screen tab bar text font size across all tabs

## [1.10.1] - 2026-07-22
### Fixed
* Implement custom draggable scrollbar to resolve transition crashes
* Page animation glitching

## [1.10.0] - 2026-07-22
### Added
* Add nightcore, lo-fi, bass boost and mfx persistence
* Add tab and track skipping transitions
### Fixed
* Bottom sheet scroll and height

## [1.9.2] - 2026-07-22
### Fixed
* Restore miniplayer padding in privacy and formatting settings screens
* Resolve settings persistence and UI safe area issues
### Changed
* Perf: Downscale playlist cover images to prevent memory bloat
* Perf: Downscale album and artist images to prevent memory bloat and scrolling lag

## [1.9.1] - 2026-07-21
### Fixed
* Resolve navigation bar transparency, sorting, and playlist cover deletion

## [1.9.0] - 2026-07-21
### Added
* Show counts for each section in favorites screen
* Highlight MFX icon button when custom speed is selected
* Change playlist cover image from home screen playlists tab
* Custom playlist cover images via file_picker
* Add experimental MFX (Slowed, Sped Up, Reverb EQ) to now playing
* Add playback speed controls to now playing screen
* Redesign song info bottom sheet with categorized groups and max height constraint
* Move favorites icon to SliverAppBar actions and revert dedicated tab
* Move favorites to a dedicated tab instead of persistent appbar button
* Standardise artist avatar UI across list, favorites, and detail screens
* Hide home screen actions when search is focused and dismiss keyboard on tap outside
* Add dedicated Favorites screen with animated button, remove legacy favorites playlist
* Add 3-dot menu to song tiles in album, artist, and playlist views
* Add amoled pure black toggle for dark mode
* Add customizable home screen title greeting and username
* Allow renaming playlists
* Display total listening time alongside song counts
* Tap active tab to scroll list to top
* Show replay icon when playlist is completed
* Add library formatting settings to toggle feat/artist stripping
* Parse genre, year, and track number from metadata and filenames
### Fixed
* Resolve analysis warnings and move speed slider to MFX sheet
* Scanner dropping metadata like trackNumber and genre on lyric updates
* Resolve string interpolation syntax error in favorites screen preventing albums from showing
* Restore missing artist detail screen favorite button and ensure preferences save modifiable lists
* Fix appearance settings screen state updates
* Move personalization settings to appearance screen
* Remove found string from artists albums playlists tabs
* Format listening time accurately without rounding and simplify text
* Calculate progress bar gradient in mini player
* Calculate seekbar gradient and thumb color based on progress
* Reset playback immediately on replay icon tap
* Remove canLaunchUrl check for opening links
* Use default LaunchMode for url_launcher
* Add Library Formatting to settings screen
* Resolve static analyzer issues
### Changed
* Style: Refine favorites screen section headers
* Style: Apply filled styling for active action chips
* Refactor: Remove legacy favorites playlist checks
* Chore: Sort the imports
* Chore: Less horizontal padding
* Revert "feat: move favorites to a dedicated tab instead of persistent appbar button"
* Refactor: Simplify SongTile and internalize menu logic, add hideMenu flag
* Style: Move info and support to bottom of settings list
* Style: Reduce title font size for home screen greeting
* Style: Use back button instead of X in Settings AppBar
* Refactor: Migrate all settings to SettingsProvider singleton

## [1.8.3] - 2026-07-21
### Added
* Add dedicated privacy and permissions setting screen
### Fixed
* Internet permission, stats playtime calculation, and theme mode toggle

## [1.8.2] - 2026-07-21
### Added
* Add community and support section to settings
* Redesign and enforce onboarding completion
* Highlight update tile when update is pending
* Add changelog viewer
* Add automatic GitHub release checker
* Support sidecar cover.jpg as album artwork fallback
### Fixed
* Address user feedback on navigation bar, track sorting, playlist reordering, and local artist images
* Default pause on duck to false
* Add safe area
* Update the launchUrl to not check the Url as this leads to an error
* Add safe area to changelog screen
* Playlist reordering UI flash
* Disable automatic update check in debug mode
### Changed
* Chore: Add build number +1 back
* Refactor: Introduce SettingsProvider for eager setting loads
* Refactor: Split settings into sub-screens and add danger zone logic
* Chore: Update flutter to 3.44.7

## [1.7.0] - 2026-07-20
### Added
* Add setting to select default start page
* Sort album tracks by disc and track number
* Add reordering support to playlists
* Use local artist images
* Add 'Recently Added' sorting option to albums view
### Fixed
* Make system navigation bar edge-to-edge and transparent

## [1.6.2] - 2026-07-19
### Added
* Add default app color picker based on extracted themes
### Fixed
* Restore useSafeArea: true to bottom sheets
* Now playing sheet safe areas and overlapping elements
* Apply proper safe area on stats screen
### Changed
* Restore useSafeArea: true on all bottom sheets
* Chore: Improve stats screen bottom padding while player is active
* Refactor: Apply formatting and resolve all static analysis issues

## [1.6.1] - 2026-07-19
### Added
* Add setting to pause music on notifications
* Display shuffle sessions, skips, and restarts in stats UI
* Add tracking for shuffle sessions, song skips, and song restarts
### Fixed
* Resolve playback quirks (shuffle mutation, skip/seek analytics) and dynamic stats padding
* Show replay icon and restart queue when playback completes
* Add bottom padding to statistics page to prevent miniplayer overlap
* Correct playback time tracking rate for analytics
### Changed
* Style: Rework sleep timer setting UI and sync button padding
* Chore: Add MIT license
* Chore: Improve changelog generation script
* Chore: Rename AGENTS.md to agents.md and update content
* Chore: Improve README.md

## [1.6.0] - 2026-07-17
### Added
* Add listening statistics screen with cumulative play tracking

## [1.5.1] - 2026-07-17
### Added
* Make immersive mode persistent
* Add real-time active worker indicator next to Unique Themes in settings sync panel
* Implement background theme color extractor to dynamically populate unique themes and album colors
### Fixed
* Load sort preferences before HomeScreen mounts to eliminate sort flash on cold start
* Dismiss Now Playing sheet before popping nested routes on Android back gesture
* Close Now Playing sheet before popping nested routes on Android back gesture
* Make song sorting stable with title and ID fallback comparisons for matching timestamps
* Group dynamic colors into visual HSL buckets to show realistic unique themes count
* Prevent vertical overflow in album detail screen appbar
* Pre-sort files by tab-specific song setting and fix initial sync lyrics detection path
* Make sequential sync the default and sole option, simplify settings UI
* Apply saved tab sorting on app start and group duplicate album names by artist
### Changed
* Chore: Remove wrong popscopes
* Perf: Only refresh go_router when gate state actually changes to eliminate startup route log spam
* Chore: Run dart format to apply standard formatting style across all files
* Chore: Fix minor dart lint warnings to ensure clean static analysis
* Chore: Remove redundant and slow benchmark tests to speed up test runs
* Perf: Batch disk writes and defer library updates in color extractor to prevent lag
* Chore: Fix folder name on README.md
* Chore: Add cupertino icons dependency for flutter build warning to disappear

## [1.4.5] - 2026-07-16
### Added
* Add sync method selector setting with timing benchmarks and warnings

## [1.4.4] - 2026-07-16
### Added
* Toggle back to music player view when pressing active bottom tab a second time
* Add confirm dialog for destructive actions and delete button in playlist detail view
### Fixed
* Correct favorite button state, playlist count, and add file info to song info sheet
### Changed
* Perf: Support configurable maxWorkers and run comparative benchmarks up to 5k songs
* Perf: Add on-device comparative integration test benchmark
* Perf: Add consolidated filesystem discovery and sync benchmark test
* Perf: Parallelize metadata reading and artwork extraction in background isolates
* Perf: Precompute and cache themes, optimize sorting, and update settings stats

## [1.4.3] - 2026-07-16
### Fixed
* Update playlists info on "add to playlist" sheet

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
* Chore: Format files

## [1.3.1] - 2026-07-12
### Added
* Add correct app icon at info
* Add simple app icon
### Fixed
* Improve seek bar
* Scroll bar up scrolling buggy behaviour
### Changed
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

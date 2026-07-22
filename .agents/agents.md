# Project Rules & Customizations

This file outlines project-specific rules and instructions for coding assistants working on Sonora.

## Development Workflow

### Changelog Maintenance
* **Rule:** Whenever you implement a new feature, refactor components, or resolve bugs, you must record these changes under the appropriate heading in the [CHANGELOG.md](file:///Users/yurtemre/Code/antigravity/kind-salk/CHANGELOG.md) file located in the project root.

### Autogenerating the Changelog
* **Instruction:** You can autogenerate or refresh the changelog based on commits between git tags by running the python script:
  `python3 scripts/generate_changelog.py`
  Always run this script after new tags have been fetched or pushed to sync git logs with the changelog.

### Automating Releases
* **Rule:** Sonora uses GitHub Actions to compile and package production Android builds.
* **Instruction:** To trigger a release tag build, perform the following:
  1. Bump the `version` field inside `pubspec.yaml`.
  2. Commit the changes using a commit message prefix containing `release:` (e.g., `release: v1.1.2` or `chore(release): bump to version 1.1.2`).
  3. Push to `main`. This triggers the release workflow, compiles the release split-APKs, and creates a tagged release on GitHub.

### APK Compilation Frequency
* **Rule:** Do not run `fvm flutter build apk` or other heavy local compilation tasks for every single small change. Instead, use `fvm flutter analyze` for syntax validation during development, and reserve local release/debug APK compilations for final verification phases.

### Changelog Entry Format
* **Rule:** Keep descriptions of changelog entries inside `CHANGELOG.md` minimal, clear, and concise.

### Code Change Quality
* **Rule:** Code modifications must be thorough, precise, and backed by detailed analysis. Do not make quick hacks; implement robust, complete solutions while avoiding unnecessary stylistic churn.

### Conventional Commits Format
* **Rule:** Always use the Conventional Commits specification for git commit messages. Examples:
  * `feat: add home screen warning banner`
  * `fix: prevent layout overflow in landscape`
  * `refactor: simplify theme lookup`
  * `chore: update build gradle configuration`
  * `release: v1.1.2` (use to trigger automation workflows)

## Tooling & Optimization

### Development Commands
* **Analysis:** Use `fvm flutter analyze` for static analysis and syntax validation during development.
* **Hot Reload:** When the Flutter app is running, use hot reload (typically via your IDE or `r` in the terminal) to apply code changes instantly without restarting the app.
* **Hot Restart:** For structural state changes (like adding new widgets or modifying global state), use hot restart (typically via your IDE or `R` in the terminal).
* **Rule:** If a Flutter application is currently running, you should use hot reload after making Dart code changes to keep the live app in sync. Use hot restart for structural changes.

### Analysis Options
* **Rule:** The project's linting configuration is defined in [analysis_options.yaml](file:///Users/yurtemre/Code/antigravity/kind-salk/analysis_options.yaml). It extends `flutter_lints/flutter.yaml` and enforces strict guidelines, including `always_use_package_imports`, `prefer_single_quotes`, and various other stylistic rules. Always ensure new code complies with these rules to keep `flutter analyze` clean.

## Music Player Development

### Audio Playback
* **Background Service:** Use just_audio with proper foreground service configuration for Android background playback.
* **Audio Focus:** Always request and abandon audio focus appropriately to handle interruptions (calls, other apps).
* **Queue Management:** Maintain a reactive audio source queue that updates dynamically when songs are added/removed.
* **Gapless Playback:** Ensure smooth transitions between tracks by preloading next tracks when possible.

### Performance & Optimization
* **Background Processing:** Offload heavy operations (file scanning, tag parsing, artwork extraction) to background isolates to prevent UI jank.
* **Incremental Sync:** Use file size and modification timestamps to skip unchanged files during library synchronization.
* **Caching:** Cache parsed metadata, album artwork, and theme colors to disk to avoid redundant parsing.
* **Lazy Loading:** Implement lazy loading for large lists (library views) with efficient filtering and sorting.

### State Management
* **Reactive State:** Use providers (ChangeNotifier/Notifier) for reactive state updates across the app.
* **Persistence:** Persist user preferences (sort options, theme mode, playback settings) using SharedPreferencesAsync.
* **Queue State:** Keep the playback queue in sync with library changes (resync, playlist modifications).

### UI/UX Best Practices
* **Material 3:** Follow Material 3 Expressive design guidelines with proper theming and typography.
* **Dynamic Themes:** Extract accent colors from album artwork for immersive, personalized theming.
* **Gesture Controls:** Implement intuitive gestures (swipe on mini-player, tap-to-seek on lyrics) for better user experience.
* **Accessibility:** Ensure proper semantic labels, contrast ratios, and screen reader support.

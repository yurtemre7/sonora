# Sonora: agent rules

Flutter music player (Android, iOS, Windows). Audio: `just_audio` + `audio_service`. State: `ChangeNotifier` providers. Prefs: `SharedPreferencesAsync`. Flutter is pinned via FVM (`.fvmrc`): prefix commands with `fvm`.

## Workflow

* **Validate:** `fvm flutter analyze` after changes; it must stay clean. Lints are in `analysis_options.yaml` (includes `always_use_package_imports`, `prefer_single_quotes`).
* **Builds:** do not build APKs per change. Build only for final verification.
* **Running app:** hot reload after Dart edits; hot restart for structural or global-state changes.
* **Quality:** root-cause fixes, no quick hacks, no unrelated style churn.
* **Strings:** add every user-facing string to both `lib/l10n/app_en.arb` and `app_ja.arb`, then run `fvm flutter gen-l10n`. Generated `app_localizations*.dart` files are committed.
* **Settings:** a new preference needs a `SettingsProvider` field and setter, plus a key in `_settingKeys` in `lib/services/backup_service.dart`.

## Changelog

* Record every feature, refactor and fix in `CHANGELOG.md`: one minimal line each, under the right heading.
* After new tags exist, refresh it with `dart scripts/generate_changelog.dart`.

## Commits and releases

* Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `release:`.
* Release: bump `version` in `pubspec.yaml`, commit with a `release:` message, push to `main`. `.github/workflows/release.yml` then builds the split APKs and tags the release.

## Code conventions

* **Heavy work** (scanning, tag parsing, artwork extraction) stays off the UI thread.
* **Incremental scan:** skip files whose size and modification time are unchanged.
* **Disk caches:** metadata, artwork, theme colors. Cover thumbnails go through `ThumbnailStore`.
* **Lists:** build lazily; keep filtering and sorting cached (`LibrarySearchIndex`).
* **Queue:** keep it in sync with library changes (rescan, playlist edits).
* **Audio:** handle audio focus and interruptions; keep the foreground service for background playback.
* **UI:** Material 3 Expressive; theme colors come from album art; keep semantic labels and contrast.

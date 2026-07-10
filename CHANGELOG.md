# Changelog

All notable changes to the Sonora music player project are documented in this file.

## [1.1.1] - 2026-07-10
### Fixed
* Fixed GitHub Actions release workflow artifact resolution by naming the download task explicitly.
* Added fallback glob path searches (`dist/sonora-*.apk` and `dist/*/sonora-*.apk`) to release asset uploads.

## [1.1.0] - 2026-07-10
### Added
* **Manual Library Sync Model:** Disabled automatic background library sync on launch and app resume. Added a manual trigger model.
* **Sync Age Warning Banner:** Created an inline M3 card prompt on the home screen when the last sync date is 30+ days old. Offers "Sync Now" or "Remind Next Month" (postpones check for 30 days).
* **Settings Panel Redesign:** Grouped folder configuration, path labels in monospace, and manual sync buttons inside a clean, unified Material 3 card container.
* **Typographic Stabilizer:** Enabled Tabular Figures OpenType features (`fontFeatures`) on SeekBar duration labels to prevent numbers from wiggling when ticking.
* **Consistent Status Bar Colors:** Added theme-aware `systemOverlayStyle` in the global `AppBarTheme` to keep status bar icons legible across all screens.
* **Rounded Tab Ripples:** Set `splashBorderRadius` on the home screen custom capsule tab selector to clip ink splashes to the pill shape.
* **GitHub Actions Workflow:** Created `.github/workflows/release.yml` to automate release packaging for Android APKs.

### Removed
* Reverted the custom wavy linear progress bar ("wavy snake") back to standard straight Material 3 linear lines.

## [1.0.0] - 2026-07-08
### Added
* **Premium Album Art Card:** Replaced rotating vinyl animation with a high-resolution elevation artwork card.
* **Empty NowPlaying Close Button:** Added an empty queue close header and central button to avoidNowPlaying deadlocks.
* **Domain & Namespace Renaming:** Migrated from `com.sonora.sonora` to `de.yurtemre.sonora` across all gradle scripts, paths, and platform services.
* **Material 3 Expressive Onboarding:** Wizard interface for permissions check and music directory selection.
* **Theme Migration:** Replaced JSON settings files with `SharedPreferencesAsync`.
* **Clean App Reset:** Resetting wipes all Sonora preferences and returns to the onboarding slider.

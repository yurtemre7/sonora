# Changelog

All notable changes to the Sonora music player project are documented in this file.

## [1.1.2] - 2026-07-10
### Added
* Configure release description upload via `body_path` in GitHub Actions release workflow.

## [1.1.1] - 2026-07-10
### Fixed
* Fix release workflow artifact download and asset upload fallback paths.

## [1.1.0] - 2026-07-10
### Added
* Implement manual library sync model and redesigned settings card.
* Add 30-day library sync warning prompt banner to HomeScreen.
* Add Tabular Figures (`fontFeatures`) on SeekBar duration labels to stabilize numbers.
* Standardize theme status bar overlay colors across all pushed routes.
* Bind rounded `splashBorderRadius` on home custom tab selector ripples.
* Setup automated release workflow for Android ABI-split APKs.

## [1.0.0] - 2026-07-08
### Added
* Replaced spinning vinyl animation with a high-resolution artwork card.
* Add header close button to now playing screen when queue is empty.
* Rename package ID and namespaces from `com.sonora.sonora` to `de.yurtemre.sonora`.
* Add Material 3 Expressive onboarding slide wizard for folder setup.
* Migrate theme preference to `SharedPreferencesAsync`.
* Add application reset method returning to onboarding.

# Project Rules & Customizations

This file outlines project-specific rules and instructions for coding assistants working on Sonora.

## Development Workflow

### Changelog Maintenance
* **Rule:** Whenever you implement a new feature, refactor components, or resolve bugs, you must record these changes under the appropriate heading in the [CHANGELOG.md](file:///Users/yurtemre/Code/antigravity/kind-salk/CHANGELOG.md) file located in the project root.

### Automating Releases
* **Rule:** Sonora uses GitHub Actions to compile and package production Android builds.
* **Instruction:** To trigger a release tag build, perform the following:
  1. Bump the `version` field inside `pubspec.yaml`.
  2. Commit the changes using a commit message prefix containing `release:` (e.g., `release: v1.1.2` or `chore(release): bump to version 1.1.2`).
  3. Push to `main`. This triggers the release workflow, compiles the release split-APKs, and creates a tagged release on GitHub.

### APK Compilation Frequency
* **Rule:** Do not run `fvm flutter build apk` or other heavy local compilation tasks for every single small change. Instead, use `fvm flutter analyze` for syntax validation during development, and reserve local release/debug APK compilations for final verification phases.

### Minimal Changes Constraint
* **Rule:** Keep changes minimal. Avoid unnecessary code churn, stylistic formatting rewrites, or modifying structures unrelated to the task. Keep diffs as tiny, precise, and targeted as possible.

### Conventional Commits Format
* **Rule:** Always use the Conventional Commits specification for git commit messages. Examples:
  * `feat: add home screen warning banner`
  * `fix: prevent layout overflow in landscape`
  * `refactor: simplify theme lookup`
  * `chore: update build gradle configuration`
  * `release: v1.1.2` (use to trigger automation workflows)

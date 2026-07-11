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

### Using the Dart MCP Server
* **Rule:** Prefer using the `dart-mcp-server` tools instead of running raw terminal commands (`fvm flutter ...`) for static analysis, hot reloads, hot restarts, and runtime diagnostics.
* **Diagnostics / Analysis:** Instead of `fvm flutter analyze`, use the `analyze_files` tool. Ensure the project root (`file:///Users/yurtemre/Documents/antigravity/kind-salk`) is registered first via the `roots` tool with command `add`.
* **Hot Reload & Hot Restart:** To apply and test code changes instantly:
  1. Run `dtd` with command `listDtdUris` to find available tool daemon endpoints.
  2. Connect using `dtd` command `connect` and the retrieved workspace URI.
  3. Call `hot_reload` or `hot_restart` on the connected `appUri`.
* **Checking Runtime Failures:** Use `get_runtime_errors` on the active `appUri` to fetch VM/Flutter framework assertions and stack traces instantly.

# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI app lives in `AppleCheck/` with MVVM folders: `Views/`, `ViewModels/`, `Services/`, `Models/`, `Persistence/`, `Utils/`, `Background/`, and `Notifications/`. Shared assets reside in `Assets.xcassets/`, including the SVG-driven AppIcon. Automation and data sources live under `scripts/` (`check_updates.py`, `sources.yaml`, generated `state.json`). Continuous monitoring is configured via `.github/workflows/check_updates.yml`. Regenerate `AppleCheck.xcodeproj` from `project.yml` whenever you touch project-level settings.

## Build, Test, and Development Commands
Use the Makefile for repeatable workflows:
```
make gen         # regenerate AppleCheck.xcodeproj via XcodeGen
make build       # build AppleCheck scheme for the default simulator
make icons       # rebuild AppIcon PNGs if the SVG changed
make all         # icons + gen + build
make clean       # remove derived data for the scheme
```
Run `python3 scripts/check_updates.py --help` to inspect automation flags; execute without args to dry-run the GitHub Action locally (writes to `scripts/state.json`).

## Coding Style & Naming Conventions
Stick to Swift 5.9 defaults: four-space indentation, braces on the same line, and trailing commas only when clarifying multiline literals. Name types and views with `UpperCamelCase`, properties and functions with `lowerCamelCase`, and suffix view models with `ViewModel`. Match filenames to the primary type and keep localized strings in Polish while keeping doc comments concise. Mirror existing Core Data builder patterns when adding models.

## Testing Guidelines
No XCTest target ships today; create `AppleCheckTests` under `Tests/` and mirror the production module layout when adding coverage. Prefix async tests with the feature area (e.g. `Services_UpdateFetcherTests`). For now, validate changes by running the `AppleCheck` scheme in Simulator and checking console logs plus persisted data. Document manual test results in the PR description, especially for background refresh or notification changes.

## Commit & Pull Request Guidelines
Commits are short and imperative (`fix github action`, `add icon`). Keep subjects under 50 characters and use bodies wrapped at 72 when extra context is needed. Each PR should explain what changed, reference related issues, and include screenshots or log excerpts for UI or automation tweaks. Confirm `make build` (and relevant scripts) before requesting review and assign at least one maintainer.

## Automation & Delivery Notes
The scheduled workflow depends on `scripts/check_updates.py`; coordinate before altering the JSON schema or polling cadence because GitHub Actions and downstream consumers expect stability. Update README secrets guidance if webhook handling changes, and ensure BG task intervals in `SettingsView` stay aligned with backend expectations.

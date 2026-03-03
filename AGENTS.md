# AGENTS.md

This file provides guidance to any AI coding agent working with this repository.

## Project

NetworkMap — a macOS menu bar app (Swift 6 / SwiftUI) that shows the user's public IP address in real-time via `MenuBarExtra`. Runs as a background accessory with no Dock icon.

**Requirements:** macOS 13.0+, Swift 5.7+

## Build & Run

```bash
./build.sh          # release build + .app bundle packaging (embeds Sparkle & signs ad-hoc)
open NetworkMap.app  # launch the app
swift build          # debug build only (no .app bundle)
```

**Clean:** `rm -rf .build NetworkMap.app`

## Release Automation

The project uses GitHub Actions (`.github/workflows/release.yml`) to handle automated releases.

1. Triggered on pushes to tags starting with `v*` (e.g., `v1.0.0`).
2. Builds the app using `build.sh` and ad-hoc signs it (`codesign -s - -f --deep`).
3. Packages the `.app` into a zip file.
4. Uses [Sparkle](https://sparkle-project.org/) to generate an `appcast.xml` incorporating the file's signature, pushing it to the `gh-pages` branch.
5. Publishes the zip as a GitHub Release artifact.

**Note:** The GitHub Actions workflow requires a `SPARKLE_PRIVATE_KEY` secret configured in the repository to sign the Sparkle appcast updates.

There are no tests.

## Architecture

Two source files in `Sources/NetworkMap/`:

- **`NetworkMapApp.swift`** — `@main` entry point. Declares a `MenuBarExtra` scene (SwiftUI) with IP display, Refresh (`⌘R`), Check for Updates, and Quit (`⌘Q`). Uses `AppDelegate` to set `NSApp.setActivationPolicy(.accessory)` so the app has no Dock icon. Also initializes the `SPUStandardUpdaterController` for Sparkle.

- **`NetworkManager.swift`** — `@MainActor ObservableObject`. Fetches IP from `https://api.ipify.org` via `URLSession` async/await. Monitors network changes with `NWPathMonitor` to auto-refresh. Publishes `currentIP` (`"Fetching..."` → IP string or `"Offline"`).

## Conventions

- Use `async/await` and `Task` for all asynchronous work — no completion handlers.
- Use `@StateObject` / `@Published` for SwiftUI state management.
- UI uses SF Symbols and `.monospaced` system fonts for IP display.

## Packaging Constraint

The app requires `LSUIElement = 1` in `Info.plist` to hide from the Dock. Swift Package Manager cannot set this, so `build.sh` manually constructs the `.app` bundle structure, writes `Info.plist` after `swift build -c release`, embeds the `Sparkle.framework`, and modifies the executable's `rpath`. Any new `Info.plist` keys (such as `SUFeedURL` or `SUPublicEDKey`) must be added to `build.sh`.

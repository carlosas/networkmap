# AGENTS.md

This file provides guidance to any AI coding agent working with this repository.

## Project

NetworkMap — a macOS menu bar app (Swift 6 / SwiftUI) that shows the user's public IP address in real-time via `MenuBarExtra`. Runs as a background accessory with no Dock icon.

**Requirements:** macOS 13.0+, Swift 5.7+

## Build & Run

```bash
./build.sh          # release build + .app bundle packaging
open NetworkMap.app  # launch the app
swift build          # debug build only (no .app bundle)
```

**Clean:** `rm -rf .build NetworkMap.app`

There are no tests.

## Architecture

Two source files in `Sources/NetworkMap/`:

- **`NetworkMapApp.swift`** — `@main` entry point. Declares a `MenuBarExtra` scene (SwiftUI) with IP display, Refresh (`⌘R`), and Quit (`⌘Q`). Uses `AppDelegate` to set `NSApp.setActivationPolicy(.accessory)` so the app has no Dock icon.

- **`NetworkManager.swift`** — `@MainActor ObservableObject`. Fetches IP from `https://api.ipify.org` via `URLSession` async/await. Monitors network changes with `NWPathMonitor` to auto-refresh. Publishes `currentIP` (`"Fetching..."` → IP string or `"Offline"`).

## Conventions

- Use `async/await` and `Task` for all asynchronous work — no completion handlers.
- Use `@StateObject` / `@Published` for SwiftUI state management.
- UI uses SF Symbols and `.monospaced` system fonts for IP display.

## Packaging Constraint

The app requires `LSUIElement = 1` in `Info.plist` to hide from the Dock. Swift Package Manager cannot set this, so `build.sh` manually constructs the `.app` bundle structure and writes `Info.plist` after `swift build -c release`. Any new `Info.plist` keys must be added to `build.sh`.

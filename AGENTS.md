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
2. Derives `VERSION` and `BUILD_NUMBER` from the git tag and commit count.
3. Generates app and menu bar icons from `icon.svg` via `generate_icons.swift`.
4. Builds the app using `build.sh` and ad-hoc signs it (`codesign -s - -f --deep`).
5. Packages the `.app` into a DMG via `create-dmg.sh`.
6. Publishes the DMG as a GitHub Release artifact.
7. Generates a Sparkle appcast (`appcast.xml`) and deploys it to GitHub Pages for auto-updates.
8. If the `TAP_GITHUB_TOKEN` secret is set, auto-updates the Homebrew cask in `carlosas/homebrew-tap`.

There are no tests.

## Architecture

Source files in `Sources/NetworkMap/`:

- **`NetworkMapApp.swift`** — `@main` entry point. Declares a windowed-style `MenuBarExtra` scene (SwiftUI) using a custom menu bar icon loaded from bundled `MenuBarIcon` resources. The menu displays the public IP, and uses a custom `MenuItemButton` view for Refresh, Check for Updates, and Quit actions. Uses `AppDelegate` to set `NSApp.setActivationPolicy(.accessory)` so the app has no Dock icon. Initializes the `SPUStandardUpdaterController` for Sparkle auto-updates.

- **`NetworkManager.swift`** — `@MainActor ObservableObject`. Fetches IP from `https://api.ipify.org` via `URLSession` async/await. Monitors network changes with `NWPathMonitor` to auto-refresh. Publishes `currentIP` (`"Fetching..."` → IP string or `"Offline"`).

- **`Resources/`** — Bundled assets: `AppIcon.icns` (application icon), `MenuBarIcon.png` and `MenuBarIcon@2x.png` (template images for the menu bar). These are copied into the `.app` bundle by `build.sh`.

### Supporting Scripts

- **`build.sh`** — Release build script. Runs `swift build -c release`, constructs the `.app` bundle, writes `Info.plist` (with `LSUIElement`, Sparkle keys, and version strings), copies icon resources, embeds `Sparkle.framework`, and sets the executable's `rpath`. Derives `VERSION` from the latest git tag and `BUILD_NUMBER` from the git commit count when not set by CI.

- **`create-dmg.sh`** — Packages `NetworkMap.app` into a distributable DMG.

- **`generate_icons.swift`** — Generates `AppIcon.icns` and `MenuBarIcon` PNGs from `icon.svg` using `AppKit` APIs.

- **`icon.svg`** — Source vector asset for all app icons.

## Conventions

- Use `async/await` and `Task` for all asynchronous work — no completion handlers.
- Use `@StateObject` / `@Published` for SwiftUI state management.
- UI uses `.monospaced` system fonts for IP display and a custom `MenuItemButton` component for interactive menu items.
- The menu bar icon is a template image loaded from bundled resources (with SF Symbol fallback).

## Packaging Constraint

The app requires `LSUIElement = 1` in `Info.plist` to hide from the Dock. Swift Package Manager cannot set this, so `build.sh` manually constructs the `.app` bundle structure, writes `Info.plist` after `swift build -c release`, embeds the `Sparkle.framework`, copies icon resources, and modifies the executable's `rpath`. Any new `Info.plist` keys (such as `SUFeedURL` or `SUPublicEDKey`) must be added to `build.sh`. Version strings (`CFBundleShortVersionString`, `CFBundleVersion`) are also injected by the script.

<div align="center">
  <img src="icon.svg" width="128" height="128" alt="NetworkMap Logo">
  
  # NetworkMap
  
  **A clean, beautiful, and ultra-lightweight macOS menu bar app that gives you advanced network information.**
  
  [![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
  [![Swift](https://img.shields.io/badge/Swift-5.7+-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

[Installation](#-how-to-install) • [Features](#-features) • [Development](#-local-development)

</div>

---

## ✨ Features

- **Real-time Monitoring** ⚡️<br/>
  Automatically refreshes your public IP the moment your network connection changes.
- **Ultra-lightweight** 🪶<br/>
  Runs purely as a background accessory app. No Dock icon, no CPU hogging.
- **Native Look & Feel** 🍏<br/>
  Built specifically for macOS with SwiftUI, adhering perfectly to Apple's design guidelines.
- **Auto-Updates** 🔄<br/>
  Powered by [Sparkle](https://sparkle-project.org/), NetworkMap silently stays up-to-date with new releases.

---

## 🚀 How to Install

### Homebrew (Recommended ✨)

The fastest and easiest way to install and keep NetworkMap updated.

```bash
brew install carlosas/networkmap/networkmap
```

### Manual Installation

1. Download the latest `NetworkMap-X.Y.Z.dmg` from the [Releases](https://github.com/carlosas/networkmap/releases) page.
2. Open the DMG and drag **NetworkMap** to your **Applications** folder.
3. Run the following command to bypass the quarantine flag (the app is not notarized by Apple):
   ```bash
   xattr -cr /Applications/NetworkMap.app
   ```
4. Launch the app from your Applications folder! 🎉

---

## 🧭 Usage

- **View IP**: Simply click the logo ( <img src="icon.svg" width="14" height="14" style="vertical-align: middle"> ) in your menu bar to instantly view the network information.
- **Refresh**: Click **Refresh** within the menu (or simply press `⌘ + R`) to manually fetch the network information at any time.
- **Check for Updates**: Easily manually check for new versions from the dropdown.
- **Quit**: Click **Quit** to close the app.

---

## 🛠 Local Development

This application requires **macOS 13.0+** and **Xcode 14.1+**.

### 1. Build and Package

To run correctly on macOS with full menu bar integration, the app must be properly packaged into an `.app` bundle structure with the correct custom `Info.plist`.

Use the provided build script instead of relying on `swift build` directly:

```bash
./build.sh
```

_(Note: The build script automatically executes `generate_icons.swift` to convert `icon.svg` into macOS `.icns` and transparent Menu Bar icons.)_

### 2. Run the App

After building, launch the newly packaged app bundle directly:

```bash
open NetworkMap.app
```

### 3. Architecture Overview

- `Sources/NetworkMap/NetworkMapApp.swift` — The SwiftUI `@main` entry point and Menu Bar configuration logic.
- `Sources/NetworkMap/NetworkManager.swift` — The crucial logic that handles ultra-fast, asynchronous IP fetching and powerful network path monitoring.
- `build.sh` — Automates the entire Swift build, embeds the Sparkle updater framework, injects necessary PLIST configurations (`LSUIElement` to effectively hide the Dock icon), and builds the macOS `.app` bundle.
- `generate_icons.swift` — Swift script that seamlessly compiles `.icns` packages and prepares transparent Menu Bar templates directly from `icon.svg`.

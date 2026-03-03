# NetworkMap 🌐

A clean and modern macOS menu bar app that displays your public IP address in real-time.

## Features

- **Real-time Monitoring:** Automatically refreshes your public IP when your network connection changes.
- **Lightweight:** Runs as a background accessory app with no Dock icon.

## How to Install

### Homebrew (recommended)

```bash
brew install carlosas/networkmap/networkmap
```

### Manual

1. Download the latest `NetworkMap-X.Y.Z.dmg` from the [Releases](https://github.com/carlosas/networkmap/releases) page.
2. Open the DMG and drag **NetworkMap** to the **Applications** folder.
3. Open Terminal and run: `xattr -cr /Applications/NetworkMap.app` (needed because the app is not notarized by Apple).
4. Launch the app from your Applications folder.

## Local Development

### 1. Build and Package

To run correctly on macOS, the app must be packaged into a `.app` bundle. Use the provided build script:

```bash
./build.sh
```

### 2. Run the App

```bash
open NetworkMap.app
```

## Usage

- **View IP:** Click the network icon (🌐) in your menu bar to see your current public IP address.
- **Refresh:** Click **Refresh** (or press `⌘+R`) to manually update the IP.
- **Quit:** Click **Quit** (or press `⌘+Q`) to exit the application.

## Development

This app requires macOS 13.0+ and Xcode 14.1+.

- `Sources/NetworkMap/NetworkMapApp.swift`: SwiftUI entry point and Menu Bar configuration.
- `Sources/NetworkMap/NetworkManager.swift`: Handles asynchronous IP fetching and network path monitoring.
- `build.sh`: Automates the Swift build and creation of the macOS `.app` bundle with the necessary `Info.plist`.

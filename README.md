# NetworkMap 🌐

A clean and modern macOS menu bar app that displays your public IP address.

## Features
- **Real-time Monitoring:** Automatically refreshes when network status changes.
- **Modern UI:** Built with SwiftUI's `MenuBarExtra` for a native, popover-style experience.
- **Lightweight:** Tiny footprint, no dock icon.

## How to Build & Run

### 1. Build the app
```bash
swift build -c release
```

### 2. Run the executable
```bash
./.build/release/NetworkMap
```

### 3. Usage
- Click the network icon in the menu bar to see your public IP.
- Click **Refresh** to manually update.
- Click **Quit** to exit.

## Development
This app uses SwiftUI 13.0+ features. 
- `NetworkManager.swift`: Handles network monitoring and IP fetching.
- `NetworkMapApp.swift`: SwiftUI entry point and Menu Bar Extra configuration.

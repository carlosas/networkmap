<div align="center">
  <img src="icon.svg" width="128" height="128" alt="NetworkMap Logo">
  
  # NetworkMap
  
  **A clean, beautiful, and ultra-lightweight macOS menu bar item that gives you advanced network information.**
  
  [![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
  [![Swift](https://img.shields.io/badge/Swift-5.7+-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

[Installation](#-how-to-install) • [Features](#-features) • [Development](#-local-development)

</div>

---

## ✨ Features

- **Real-time Monitoring** ⚡️<br/>
  Automatically refreshes the information the moment your network connection changes.
- **Ultra-lightweight** 🪶<br/>
  Runs purely as a background accessory app. No Dock icon, no CPU hogging.
- **Native Look & Feel** 🍏<br/>
  Built specifically for macOS with SwiftUI, adhering to Apple's design guidelines.
- **Auto-Updates** 🔄<br/>
  Powered by Sparkle, NetworkMap stays up-to-date with new releases.

---

## 🚀 How to Install

### Homebrew (Recommended ✨)

The fastest and easiest way to install and keep NetworkMap updated:

```bash
brew install carlosas/tap/networkmap
```

That's it! 🎉 Launch the app from your Applications folder.

### Manual Installation

1. Download the latest `NetworkMap-X.Y.Z.dmg` from the [Releases](https://github.com/carlosas/networkmap/releases) page.
2. Open the DMG and drag **NetworkMap** to your **Applications** folder.
3. Run the following command to bypass the quarantine flag (the app is not notarized by Apple):
   ```bash
   xattr -cr /Applications/NetworkMap.app
   ```
4. Launch the app from your Applications folder.

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

## 📝 What's coming next

[x] MAC Vendor Lookup
   We already capture MAC addresses and bundle nmap-mac-prefixes. Show the vendor name (Apple, TP-Link, etc.) instead of "Unknown" — that's the biggest UX gap right now. A device showing "Apple —  
   192.168.1.43" is 10x more useful than "Unknown".

[ ] Click-to-Copy Public IP

Same as device rows — clicking the public IP should copy it to clipboard. That's the #1 reason people check their IP.

[ ] IP Geolocation

Hit a free API (like ip-api.com) and show city/country next to the public IP. Useful for VPN users to confirm their exit node.

[ ] Port Scanning (on demand)

Add a "Scan Ports" option per device (right-click or expand). Run nmap -F (fast top-100 ports) on a selected host. Show open ports inline. Power users want this.

[ ] Device Change Notifications

Track the previous scan result. When a new device appears or disappears, fire a macOS notification. This is a lightweight intrusion detection feature — very hacker-friendly.

[ ] Local IP Display

Show the local/private IP (e.g., 192.168.1.43) alongside the public IP. People often need both.

[ ] Network Interface Info

Show which interface is active (Wi-Fi vs Ethernet), SSID name, link speed. Quick glance diagnostics.

[ ] Latency/Ping per Device

nmap's -sn already measures round-trip time. Parse and display it — helps identify slow/overloaded devices.

[ ] Device Naming / Aliases

Let users assign custom names to MAC addresses (persisted to UserDefaults). "Unknown 192.168.1.1" becomes "Router" permanently.

[ ] Scan History / Timeline

Store scan results with timestamps. Show when a device was first/last seen. Useful for tracking intermittent devices.

[ ] Show IP in Menu Bar

Option to display the public IP directly in the menu bar text (next to the icon). Many network tools do this — saves a click.

[ ] Visual Scan Progress

Replace the spinner with a progress bar or device count ticker during scans.

[ ] Expandable Device Rows

Click a device to expand and show MAC, vendor, ports, first-seen timestamp — rather than cramming everything into the row.

[ ] Search/Filter Devices

For networks with 20+ devices, a quick filter field at the top of the device list.

[ ] Configurable Scan Interval

Let users change the 15-minute auto-scan interval (or disable it entirely).

[ ] Wake-on-LAN

Send WoL magic packets to devices by MAC address. Trivial to implement, very useful for power users.

[ ] ARP Spoofing Detection

Flag duplicate MAC addresses or MAC changes for the same IP — signs of ARP poisoning.

[ ] Rogue Device Alerts

Let users mark "known" devices. Alert on any unknown device joining the network.

[ ] DNS Leak Test

Quick check to see if DNS queries are leaking outside a VPN tunnel.

[ ] Bandwidth Monitor

Use nettop or NetworkStatistics to show per-interface throughput in the menu bar.

---

Technical Debt

- Retry logic for failed nmap scans (exponential backoff)
- Concurrent subnet scanning for multi-homed machines
- UserDefaults/Settings pane for all the configurability above
- Accessibility — VoiceOver labels on all interactive elements
- Notarization — proper code signing so users don't need xattr -cr
- Use `arp`?

---

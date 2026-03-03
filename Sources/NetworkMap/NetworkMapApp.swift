import SwiftUI
import AppKit
import Sparkle

struct MenuItemButton: View {
    let title: String
    let shortcut: String?
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let shortcut {
                Text(shortcut)
                    .font(.body)
                    .foregroundColor(isHovered ? .white : .secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.accentColor : Color.clear)
        )
        .foregroundColor(isHovered ? .white : .primary)
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .onHover { isHovered = $0 }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // This ensures the app doesn't show in the Dock
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct NetworkMapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkManager = NetworkManager()
    private let updaterController: SPUStandardUpdaterController
    private let menuBarIcon: NSImage
    
    init() {
        // Initialize Sparkle Updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Load custom menu bar icon from bundle resources
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            menuBarIcon = image
        } else {
            // Fallback to SF Symbol if resource not found
            menuBarIcon = NSImage(systemSymbolName: "network", accessibilityDescription: "NetworkMap")!
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 0) {
                // --- Information area (unchanged) ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Public IP Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkManager.currentIP)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                }
                .padding()
                
                Divider()
                    .padding(.vertical, 4)
                
                // --- Menu items ---
                VStack(alignment: .leading, spacing: 2) {
                    MenuItemButton("Refresh", shortcut: "⌘R") {
                        Task {
                            await networkManager.fetchPublicIP()
                        }
                    }
                    
                    MenuItemButton("Check for Updates...") {
                        updaterController.checkForUpdates(nil)
                    }
                }
                .padding(.horizontal, 6)
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    MenuItemButton("Quit", shortcut: "⌘Q") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }
            .frame(width: 220)
        } label: {
            Image(nsImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}


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
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .foregroundColor(isHovered ? .white : .secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(isHovered ? Color.accentColor : Color.clear)
            .foregroundColor(isHovered ? .white : .primary)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
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
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            menuBarIcon = image
        } else {
            // Fallback to SF Symbol if resource not found
            menuBarIcon = NSImage(systemSymbolName: "network", accessibilityDescription: "NetworkMap")!
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Public IP Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(networkManager.currentIP)
                    .font(.system(.body, design: .monospaced))
                    .bold()
            }
            .padding()
            .frame(width: 200)
            
            Divider()
            
            MenuItemButton("Refresh", shortcut: "⌘R") {
                Task {
                    await networkManager.fetchPublicIP()
                }
            }
            
            MenuItemButton("Check for Updates...") {
                updaterController.checkForUpdates(nil)
            }
            
            Divider()
            
            MenuItemButton("Quit", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(nsImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

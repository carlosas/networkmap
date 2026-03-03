import SwiftUI
import AppKit
import Sparkle

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
            
            Button("Refresh") {
                Task {
                    await networkManager.fetchPublicIP()
                }
            }
            .keyboardShortcut("R")
            
            Button("Check for Updates...") {
                updaterController.checkForUpdates(nil)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("Q")
        } label: {
            Image(nsImage: menuBarIcon)
        }
    }
}

import SwiftUI
import AppKit

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
    
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Public IP Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(networkManager.currentIP)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                
                Divider()
                
                Button("Refresh") {
                    Task {
                        await networkManager.fetchPublicIP()
                    }
                }
                .keyboardShortcut("R")
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("Q")
            }
            .padding()
            .frame(width: 200)
        } label: {
            HStack {
                Image(systemName: "network")
                Text(networkManager.currentIP)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

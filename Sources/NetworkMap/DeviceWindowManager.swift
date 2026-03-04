import AppKit
import SwiftUI

@MainActor
class DeviceWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    private var panel: NSPanel?

    func showDevice(_ device: NetworkDevice) {
        let hostingView = NSHostingView(rootView: DeviceDetailView(device: device))
        hostingView.setFrameSize(NSSize(width: 340, height: 420))

        if let panel {
            panel.contentView = hostingView
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "Device Details"
        newPanel.isFloatingPanel = true
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.level = .floating
        newPanel.contentView = hostingView
        newPanel.center()
        newPanel.delegate = self
        newPanel.isReleasedWhenClosed = false
        newPanel.makeKeyAndOrderFront(nil)

        panel = newPanel
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            panel = nil
        }
    }
}

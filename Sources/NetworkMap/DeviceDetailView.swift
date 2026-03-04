import SwiftUI

struct DeviceDetailView: View {
    let device: NetworkDevice
    @State private var pingResult: String?

    private var displayName: String {
        device.hostname ?? device.vendor ?? "Unknown"
    }

    private var iconName: String {
        if let name = (device.hostname ?? "").lowercased() as String? {
            if name.contains("router") || name.contains("gateway") { return "wifi.router" }
            if name.contains("iphone") || name.contains("phone") { return "iphone" }
            if name.contains("ipad") || name.contains("tablet") { return "ipad" }
            if name.contains("watch") { return "applewatch" }
            if name.contains("tv") || name.contains("appletv") { return "appletv" }
            if name.contains("macbook") || name.contains("laptop") { return "laptopcomputer" }
            if name.contains("imac") || name.contains("mac") { return "desktopcomputer" }
        }
        return "desktopcomputer"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                    if let vendor = device.vendor, device.hostname != nil {
                        Text(vendor)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()

            Divider()

            // Details
            Form {
                LabeledContent("IP Address") {
                    Text(device.ip)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                if let mac = device.macAddress {
                    LabeledContent("MAC Address") {
                        Text(mac)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                if let vendor = device.vendor {
                    LabeledContent("Vendor") {
                        Text(vendor)
                    }
                }
                if let hostname = device.hostname {
                    LabeledContent("Hostname") {
                        Text(hostname)
                            .textSelection(.enabled)
                    }
                }
                LabeledContent("Ping") {
                    if let pingResult {
                        Text(pingResult)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // Copy IP button
            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(device.ip, forType: .string)
                } label: {
                    Label("Copy IP", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .focusable(false)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .task(id: device.ip) {
            pingResult = nil
            pingResult = await runPing(ip: device.ip)
        }
    }

    private func runPing(ip: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "2", ip]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                // Parse "round-trip min/avg/max/stddev = 1.234/1.234/1.234/0.000 ms"
                if let range = output.range(of: "round-trip") ?? output.range(of: "rtt"),
                   let eqRange = output[range.upperBound...].range(of: "=") {
                    let stats = output[eqRange.upperBound...].trimmingCharacters(in: .whitespaces)
                    let parts = stats.split(separator: "/")
                    if parts.count >= 2 {
                        // avg is the second value
                        continuation.resume(returning: "\(parts[1]) ms")
                        return
                    }
                }
                if process.terminationStatus == 0 {
                    continuation.resume(returning: "OK")
                } else {
                    continuation.resume(returning: "Unreachable")
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: "Error")
            }
        }
    }
}

import Foundation
import Darwin
import Network

struct NetworkDevice: Identifiable, Hashable {
    let id = UUID()
    let ip: String
    let hostname: String?
    let macAddress: String?
    let vendor: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(ip)
    }

    static func == (lhs: NetworkDevice, rhs: NetworkDevice) -> Bool {
        lhs.ip == rhs.ip
    }
}

enum ScanState: Equatable {
    case idle
    case scanning
    case completed(Int)
    case nmapNotFound
    case error(String)
}

private enum ScanError: LocalizedError {
    case nmapFailed(String)

    var errorDescription: String? {
        switch self {
        case .nmapFailed(let msg): return msg
        }
    }
}

@MainActor
class NetworkScanner: ObservableObject {
    @Published var devices: [NetworkDevice] = []
    @Published var scanState: ScanState = .idle
    @Published var isPrivileged: Bool = false

    private static let privilegedDir = "/Library/Application Support/NetworkMap"
    private static let privilegedNmapPath = "/Library/Application Support/NetworkMap/nmap"

    private var timerTask: Task<Void, Never>?

    init() {
        checkPrivileged()
        timerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            await self?.scan()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
                await self?.scan()
            }
        }
    }

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Privilege management

    func checkPrivileged() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.privilegedNmapPath) else {
            isPrivileged = false
            return
        }
        do {
            let attrs = try fm.attributesOfItem(atPath: Self.privilegedNmapPath)
            let perms = (attrs[.posixPermissions] as? Int) ?? 0
            isPrivileged = (perms & 0o4000) != 0
        } catch {
            isPrivileged = false
        }
    }

    @discardableResult
    func requestPrivilegedAccess() async -> Bool {
        guard let bundledDir = Bundle.main.resourceURL?.appendingPathComponent("nmap") else {
            return false
        }
        let dir = Self.privilegedDir
        let source = """
            do shell script "mkdir -p '\(dir)' && cp -R '\(bundledDir.path)/' '\(dir)/' && chown -R root:wheel '\(dir)' && chmod 4755 '\(dir)/nmap'" with administrator privileges
            """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard error == nil else { return false }
        checkPrivileged()
        if isPrivileged {
            await scan()
        }
        return isPrivileged
    }

    @discardableResult
    func revokePrivilegedAccess() async -> Bool {
        let dir = Self.privilegedDir
        let source = """
            do shell script "rm -rf '\(dir)'" with administrator privileges
            """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard error == nil else { return false }
        checkPrivileged()
        return !isPrivileged
    }

    func scan() async {
        guard scanState != .scanning else { return }
        scanState = .scanning

        guard let nmapPath = findNmap() else {
            scanState = .nmapNotFound
            return
        }

        guard let subnet = detectSubnet() else {
            scanState = .error("Could not detect local network")
            return
        }

        do {
            let xmlData = try await runNmap(path: nmapPath, subnet: subnet, dataDir: nmapDataDir())
            let parsed = parseNmapXML(xmlData)
            let arpTable = readArpTable()
            let macPrefixes = loadMacPrefixes()
            let localIP = localIPAddress(from: subnet)
            let gatewayIP = detectGatewayIP()
            let bonjourNames = await BonjourScanner.resolve(timeout: 2.0)

            // Start with nmap-discovered hosts
            let nmapIPs = Set(parsed.map { $0.ip })
            var allDevices = parsed

            // Add devices found in ARP table but missed by nmap
            let subnetPrefix = subnet.components(separatedBy: "/").first ?? ""
            let prefixParts = subnetPrefix.split(separator: ".").dropLast()
            let subnetBase = prefixParts.joined(separator: ".") + "."
            for (ip, mac) in arpTable where !nmapIPs.contains(ip) && ip.hasPrefix(subnetBase) {
                // Skip network address and broadcast address
                guard let lastOctet = ip.split(separator: ".").last.flatMap({ Int($0) }),
                      lastOctet != 0 && lastOctet != 255 else { continue }
                allDevices.append(NetworkDevice(ip: ip, hostname: nil, macAddress: mac, vendor: nil))
            }

            let enriched = allDevices.map { device -> NetworkDevice in
                var hostname = device.hostname
                var mac = device.macAddress
                var vendor = device.vendor

                // Enrich with ARP table if nmap didn't provide MAC
                if mac == nil, let arpMac = arpTable[device.ip] {
                    mac = arpMac
                }

                // OUI vendor lookup from MAC prefix
                if vendor == nil, let mac {
                    vendor = lookupVendor(mac: mac, prefixes: macPrefixes)
                }

                // Bonjour name lookup
                if hostname == nil, let bonjourName = bonjourNames[device.ip] {
                    hostname = bonjourName
                }

                // Identify local machine
                if hostname == nil, device.ip == localIP {
                    hostname = Host.current().localizedName
                }

                // Identify gateway/router
                if hostname == nil, device.ip == gatewayIP {
                    hostname = "Router"
                }

                return NetworkDevice(ip: device.ip, hostname: hostname, macAddress: mac, vendor: vendor)
            }
            devices = enriched.sorted { compareIPs($0.ip, $1.ip) }
            scanState = .completed(devices.count)
        } catch {
            scanState = .error(error.localizedDescription)
        }
        checkPrivileged()
    }

    // MARK: - Find nmap binary

    private func findNmap() -> String? {
        // Prefer privileged (setuid) copy if available
        if isPrivileged, FileManager.default.isExecutableFile(atPath: Self.privilegedNmapPath) {
            return Self.privilegedNmapPath
        }
        // Bundled nmap inside the app bundle
        if let bundledDir = Bundle.main.resourceURL?.appendingPathComponent("nmap") {
            let bundledPath = bundledDir.appendingPathComponent("nmap").path
            if FileManager.default.isExecutableFile(atPath: bundledPath) {
                return bundledPath
            }
        }
        // Fallback to system-installed nmap
        let candidates = [
            "/opt/homebrew/bin/nmap",
            "/usr/local/bin/nmap",
            "/opt/local/bin/nmap"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Returns the nmap data directory (privileged copy or bundled).
    private func nmapDataDir() -> String? {
        if isPrivileged, FileManager.default.fileExists(atPath: Self.privilegedDir) {
            return Self.privilegedDir
        }
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("nmap") else { return nil }
        return FileManager.default.fileExists(atPath: dir.path) ? dir.path : nil
    }

    // MARK: - Detect local subnet

    private nonisolated func detectSubnet() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name != "lo0" else { continue }

            // Extract IP address
            var addr = interface.ifa_addr.pointee
            var ipBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(&addr, socklen_t(addr.sa_len),
                        &ipBuffer, socklen_t(ipBuffer.count),
                        nil, 0, NI_NUMERICHOST)
            let ip = String(cString: ipBuffer)

            // Skip link-local addresses
            guard !ip.hasPrefix("169.254.") else { continue }

            // Extract netmask
            var mask = interface.ifa_netmask.pointee
            var maskBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(&mask, socklen_t(mask.sa_len),
                        &maskBuffer, socklen_t(maskBuffer.count),
                        nil, 0, NI_NUMERICHOST)
            let netmask = String(cString: maskBuffer)

            let cidr = netmaskToCIDR(netmask)
            let networkAddress = calculateNetworkAddress(ip: ip, netmask: netmask)
            return "\(networkAddress)/\(cidr)"
        }
        return nil
    }

    private nonisolated func netmaskToCIDR(_ netmask: String) -> Int {
        netmask.split(separator: ".").compactMap { UInt8($0) }.reduce(0) { total, octet in
            total + octet.nonzeroBitCount
        }
    }

    private nonisolated func calculateNetworkAddress(ip: String, netmask: String) -> String {
        let ipParts = ip.split(separator: ".").compactMap { UInt8($0) }
        let maskParts = netmask.split(separator: ".").compactMap { UInt8($0) }
        guard ipParts.count == 4, maskParts.count == 4 else { return ip }
        return zip(ipParts, maskParts).map { String($0 & $1) }.joined(separator: ".")
    }

    // MARK: - Run nmap process

    private nonisolated func runNmap(path: String, subnet: String, dataDir: String?) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            var args = ["-sn", "--system-dns", "-oX", "-"]
            if let dataDir {
                args += ["--datadir", dataDir]
            }
            args.append(subnet)
            process.arguments = args

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { _ in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: outData)
                } else {
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nmap failed"
                    continuation.resume(throwing: ScanError.nmapFailed(errStr))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parse nmap XML output

    private nonisolated func parseNmapXML(_ data: Data) -> [NetworkDevice] {
        let delegate = NmapXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.devices
    }

    // MARK: - Local and gateway identification

    /// Extracts the local IP address from the subnet string (re-reads interfaces).
    private nonisolated func localIPAddress(from subnet: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name != "lo0" else { continue }
            var addr = interface.ifa_addr.pointee
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(&addr, socklen_t(addr.sa_len), &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: buf)
            guard !ip.hasPrefix("169.254.") else { continue }
            return ip
        }
        return nil
    }

    /// Detects the default gateway IP via `route`.
    private nonisolated func detectGatewayIP() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("gateway:") {
                return trimmed.replacingOccurrences(of: "gateway:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - ARP table and vendor lookup

    /// Reads the system ARP table to get IP → MAC mappings.
    private nonisolated func readArpTable() -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-a"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return [:] }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        // Format: "? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ..."
        var table: [String: String] = [:]
        for line in output.components(separatedBy: "\n") {
            guard let ipStart = line.firstIndex(of: "("),
                  let ipEnd = line.firstIndex(of: ")"),
                  ipStart < ipEnd else { continue }
            let ip = String(line[line.index(after: ipStart)..<ipEnd])
            guard let atRange = line.range(of: " at ") else { continue }
            let afterAt = line[atRange.upperBound...]
            let mac = String(afterAt.prefix(while: { $0 != " " }))
            guard mac != "(incomplete)" else { continue }
            table[ip] = mac
        }
        return table
    }

    /// Loads the nmap OUI prefix database (MAC prefix → vendor name).
    private nonisolated func loadMacPrefixes() -> [String: String] {
        // Try bundled nmap data dir first, then common system locations
        let candidates: [String] = {
            var paths: [String] = []
            if let dir = Bundle.main.resourceURL?.appendingPathComponent("nmap") {
                paths.append(dir.appendingPathComponent("nmap-mac-prefixes").path)
            }
            paths += [
                "/opt/homebrew/share/nmap/nmap-mac-prefixes",
                "/usr/local/share/nmap/nmap-mac-prefixes",
                "/usr/share/nmap/nmap-mac-prefixes"
            ]
            return paths
        }()

        for path in candidates {
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            var prefixes: [String: String] = [:]
            for line in contents.components(separatedBy: "\n") {
                guard !line.hasPrefix("#"), !line.isEmpty else { continue }
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { continue }
                prefixes[String(parts[0]).uppercased()] = String(parts[1])
            }
            return prefixes
        }
        return [:]
    }

    /// Looks up the vendor name for a MAC address using the OUI prefix table.
    private nonisolated func lookupVendor(mac: String, prefixes: [String: String]) -> String? {
        // Normalize MAC: remove colons/hyphens, uppercase, take first 6 chars (OUI)
        let normalized = mac.replacingOccurrences(of: ":", with: "")
                           .replacingOccurrences(of: "-", with: "")
                           .uppercased()
        guard normalized.count >= 6 else { return nil }
        let oui = String(normalized.prefix(6))
        return prefixes[oui]
    }

    // MARK: - IP comparison

    private func compareIPs(_ a: String, _ b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for (ap, bp) in zip(aParts, bParts) {
            if ap != bp { return ap < bp }
        }
        return false
    }
}

// MARK: - XML Parser Delegate

private class NmapXMLDelegate: NSObject, XMLParserDelegate {
    var devices: [NetworkDevice] = []
    private var inHost = false
    private var hostIsUp = false
    private var currentIP: String?
    private var currentMAC: String?
    private var currentVendor: String?
    private var currentHostname: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "host":
            inHost = true
            hostIsUp = false
            currentIP = nil
            currentMAC = nil
            currentVendor = nil
            currentHostname = nil
        case "status" where inHost:
            hostIsUp = attributeDict["state"] == "up"
        case "address" where inHost:
            if attributeDict["addrtype"] == "ipv4" {
                currentIP = attributeDict["addr"]
            } else if attributeDict["addrtype"] == "mac" {
                currentMAC = attributeDict["addr"]
                currentVendor = attributeDict["vendor"]
            }
        case "hostname" where inHost:
            if currentHostname == nil {
                currentHostname = attributeDict["name"]
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if elementName == "host" {
            if let ip = currentIP, hostIsUp {
                devices.append(NetworkDevice(ip: ip, hostname: currentHostname, macAddress: currentMAC, vendor: currentVendor))
            }
            inHost = false
        }
    }
}

// MARK: - Bonjour Service Discovery

private enum BonjourScanner {
    /// Service types that commonly reveal device names.
    private static let serviceTypes = [
        "_companion-link._tcp",
        "_airplay._tcp",
        "_raop._tcp",
        "_googlecast._tcp",
        "_hap._tcp",
        "_smb._tcp",
        "_rfb._tcp",
        "_printer._tcp",
        "_ipp._tcp",
    ]

    private final class ResultCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: String] = [:]

        func set(_ name: String, for ip: String) {
            lock.lock()
            if storage[ip] == nil { storage[ip] = name }
            lock.unlock()
        }

        var results: [String: String] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    /// Browses Bonjour services and returns a mapping of IP → friendly device name.
    static func resolve(timeout: TimeInterval) async -> [String: String] {
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "bonjour", attributes: .concurrent)
            let collector = ResultCollector()
            var browsers: [NWBrowser] = []

            for type in serviceTypes {
                group.enter()
                let params = NWParameters()
                params.includePeerToPeer = true
                let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: params)
                browsers.append(browser)

                browser.browseResultsChangedHandler = { newResults, _ in
                    for result in newResults {
                        if case .service(let name, _, _, _) = result.endpoint {
                            // Resolve the endpoint to get the IP
                            let connection = NWConnection(to: result.endpoint, using: .tcp)
                            connection.stateUpdateHandler = { state in
                                if case .ready = state,
                                   let path = connection.currentPath,
                                   let endpoint = path.remoteEndpoint,
                                   case .hostPort(let host, _) = endpoint {
                                    let ip: String?
                                    switch host {
                                    case .ipv4(let addr):
                                        ip = "\(addr)"
                                    case .ipv6(let addr):
                                        let s = "\(addr)"
                                        // Extract IPv4-mapped IPv6 (::ffff:a.b.c.d)
                                        if s.hasPrefix("::ffff:") {
                                            ip = String(s.dropFirst(7))
                                        } else {
                                            ip = nil
                                        }
                                    default:
                                        ip = nil
                                    }
                                    if let ip {
                                        collector.set(name, for: ip)
                                    }
                                    connection.cancel()
                                }
                                if case .failed = state { connection.cancel() }
                                if case .cancelled = state { /* done */ }
                            }
                            connection.start(queue: queue)
                        }
                    }
                }
                browser.stateUpdateHandler = { state in
                    if case .failed = state { group.leave() }
                }
                browser.start(queue: queue)
            }

            // Wait for the timeout, then collect results
            queue.asyncAfter(deadline: .now() + timeout) {
                for browser in browsers {
                    browser.cancel()
                }
                for _ in serviceTypes { group.leave() }
                continuation.resume(returning: collector.results)
            }
        }
    }
}

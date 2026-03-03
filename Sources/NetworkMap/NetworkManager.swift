import Foundation
import Network

@MainActor
class NetworkManager: ObservableObject {
    @Published var currentIP: String = "Fetching..."
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] _ in
            Task {
                await self?.fetchPublicIP()
            }
        }
        monitor.start(queue: queue)
        
        Task {
            await fetchPublicIP()
        }
    }

    func fetchPublicIP() async {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ipString = String(data: data, encoding: .utf8) {
                self.currentIP = ipString
            }
        } catch {
            self.currentIP = "Offline"
        }
    }
}

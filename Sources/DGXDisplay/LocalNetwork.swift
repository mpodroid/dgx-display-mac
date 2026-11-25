import AppKit
import Network

/// Opens a TCP connection in this process so macOS can show the Local Network
/// prompt. A short-lived `ssh` child is not enough: the system drops that
/// prompt and `connect` fails with "No route to host".
final class LocalNetworkProbe {
    private var connection: NWConnection?
    private var armedHost: String?
    var onGranted: (() -> Void)?

    func arm(_ host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != armedHost || connection == nil else { return }
        armedHost = trimmed
        connection?.cancel()

        let connection = NWConnection(host: NWEndpoint.Host(trimmed), port: 22, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            self?.observe(state, connection)
        }
        connection.start(queue: .main)
    }

    private func observe(_ state: NWConnection.State, _ connection: NWConnection) {
        switch state {
        case .ready:
            finish(connection)
            onGranted?()
        case .waiting:
            if case .localNetworkDenied? = connection.currentPath?.unsatisfiedReason {
                NSApp.activate()
            }
        case .failed:
            finish(connection)
        case .cancelled, .setup, .preparing:
            break
        @unknown default:
            break
        }
    }

    private func finish(_ connection: NWConnection) {
        connection.cancel()
        if self.connection === connection {
            self.connection = nil
        }
    }
}

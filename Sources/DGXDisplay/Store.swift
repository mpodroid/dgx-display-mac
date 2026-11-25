import DGXDisplayCore
import Foundation

@MainActor
final class Store: ObservableObject {
    @Published var sample: Sample?
    @Published var page: PanelPage = .face
    @Published var iopsHistory: [Int] = []
    @Published var host: String
    @Published var user: String
    @Published var identity: String
    @Published var running = false
    @Published var trouble: String?

    private(set) var sessionStarted: Date?
    private var epoch = 0

    var onLive: (() -> Void)?
    var onCommit: ((SSHLaunch) -> Void)?

    init(defaults: UserDefaults = .standard) {
        host = defaults.string(forKey: Key.host) ?? SSHLaunch.defaultHost
        user = defaults.string(forKey: Key.user) ?? SSHLaunch.defaultUser
        identity = defaults.string(forKey: Key.identity) ?? SSHLaunch.defaultIdentity
    }

    var launch: SSHLaunch {
        SSHLaunch(
            user: user.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            identityPath: expandTilde(identity.trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    func armClock() {
        if sessionStarted == nil {
            sessionStarted = Date()
        }
    }

    func face(at now: Date) -> Face {
        let age = sessionStarted.map { now.timeIntervalSince($0) }
        return Face.resolve(sample: sample, now: now, sessionAge: age)
    }

    func statusLine(at now: Date) -> String {
        if let sample {
            let age = now.timeIntervalSince(sample.receivedAt)
            if age > Face.wedgeSeconds {
                if !running, let trouble, !trouble.isEmpty { return trouble }
                return "No sample for \(Int(age))s"
            }
            if running { return sample.host }
        } else if running, let started = sessionStarted, now.timeIntervalSince(started) > Face.wedgeSeconds {
            return "No sample for \(Int(now.timeIntervalSince(started)))s"
        }
        if let trouble, !trouble.isEmpty { return trouble }
        return "Connecting"
    }

    func advance() {
        page = page.next
    }

    func setLink(gen: Int, trouble: String?, running: Bool) {
        guard gen >= epoch else { return }
        epoch = gen
        self.running = running
        self.trouble = trouble
    }

    func resetForNewTarget(gen: Int) {
        guard gen >= epoch else { return }
        epoch = gen
        sample = nil
        iopsHistory = []
        sessionStarted = Date()
        running = false
        trouble = "Connecting"
    }

    func ingest(gen: Int, line: String) {
        guard gen >= epoch, let parsed = parseSS1(line) else { return }
        epoch = gen
        if sessionStarted == nil {
            sessionStarted = Date()
        }
        sample = parsed
        running = true
        trouble = nil
        let point = parsed.readIOPS.map { Int($0.rounded()) } ?? 0
        iopsHistory.append(point)
        if iopsHistory.count > 60 {
            iopsHistory.removeFirst(iopsHistory.count - 60)
        }
        onLive?()
    }

    func commitConnection(defaults: UserDefaults = .standard) {
        if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            host = SSHLaunch.defaultHost
        }
        if user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            user = SSHLaunch.defaultUser
        }
        if identity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            identity = SSHLaunch.defaultIdentity
        }
        defaults.set(host, forKey: Key.host)
        defaults.set(user, forKey: Key.user)
        defaults.set(identity, forKey: Key.identity)
        onCommit?(launch)
    }

    private enum Key {
        static let host = "host"
        static let user = "user"
        static let identity = "identity"
    }
}

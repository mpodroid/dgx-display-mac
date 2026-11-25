import Foundation

/// One long-lived SSH process. The remote command reads the service feed.
/// It does not sample and it does not open the panel device.
public struct SSHLaunch: Equatable, Sendable {
    public static let defaultHost = "spark-b1fa.local"
    public static let defaultUser = "admin"
    public static let remoteCommand = "/usr/bin/dgx-display-writer --follow"

    public var user: String
    public var host: String
    public var identityPath: String

    public init(user: String, host: String, identityPath: String) {
        self.user = user
        self.host = host
        self.identityPath = identityPath
    }

    public static var defaultIdentity: String {
        expandTilde("~/Library/Application Support/NVIDIA/Sync/config/nvsync.key")
    }

    public var arguments: [String] {
        [
            "-4",
            "-o", "BatchMode=yes",
            "-o", "IdentitiesOnly=yes",
            "-o", "PasswordAuthentication=no",
            "-o", "KbdInteractiveAuthentication=no",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2",
            "-o", "StrictHostKeyChecking=accept-new",
            "-i", identityPath,
            "\(user)@\(host)",
            Self.remoteCommand,
        ]
    }
}

/// macOS reports a Local Network denial as "No route to host".
public func sshTrouble(_ line: String) -> String {
    if line.range(of: "no route to host", options: .caseInsensitive) != nil {
        return "No route to host. Allow Local Network for DGX Display."
    }
    return line
}

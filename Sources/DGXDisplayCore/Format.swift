import Foundation

private let posix = Locale(identifier: "en_US_POSIX")

/// Gauge full-scale values used by the front panel.
public enum Scale {
    public static let decode: Double = 100
    public static let prefill: Double = 2000
    public static let mgmtBytes: Double = 10_000_000
    public static let rdmaBytes: Double = 1_000_000_000
    public static let iops: Double = 100_000
    public static let awaitMS: Double = 50
    public static let diskPSI: Double = 100
    public static let memPSI: Double = 50
    public static let cacheGiB: Double = 10
    public static let iopsAmber: Double = 50_000
    public static let iopsRed: Double = 80_000
    public static let awaitAmber: Double = 20
    public static let awaitRed: Double = 50
    public static let psiAmber: Double = 5
    public static let psiRed: Double = 20
}

public func clamp01(_ value: Double) -> Double {
    min(1, max(0, value))
}

public func formatRate(_ bytesPerSecond: Double?) -> String {
    guard let bytesPerSecond, bytesPerSecond >= 0 else { return "--" }
    if bytesPerSecond >= 1_000_000_000 {
        return String(format: "%.1fG/s", locale: posix, bytesPerSecond / 1_000_000_000)
    }
    if bytesPerSecond >= 1_000_000 {
        return String(format: "%.1fM/s", locale: posix, bytesPerSecond / 1_000_000)
    }
    if bytesPerSecond >= 1_000 {
        return String(format: "%.1fk/s", locale: posix, bytesPerSecond / 1_000)
    }
    return String(format: "%.0fB/s", locale: posix, bytesPerSecond)
}

public func formatCount(_ count: Double?) -> String {
    guard let count, count >= 0 else { return "--" }
    if count >= 1_000_000 {
        return String(format: "%.1fM", locale: posix, count / 1_000_000)
    }
    if count >= 1_000 {
        return String(format: "%.0fk", locale: posix, count / 1_000)
    }
    return String(format: "%.0f", locale: posix, count)
}

public func formatGiB(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.1fG", locale: posix, value)
}

public func formatMiB(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.0fM", locale: posix, value)
}

public func formatTemp(_ celsius: Double?) -> String {
    guard let celsius else { return "--" }
    return String(format: "%.0f°", locale: posix, celsius)
}

public func formatFixed(_ value: Double?, decimals: Int) -> String {
    guard let value else { return "--" }
    return String(format: "%.\(decimals)f", locale: posix, value)
}

public func formatTokens(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.0f", locale: posix, value.rounded())
}

/// Menu-bar count. Thousands stay whole so 1480 is not rounded to 1k.
public func formatMenuCount(_ count: Double) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", locale: posix, count / 1_000_000)
    }
    if count >= 10_000 {
        return String(format: "%.0fk", locale: posix, count / 1_000)
    }
    return String(format: "%.0f", locale: posix, count.rounded())
}

/// Hours, minutes, and seconds the way the panel prints an age (`formatEta`).
public func formatDuration(_ seconds: Int?) -> String {
    guard let seconds, seconds >= 0 else { return "--" }
    if seconds >= 3600 {
        return String(format: "%dh%02dm", locale: posix, seconds / 3600, (seconds % 3600) / 60)
    }
    if seconds >= 60 {
        return String(format: "%dm%02ds", locale: posix, seconds / 60, seconds % 60)
    }
    return String(format: "%ds", locale: posix, seconds)
}

public func expandTilde(_ path: String) -> String {
    if path == "~" {
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
    if path.hasPrefix("~/") {
        let rest = path.dropFirst(2)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(String(rest)).path
    }
    return path
}

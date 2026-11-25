import Foundation

/// Panel palette from the front-panel firmware (`rgb(...)` in main.cpp).
public struct RGB: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let dim = RGB(r: 120, g: 120, b: 120)
    public static let boot = RGB(r: 255, g: 170, b: 40)
    public static let up = RGB(r: 70, g: 170, b: 255)
    public static let serve = RGB(r: 40, g: 210, b: 120)
    public static let wedge = RGB(r: 255, g: 50, b: 50)
    public static let stall = RGB(r: 255, g: 150, b: 0)
    public static let idle = RGB(r: 90, g: 160, b: 220)
    public static let halt = RGB(r: 150, g: 150, b: 150)
    public static let white = RGB(r: 255, g: 255, b: 255)
}

/// Face the firmware computes in `currentMode`. The order of the checks is the behavior.
public enum Face: String, Equatable, Sendable {
    case boot
    case up
    case idle
    case serve
    case stall
    case load
    case down
    case wedge
    case halt

    public static let wedgeSeconds: TimeInterval = 5

    public var word: String {
        switch self {
        case .boot: "BOOT"
        case .up: "UP"
        case .idle: "IDLE"
        case .serve: "SERVE"
        case .stall: "STALL"
        case .load: "LOAD"
        case .down: "DOWN"
        case .wedge: "WEDGE"
        case .halt: "HALT"
        }
    }

    public var rgb: RGB {
        switch self {
        case .boot, .load: .boot
        case .up: .up
        case .idle: .idle
        case .serve: .serve
        case .stall: .stall
        case .down, .wedge: .wedge
        case .halt: .halt
        }
    }

    /// `sessionAge` is how long the SSH attempt has been running with no sample yet.
    /// A missing sample stays Boot until that age passes five seconds, then Wedge.
    public static func resolve(sample: Sample?, now: Date, sessionAge: TimeInterval?) -> Face {
        guard let sample else {
            if let sessionAge, sessionAge > wedgeSeconds {
                return .wedge
            }
            return .boot
        }
        if sample.state == "halt" {
            return .halt
        }
        if now.timeIntervalSince(sample.receivedAt) > wedgeSeconds {
            return .wedge
        }
        if sample.loading {
            return .load
        }
        if !sample.stall.isEmpty, let stallSeconds = sample.stallSeconds, stallSeconds >= 5 {
            return .stall
        }
        if sample.engineOK == false {
            return sample.role == "head" ? .down : .up
        }
        if sample.role == "worker" {
            return .up
        }
        if (sample.decodeTPS ?? 0) > 0 || (sample.prefillTPS ?? 0) > 0 {
            return .serve
        }
        return .idle
    }
}

public enum PanelPage: CaseIterable, Hashable, Sendable {
    case face
    case service
    case disk
    case network
    case memory
    case cluster

    public var title: String {
        switch self {
        case .face: "Face"
        case .service: "Service"
        case .disk: "Disk"
        case .network: "Network"
        case .memory: "Memory"
        case .cluster: "Cluster"
        }
    }

    public var next: PanelPage {
        let pages = Self.allCases
        let index = pages.firstIndex(of: self) ?? 0
        return pages[(index + 1) % pages.count]
    }
}

public func temperatureColor(_ celsius: Double) -> RGB {
    if celsius >= 90 { return .wedge }
    if celsius >= 80 { return .stall }
    return .serve
}

public func oomColor(_ memGiB: Double?) -> RGB {
    guard let memGiB else { return .dim }
    if memGiB < 2 { return .wedge }
    if memGiB < 5 { return .stall }
    return .serve
}

public func memoryUsedColor(used: Double, total: Double) -> RGB {
    guard total > 0 else { return .dim }
    let fraction = used / total
    if fraction >= 0.95 { return .wedge }
    if fraction >= 0.85 { return .stall }
    return .serve
}

public func severityColor(_ value: Double, amber: Double, red: Double) -> RGB {
    if value >= red { return .wedge }
    if value >= amber { return .stall }
    return .serve
}

public extension Sample {
    var queue: Int { (waiting ?? 0) + (connections ?? 0) }

    var pairWord: String {
        if pairBroken == true { return "BROKEN" }
        if pairStalled == true { return "STALL" }
        if pairStalled != nil || pairBroken != nil { return "OK" }
        return "--"
    }

    var pairColor: RGB {
        if pairBroken == true { return .wedge }
        if pairStalled == true { return .stall }
        if pairStalled != nil || pairBroken != nil { return .serve }
        return .dim
    }

    /// A RoCE link that is not up forces the pair line to wedge red.
    var linkColor: RGB {
        if roce0 != "up" || roce1 != "up" { return .wedge }
        return pairColor
    }

    var stallWord: String {
        switch stall {
        case "disk": "DISK"
        case "mem": "MEM"
        case "fabric": "FABRIC"
        case "engine": "ENGINE"
        case "thermal": "THERMAL"
        default: "STALL"
        }
    }

    var localIsHead: Bool { role == "head" }

    func decodeOpacity(at now: Date) -> Double {
        rateOpacity(present: decodeTPS != nil, reportedAge: decodeAgeS ?? 0, now: now, solid: 7, fade: 3)
    }

    func prefillOpacity(at now: Date) -> Double {
        rateOpacity(present: prefillTPS != nil, reportedAge: prefillAgeS ?? 0, now: now, solid: 2, fade: 2)
    }

    private func rateOpacity(present: Bool, reportedAge: Double, now: Date, solid: Double, fade: Double) -> Double {
        guard present else { return 0 }
        let age = reportedAge + now.timeIntervalSince(receivedAt)
        if age <= solid { return 1 }
        if age >= solid + fade { return 0 }
        return (solid + fade - age) / fade
    }
}

import CoreFoundation
import Foundation

/// One `SS1` sample. Missing JSON keys stay nil. Negative rates are dropped,
/// matching the firmware, which treats them as absent.
public struct Sample: Equatable, Sendable {
    public var receivedAt: Date
    public var host: String
    public var model: String
    public var state: String
    public var role: String
    public var stall: String
    public var phase: String
    public var loading: Bool
    public var engineOK: Bool?
    public var pairStalled: Bool?
    public var pairBroken: Bool?
    public var waiting: Int?
    public var connections: Int?
    public var stallSeconds: Int?
    public var idleSeconds: Int?
    public var percent: Int?
    public var etaSeconds: Int?
    public var roce0: String
    public var roce1: String
    public var net: String
    public var ip: String?
    public var gateway: String?
    public var mgmtRX: Double?
    public var mgmtTX: Double?
    public var roceRX: Double?
    public var roceTX: Double?
    public var mgmtErrors: Int?
    public var diskDevice: String?
    public var diskRead: Double?
    public var diskWrite: Double?
    public var readIOPS: Double?
    public var writeIOPS: Double?
    public var awaitMS: Double?
    public var util: Double?
    public var diskPSI: Double?
    public var diskPSIFull: Double?
    public var cacheGiB: Double?
    public var swapMiB: Double?
    public var swapTotalMiB: Double?
    public var swapIn: Double?
    public var swapOut: Double?
    public var majorFaults: Int?
    public var memTotalGiB: Double?
    public var memUsedGiB: Double?
    public var memPSI: Double?
    public var gpuC: Double?
    public var socC: Double?
    public var cpuC: Double?
    public var memGiB: Double?
    public var decodeTPS: Double?
    public var decodeAgeS: Double?
    public var prefillTPS: Double?
    public var prefillAgeS: Double?

    public var headlineTemperature: Double? { socC ?? gpuC }
}

public func parseSS1(_ line: String, receivedAt: Date = Date()) -> Sample? {
    var text = line
    if text.hasSuffix("\r") {
        text.removeLast()
    }
    while text.last?.isWhitespace == true {
        text.removeLast()
    }
    guard text.hasPrefix("SS1 ") else { return nil }
    let payload = text.dropFirst(4)
    guard let data = payload.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return nil
    }
    return Sample(json: object, receivedAt: receivedAt)
}

extension Sample {
    fileprivate init(json: [String: Any], receivedAt: Date) {
        func number(_ key: String) -> Double? {
            guard let value = json[key], !(value is NSNull) else { return nil }
            guard let number = value as? NSNumber else { return nil }
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let decoded = number.doubleValue
            if !decoded.isFinite { return nil }
            return decoded
        }

        func rate(_ key: String) -> Double? {
            guard let value = number(key), value >= 0 else { return nil }
            return value
        }

        func count(_ key: String) -> Int? {
            guard let value = number(key) else { return nil }
            if value < 0 { return 0 }
            return Int(value)
        }

        func text(_ key: String, default fallback: String) -> String {
            json[key] as? String ?? fallback
        }

        func flag(_ key: String) -> Bool? {
            guard let value = json[key], !(value is NSNull) else { return nil }
            guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                return nil
            }
            return number.boolValue
        }

        self.receivedAt = receivedAt
        host = text("host", default: "spark")
        model = text("model", default: "")
        state = text("state", default: "up")
        role = text("role", default: "")
        stall = text("stall", default: "")
        phase = text("phase", default: "")
        loading = flag("loading") ?? false
        engineOK = flag("engine_ok")
        pairStalled = flag("pair_stalled")
        pairBroken = flag("pair_broken")
        waiting = count("waiting")
        connections = count("connections")
        stallSeconds = count("stall_s")
        idleSeconds = count("idle_s")
        if let raw = count("pct") {
            percent = min(100, max(0, raw))
        } else {
            percent = nil
        }
        if let raw = number("eta_s"), raw >= 0 {
            etaSeconds = Int(raw)
        } else {
            etaSeconds = nil
        }
        if let links = json["roce"] as? [Any] {
            roce0 = (links.count > 0 ? links[0] as? String : nil) ?? "down"
            roce1 = (links.count > 1 ? links[1] as? String : nil) ?? "down"
        } else {
            roce0 = "down"
            roce1 = "down"
        }
        net = text("net", default: "")
        let ipText = text("ip", default: "")
        ip = ipText.isEmpty ? nil : ipText
        let gwText = text("gw", default: "")
        gateway = gwText.isEmpty ? nil : gwText
        mgmtRX = rate("mgmt_rx")
        mgmtTX = rate("mgmt_tx")
        roceRX = rate("roce_rx")
        roceTX = rate("roce_tx")
        mgmtErrors = count("mgmt_err")
        let device = text("ddev", default: "")
        diskDevice = device.isEmpty ? nil : device
        diskRead = rate("dr")
        diskWrite = rate("dw")
        readIOPS = rate("dri")
        writeIOPS = rate("dwi")
        awaitMS = rate("daw")
        util = rate("dut")
        diskPSI = rate("dps")
        diskPSIFull = rate("dpf")
        cacheGiB = rate("dcache")
        swapMiB = rate("dswap")
        swapTotalMiB = rate("dswtotal")
        swapIn = rate("dswin")
        swapOut = rate("dswout")
        majorFaults = count("dmaj")
        memTotalGiB = rate("mtot")
        memUsedGiB = rate("mused")
        memPSI = rate("dpm")
        gpuC = rate("gpu_c")
        socC = rate("soc_c")
        cpuC = rate("cpu_c")
        memGiB = rate("mem_gib")
        decodeTPS = rate("decode_tps")
        decodeAgeS = rate("decode_age_s")
        prefillTPS = rate("prefill_tps")
        prefillAgeS = rate("prefill_age_s")
    }
}

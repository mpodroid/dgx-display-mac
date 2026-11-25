import DGXDisplayCore
import SwiftUI

struct FacePage: View {
    var sample: Sample?
    var face: Face
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(face.word)
                    .mono(34, weight: .semibold)
                    .foregroundStyle(Color(face.rgb))
                Spacer()
                if let role = sample?.role, !role.isEmpty {
                    Text(role)
                        .mono(12)
                        .foregroundStyle(Color(RGB.dim))
                }
            }
            Text(sample?.model.isEmpty == false ? sample!.model : "idle")
                .mono(13)
                .foregroundStyle(Color.white)
                .lineLimit(2)
            center
            temperatures
        }
    }

    @ViewBuilder
    private var center: some View {
        switch face {
        case .serve:
            VStack(alignment: .leading, spacing: 8) {
                rateLine(
                    "Decode",
                    tokens: sample?.decodeTPS,
                    opacity: sample?.decodeOpacity(at: now) ?? 0,
                    fraction: (sample?.decodeTPS ?? 0) / Scale.decode,
                    color: .serve
                )
                rateLine(
                    "Prefill",
                    tokens: sample?.prefillTPS,
                    opacity: sample?.prefillOpacity(at: now) ?? 0,
                    fraction: (sample?.prefillTPS ?? 0) / Scale.prefill,
                    color: .up
                )
                queueLine
            }
        case .idle:
            VStack(alignment: .leading, spacing: 6) {
                Text("0")
                    .mono(28, weight: .semibold)
                    .foregroundStyle(Color.white)
                Text(formatDuration(sample?.idleSeconds))
                    .mono(13)
                    .foregroundStyle(Color(RGB.dim))
            }
        case .stall:
            VStack(alignment: .leading, spacing: 6) {
                Text(sample?.stallWord ?? "STALL")
                    .mono(22, weight: .semibold)
                    .foregroundStyle(Color(RGB.stall))
                Text(stallEvidence)
                    .mono(13)
                    .foregroundStyle(Color.white)
                Text(formatDuration(sample?.stallSeconds))
                    .mono(12)
                    .foregroundStyle(Color(RGB.dim))
            }
        case .load:
            VStack(alignment: .leading, spacing: 8) {
                Text(loadLine)
                    .mono(18, weight: .semibold)
                    .foregroundStyle(Color(RGB.boot))
                Meter(fraction: Double(sample?.percent ?? 0) / 100, color: .boot)
            }
        case .down:
            Text("Engine down")
                .mono(18, weight: .semibold)
                .foregroundStyle(Color(RGB.wedge))
        case .wedge:
            Text("No sample")
                .mono(16)
                .foregroundStyle(Color(RGB.wedge))
        case .halt:
            Text("Halted")
                .mono(18, weight: .semibold)
                .foregroundStyle(Color(RGB.halt))
        case .boot:
            Text("Connecting")
                .mono(16)
                .foregroundStyle(Color(RGB.boot))
        case .up:
            Text("Up")
                .mono(18, weight: .semibold)
                .foregroundStyle(Color(RGB.up))
        }
    }

    private var temperatures: some View {
        HStack(spacing: 14) {
            temp("SoC", sample?.socC)
            temp("GPU", sample?.gpuC)
            temp("CPU", sample?.cpuC)
            Spacer()
            if let mem = sample?.memGiB {
                Text(formatGiB(mem))
                    .mono(12)
                    .foregroundStyle(Color(oomColor(mem)))
            }
        }
    }

    private func temp(_ label: String, _ value: Double?) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(Color(RGB.dim))
            Text(formatTemp(value))
                .foregroundStyle(Color(value.map(temperatureColor) ?? .dim))
        }
        .mono(12)
    }

    private var queueLine: some View {
        HStack(spacing: 8) {
            QueueDots(count: sample?.queue ?? 0)
            Text("\(sample?.queue ?? 0)")
                .mono(12)
                .foregroundStyle(Color(RGB.dim))
        }
    }

    private func rateLine(_ label: String, tokens: Double?, opacity: Double, fraction: Double, color: RGB) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).foregroundStyle(Color(RGB.dim))
                Spacer()
                Text(opacity > 0 ? "\(formatTokens(tokens)) t/s" : "--")
                    .foregroundStyle(Color(color).opacity(opacity > 0 ? opacity : 1))
            }
            .mono(12)
            Meter(fraction: opacity > 0 ? fraction : 0, color: color)
        }
    }

    private var loadLine: String {
        let phase = sample?.phase.isEmpty == false ? sample!.phase : "LOAD"
        if let percent = sample?.percent, let eta = sample?.etaSeconds {
            return "\(phase) \(percent)%  \(formatDuration(eta))"
        }
        if let percent = sample?.percent {
            return "\(phase) \(percent)%"
        }
        return phase
    }

    private var stallEvidence: String {
        switch sample?.stall {
        case "disk":
            return "\(formatCount(sample?.readIOPS)) r/s   \(formatFixed(sample?.awaitMS, decimals: 1)) ms   PSI \(formatFixed(sample?.diskPSI, decimals: 0))%"
        case "mem":
            return "\(formatGiB(sample?.memGiB))   swap in \(formatRate(sample?.swapIn))"
        case "fabric":
            return "RoCE \(sample?.roce0 ?? "--")/\(sample?.roce1 ?? "--")   pair \(sample?.pairWord ?? "--")"
        case "engine":
            return "Engine down"
        default:
            return "Queue \(sample?.queue ?? 0)"
        }
    }
}

struct ServicePage: View {
    var sample: Sample?
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sample?.model.isEmpty == false ? sample!.model : "idle")
                .mono(14)
                .foregroundStyle(Color.white)
                .lineLimit(2)
            HStack(alignment: .top, spacing: 16) {
                gauge(
                    "Decode",
                    (sample?.decodeOpacity(at: now) ?? 0) > 0 ? sample?.decodeTPS : nil,
                    Scale.decode,
                    .serve
                )
                gauge(
                    "Prefill",
                    (sample?.prefillOpacity(at: now) ?? 0) > 0 ? sample?.prefillTPS : nil,
                    Scale.prefill,
                    .up
                )
            }
            HStack(spacing: 10) {
                QueueDots(count: sample?.queue ?? 0)
                Text("Queue \(sample?.queue ?? 0)")
                    .foregroundStyle(Color(RGB.dim))
                Spacer()
                Text("Pair \(sample?.pairWord ?? "--")")
                    .foregroundStyle(Color(sample?.pairColor ?? .dim))
            }
            .mono(12)
            HStack(spacing: 14) {
                labeled("SoC", formatTemp(sample?.socC), sample?.socC.map(temperatureColor) ?? .dim)
                labeled("GPU", formatTemp(sample?.gpuC), sample?.gpuC.map(temperatureColor) ?? .dim)
                labeled("CPU", formatTemp(sample?.cpuC), sample?.cpuC.map(temperatureColor) ?? .dim)
                Spacer()
                labeled("Mem", formatGiB(sample?.memGiB), oomColor(sample?.memGiB))
            }
        }
    }

    private func gauge(_ label: String, _ tokens: Double?, _ scale: Double, _ color: RGB) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatTokens(tokens))
                .mono(22, weight: .semibold)
                .foregroundStyle(Color.white)
            Text(label)
                .mono(11)
                .foregroundStyle(Color(RGB.dim))
            Meter(fraction: (tokens ?? 0) / scale, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeled(_ name: String, _ value: String, _ color: RGB) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).foregroundStyle(Color(RGB.dim))
            Text(value).foregroundStyle(Color(color))
        }
        .mono(12)
    }
}

struct DiskPage: View {
    var sample: Sample?
    var history: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sample?.diskDevice ?? "--")
                .mono(16, weight: .semibold)
                .foregroundStyle(Color.white)
            HStack(alignment: .top, spacing: 12) {
                column("IOPS", sample?.readIOPS, Scale.iops, Scale.iopsAmber, Scale.iopsRed, decimals: 0, asCount: true)
                column("ms", sample?.awaitMS, Scale.awaitMS, Scale.awaitAmber, Scale.awaitRed, decimals: 1, asCount: false)
                column("PSI", sample?.diskPSI, Scale.diskPSI, Scale.psiAmber, Scale.psiRed, decimals: 1, asCount: false)
            }
            MeterRow(
                label: "Cache",
                value: formatGiB(sample?.cacheGiB),
                fraction: (sample?.cacheGiB ?? 0) / Scale.cacheGiB,
                color: .idle
            )
            MeterRow(
                label: "Swap",
                value: formatMiB(sample?.swapMiB),
                fraction: swapFraction,
                color: .stall
            )
            HStack {
                Text("In \(formatRate(sample?.swapIn))")
                Spacer()
                Text("Out \(formatRate(sample?.swapOut))")
            }
            .mono(11)
            .foregroundStyle(Color(RGB.dim))
            Sparkline(values: history, color: .up)
        }
    }

    private var swapFraction: Double {
        guard let total = sample?.swapTotalMiB, total > 0 else { return 0 }
        return (sample?.swapMiB ?? 0) / total
    }

    private func column(
        _ label: String,
        _ value: Double?,
        _ scale: Double,
        _ amber: Double,
        _ red: Double,
        decimals: Int,
        asCount: Bool
    ) -> some View {
        let text = asCount ? formatCount(value) : formatFixed(value, decimals: decimals)
        let color = value.map { severityColor($0, amber: amber, red: red) } ?? .dim
        return VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .mono(16, weight: .semibold)
                .foregroundStyle(Color.white)
            Text(label)
                .mono(11)
                .foregroundStyle(Color(RGB.dim))
            Meter(fraction: (value ?? 0) / scale, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NetworkPage: View {
    var sample: Sample?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PairRow(sample: sample)
            VStack(alignment: .leading, spacing: 2) {
                Text(sample?.ip ?? "--")
                Text(sample?.gateway ?? "--")
                    .foregroundStyle(Color(RGB.dim))
            }
            .mono(13)
            .foregroundStyle(Color.white)
            MeterRow(
                label: "RX",
                value: formatRate(sample?.mgmtRX),
                fraction: (sample?.mgmtRX ?? 0) / Scale.mgmtBytes,
                color: .serve
            )
            MeterRow(
                label: "TX",
                value: formatRate(sample?.mgmtTX),
                fraction: (sample?.mgmtTX ?? 0) / Scale.mgmtBytes,
                color: .up
            )
            MeterRow(
                label: "RDMA",
                value: formatRate(sample?.roceRX),
                fraction: (sample?.roceRX ?? 0) / Scale.rdmaBytes,
                color: .serve
            )
            if let errors = sample?.mgmtErrors, errors > 0 {
                Text("Errors \(errors)")
                    .mono(12)
                    .foregroundStyle(Color(RGB.wedge))
            }
        }
    }
}

struct MemoryPage: View {
    var sample: Sample?

    var body: some View {
        let total = sample?.memTotalGiB ?? 0
        let used = sample?.memUsedGiB ?? 0
        let usedColor = memoryUsedColor(used: used, total: total)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Tank(fraction: total > 0 ? used / total : 0, color: usedColor)
                    .frame(width: 22, height: 88)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available")
                        .mono(11)
                        .foregroundStyle(Color(RGB.dim))
                    Text(formatGiB(sample?.memGiB))
                        .mono(28, weight: .semibold)
                        .foregroundStyle(Color.white)
                    Text("\(formatGiB(sample?.memUsedGiB)) of \(formatGiB(sample?.memTotalGiB))")
                        .mono(12)
                        .foregroundStyle(Color(usedColor))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("OOM")
                        .mono(11)
                        .foregroundStyle(Color(oomColor(sample?.memGiB)))
                    Circle()
                        .fill(Color(oomColor(sample?.memGiB)))
                        .frame(width: 8, height: 8)
                }
            }
            MeterRow(
                label: "Cache",
                value: formatGiB(sample?.cacheGiB),
                fraction: (sample?.cacheGiB ?? 0) / Scale.cacheGiB,
                color: .idle
            )
            MeterRow(
                label: "Swap",
                value: formatMiB(sample?.swapMiB),
                fraction: swapFraction,
                color: .stall
            )
            MeterRow(
                label: "PSI",
                value: formatFixed(sample?.memPSI, decimals: 1),
                fraction: (sample?.memPSI ?? 0) / Scale.memPSI,
                color: severityColor(sample?.memPSI ?? 0, amber: Scale.psiAmber, red: Scale.psiRed)
            )
        }
    }

    private var swapFraction: Double {
        guard let total = sample?.swapTotalMiB, total > 0 else { return 0 }
        return (sample?.swapMiB ?? 0) / total
    }
}

struct ClusterPage: View {
    var sample: Sample?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PairRow(sample: sample)
            HStack(alignment: .firstTextBaseline) {
                Text(formatTokens(sample?.decodeTPS))
                    .mono(28, weight: .semibold)
                    .foregroundStyle(Color.white)
                Text("t/s")
                    .mono(12)
                    .foregroundStyle(Color(RGB.dim))
                Spacer()
                QueueDots(count: sample?.queue ?? 0)
            }
            Meter(fraction: (sample?.decodeTPS ?? 0) / Scale.decode, color: .serve)
            MeterRow(
                label: "Disk",
                value: formatCount(sample?.readIOPS),
                fraction: (sample?.readIOPS ?? 0) / Scale.iops,
                color: severityColor(sample?.readIOPS ?? 0, amber: Scale.iopsAmber, red: Scale.iopsRed)
            )
        }
    }
}

struct PairRow: View {
    var sample: Sample?

    var body: some View {
        let head = sample?.role != "worker"
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(head ? "Head" : "Worker")
                    .foregroundStyle(Color(RGB.serve))
                Rectangle()
                    .fill(Color(sample?.linkColor ?? .dim))
                    .frame(height: 2)
                Text(head ? "Worker" : "Head")
                    .foregroundStyle(Color(sample?.linkColor ?? .dim))
            }
            .mono(12)
            HStack(spacing: 8) {
                Text("RoCE").foregroundStyle(Color(RGB.dim))
                Circle()
                    .fill(Color(sample?.roce0 == "up" ? RGB.serve : RGB.wedge))
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(Color(sample?.roce1 == "up" ? RGB.serve : RGB.wedge))
                    .frame(width: 7, height: 7)
                Text("Pair \(sample?.pairWord ?? "--")")
                    .foregroundStyle(Color(sample?.pairColor ?? .dim))
            }
            .mono(12)
        }
    }
}

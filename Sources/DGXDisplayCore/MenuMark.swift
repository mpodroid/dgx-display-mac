import Foundation

/// The colored state mark. Rates are not part of it.
public struct MenuPiece: Equatable, Sendable {
    public var text: String
    public var rgb: RGB

    public init(text: String, rgb: RGB) {
        self.text = text
        self.rgb = rgb
    }
}

/// What the menu bar shows for the current face.
/// SERVE and STALL use a colored icon for the state. Their rates are plain
/// title text, drawn by the menu bar in its own text color.
/// SERVE's title is the decode rate, then the prefill rate.
/// STALL's title is the disk IO request rate (reads plus writes).
public struct MenuMark: Equatable, Sendable {
    public var state: MenuPiece
    public var title: String
    public var tooltip: String

    public var key: String {
        "\(state.text) \(state.rgb.r),\(state.rgb.g),\(state.rgb.b) \(title)"
    }
}

public func menuMark(face: Face, sample: Sample?, now: Date) -> MenuMark {
    switch face {
    case .serve:
        return serveMark(sample, now)
    case .stall:
        return stallMark(sample)
    default:
        return MenuMark(
            state: MenuPiece(text: face.word, rgb: face.rgb),
            title: "",
            tooltip: "DGX Display \(face.word)"
        )
    }
}

private func serveMark(_ sample: Sample?, _ now: Date) -> MenuMark {
    let decode = rateText(sample?.decodeTPS, opacity: sample?.decodeOpacity(at: now) ?? 0)
    let prefill = rateText(sample?.prefillTPS, opacity: sample?.prefillOpacity(at: now) ?? 0)
    return MenuMark(
        state: MenuPiece(text: Face.serve.word, rgb: .serve),
        title: "\(decode)  \(prefill)",
        tooltip: "DGX Display SERVE  decode \(decode) t/s, prefill \(prefill) t/s"
    )
}

private func stallMark(_ sample: Sample?) -> MenuMark {
    let io = ioRequestText(sample)
    return MenuMark(
        state: MenuPiece(text: Face.stall.word, rgb: .stall),
        title: io,
        tooltip: "DGX Display STALL  IO requests \(io)"
    )
}

private func rateText(_ value: Double?, opacity: Double) -> String {
    guard opacity > 0, let value else { return "--" }
    return formatTokens(value)
}

/// Reads per second plus writes per second. Below 10k the count stays whole.
private func ioRequestText(_ sample: Sample?) -> String {
    guard let sample else { return "--" }
    if sample.readIOPS == nil, sample.writeIOPS == nil { return "--" }
    let total = (sample.readIOPS ?? 0) + (sample.writeIOPS ?? 0)
    return "\(formatMenuCount(total)) io/s"
}

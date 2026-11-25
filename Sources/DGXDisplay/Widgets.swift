import DGXDisplayCore
import SwiftUI

extension Color {
    init(_ rgb: RGB) {
        self.init(
            red: Double(rgb.r) / 255,
            green: Double(rgb.g) / 255,
            blue: Double(rgb.b) / 255
        )
    }
}

extension View {
    func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight, design: .monospaced))
    }
}

struct Meter: View {
    var fraction: Double
    var color: RGB

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(RGB.dim).opacity(0.35))
                Rectangle()
                    .fill(Color(color))
                    .frame(width: geo.size.width * clamp01(fraction))
            }
        }
        .frame(height: 6)
    }
}

struct Tank: View {
    var fraction: Double
    var color: RGB

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color(RGB.dim).opacity(0.35))
                Rectangle()
                    .fill(Color(color))
                    .frame(height: geo.size.height * clamp01(fraction))
            }
        }
    }
}

struct MeterRow: View {
    var label: String
    var value: String
    var fraction: Double
    var color: RGB

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).foregroundStyle(Color(RGB.dim))
                Spacer()
                Text(value).foregroundStyle(Color.white)
            }
            .mono(12)
            Meter(fraction: fraction, color: color)
        }
    }
}

struct QueueDots: View {
    var count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color(index < count ? (count > 3 ? RGB.wedge : RGB.stall) : RGB.dim))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("Queue \(count)")
    }
}

struct Sparkline: View {
    var values: [Int]
    var color: RGB

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let peak = max(values.max() ?? 1, 1)
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * Double(index) / Double(values.count - 1)
                let y = size.height - 1 - (Double(value) / Double(peak)) * (size.height - 1)
                let point = CGPoint(x: x, y: y)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(path, with: .color(Color(color)), lineWidth: 1)
        }
        .frame(height: 28)
    }
}

struct AdvanceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

import DGXDisplayCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: Store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let face = store.face(at: timeline.date)
            VStack(spacing: 0) {
                Button(action: store.advance) {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(face.rgb))
                            .frame(height: 3)
                        VStack(alignment: .leading, spacing: 12) {
                            if store.page != .face {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(store.page.title)
                                        .mono(16, weight: .semibold)
                                        .foregroundStyle(Color(face.rgb))
                                    Spacer()
                                    Text(store.sample?.host ?? "")
                                        .mono(12)
                                        .foregroundStyle(Color(RGB.dim))
                                }
                            }
                            page(face: face, now: timeline.date)
                                .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
                            HStack(spacing: 4) {
                                ForEach(PanelPage.allCases, id: \.self) { item in
                                    Rectangle()
                                        .fill(Color(item == store.page ? face.rgb : RGB.dim))
                                        .frame(height: 3)
                                }
                                Text(store.page.next.title)
                                    .mono(11)
                                    .foregroundStyle(Color(RGB.dim))
                                    .frame(width: 68, alignment: .trailing)
                            }
                        }
                        .padding(16)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(AdvanceStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusEffectDisabled()

                Text(store.statusLine(at: timeline.date))
                    .mono(11)
                    .foregroundStyle(Color(store.running && face != .wedge ? RGB.dim : face.rgb))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .frame(width: 348, alignment: .top)
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func page(face: Face, now: Date) -> some View {
        switch store.page {
        case .face:
            FacePage(sample: store.sample, face: face, now: now)
        case .service:
            ServicePage(sample: store.sample, now: now)
        case .disk:
            DiskPage(sample: store.sample, history: store.iopsHistory)
        case .network:
            NetworkPage(sample: store.sample)
        case .memory:
            MemoryPage(sample: store.sample)
        case .cluster:
            ClusterPage(sample: store.sample)
        }
    }
}


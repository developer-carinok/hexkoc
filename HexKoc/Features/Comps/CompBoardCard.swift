import SwiftUI

struct CompBoardCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Tahta Dizilimi")

                BoardView(units: comp.units)

                Text("Üst sıra = ön hat (rakibe yakın)")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)

                if !unpositioned.isEmpty {
                    Text("Konumu bilinmiyor")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.secondaryText)
                    FlowRow(spacing: 6) {
                        ForEach(unpositioned) { unit in
                            NavigationLink(value: Route.champion(store.champion(unit.id)?.id ?? unit.id)) {
                                Chip(
                                    text: store.champion(unit.id)?.name.tr ?? unit.id,
                                    color: Theme.cost(store.champion(unit.id)?.cost ?? 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var unpositioned: [CompUnit] {
        comp.units.filter { $0.cell == nil }
    }
}

/// Satır sonunda alt satıra geçen basit yerleşim.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

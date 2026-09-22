import SwiftUI

/// 28 hücrelik TFT tahtası. Üst sıra = ön hat (hücre 22-28),
/// alt sıra = arka hat (hücre 1-7). 2. ve 4. sıralar yarım altıgen sağa kayık.
struct BoardView: View {
    let units: [CompUnit]

    @Environment(DataStore.self) private var store

    var body: some View {
        Color.clear
            .aspectRatio(BoardLayout.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let hexWidth = proxy.size.width / BoardLayout.widthInHexes
                    let hexHeight = hexWidth * Hex.heightRatio

                    ZStack(alignment: .topLeading) {
                        ForEach(BoardLayout.slots, id: \.cell) { slot in
                            let unit = unitsByCell[slot.cell]
                            cellView(unit: unit, hexWidth: hexWidth)
                                .frame(width: hexWidth, height: hexHeight)
                                .position(BoardLayout.center(of: slot, hexWidth: hexWidth))
                        }
                    }
                }
            }
            .accessibilityLabel("Tahta dizilimi")
    }

    private var unitsByCell: [Int: CompUnit] {
        Dictionary(units.compactMap { unit in unit.cell.map { ($0, unit) } }, uniquingKeysWith: { first, _ in first })
    }

    @ViewBuilder
    private func cellView(unit: CompUnit?, hexWidth: CGFloat) -> some View {
        if let unit {
            let champion = store.champion(unit.id)
            NavigationLink(value: Route.champion(champion?.id ?? unit.id)) {
                ZStack(alignment: .top) {
                    IconView(path: champion?.icon, url: champion?.iconURL,
                             size: hexWidth * Hex.heightRatio, contentMode: .fill)
                        .frame(width: hexWidth, height: hexWidth * Hex.heightRatio)
                        .clipShape(HexagonShape())
                        .overlay(
                            HexagonShape()
                                .strokeBorder(Theme.cost(champion?.cost ?? 1), lineWidth: 2)
                        )
                    if unit.stars >= 3 {
                        StarMarker(size: max(5, hexWidth * 0.14))
                            .padding(.top, hexWidth * 0.12)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(champion?.name.tr ?? unit.id)
        } else {
            HexagonShape()
                .fill(Theme.elevated.opacity(0.55))
                .overlay(HexagonShape().strokeBorder(Theme.hairline, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }
}

/// Tahtanın geometrisi — hücre numaralandırması burada tek yerde.
enum BoardLayout {
    static let rowCount = 4
    static let columnCount = 7

    /// 7 altıgen + kayık satırlar için yarım altıgen.
    static let widthInHexes: CGFloat = CGFloat(columnCount) + 0.5

    static let aspectRatio: CGFloat = widthInHexes / (Hex.heightRatio + CGFloat(rowCount - 1) * Hex.pitchRatio)

    struct Slot {
        let row: Int
        let column: Int
        let cell: Int
    }

    /// Üstten alta: 22-28, 15-21, 8-14, 1-7.
    static let slots: [Slot] = (0..<rowCount).flatMap { row in
        (0..<columnCount).map { column in
            Slot(row: row, column: column, cell: firstCell(inRow: row) + column)
        }
    }

    static func firstCell(inRow row: Int) -> Int {
        switch row {
        case 0: 22
        case 1: 15
        case 2: 8
        default: 1
        }
    }

    /// Üstten 2. ve 4. sıralar (hücre 15-21 ve 1-7) yarım altıgen sağa kayar.
    static func isShifted(row: Int) -> Bool { row % 2 == 1 }

    static func center(of slot: Slot, hexWidth: CGFloat) -> CGPoint {
        let shift = isShifted(row: slot.row) ? hexWidth / 2 : 0
        return CGPoint(
            x: shift + hexWidth * (0.5 + CGFloat(slot.column)),
            y: hexWidth * Hex.heightRatio / 2 + CGFloat(slot.row) * hexWidth * Hex.pitchRatio
        )
    }
}

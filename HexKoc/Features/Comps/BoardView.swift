import SwiftUI

/// 28 hücrelik TFT tahtası. Üst sıra = ön hat (hücre 22-28),
/// alt sıra = arka hat (hücre 1-7). 2. ve 4. sıralar yarım altıgen sağa kayık.
struct BoardView: View {
    let units: [CompUnit]
    /// Yatay modda tahta pencereye sığsın diye yükseklik sınırı.
    var maxHeight: CGFloat = .infinity

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

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

                        // İsimler tüm altıgenlerin üstünde kalsın; dokunuş altıgene geçsin.
                        ForEach(BoardLayout.slots, id: \.cell) { slot in
                            if let unit = unitsByCell[slot.cell] {
                                namePill(unit: unit, hexWidth: hexWidth)
                                    .frame(width: hexWidth, height: hexHeight, alignment: .bottom)
                                    .position(BoardLayout.center(of: slot, hexWidth: hexWidth))
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: BoardLayout.maxWidth(forHeight: maxHeight))
            .frame(maxWidth: .infinity)
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
            .accessibilityLabel(champion?.name.text(settings.nameLanguage) ?? unit.id)
        } else {
            HexagonShape()
                .fill(Theme.elevated.opacity(0.55))
                .overlay(HexagonShape().strokeBorder(Theme.hairline, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    /// Altıgenin alt kenarına binen küçük isim etiketi.
    private func namePill(unit: CompUnit, hexWidth: CGFloat) -> some View {
        Text(store.champion(unit.id)?.name.text(settings.nameLanguage) ?? unit.id)
            .font(.system(size: min(9, hexWidth * 0.22), weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .frame(maxWidth: hexWidth)
            .background(Color.black.opacity(0.72), in: Capsule())
            .accessibilityHidden(true)
    }
}

/// Tahtanın geometrisi — hücre numaralandırması burada tek yerde.
enum BoardLayout {
    static let rowCount = 4
    static let columnCount = 7

    /// 7 altıgen + kayık satırlar için yarım altıgen.
    static let widthInHexes: CGFloat = CGFloat(columnCount) + 0.5

    static let aspectRatio: CGFloat = widthInHexes / (Hex.heightRatio + CGFloat(rowCount - 1) * Hex.pitchRatio)

    /// Yüksekliğe sığdırırken: bir altıgen + üç satır adımı + biraz pay.
    static let heightInHexes: CGFloat = 1 + CGFloat(rowCount - 1) * Hex.pitchRatio + 0.15

    /// Verilen yüksekliğe sığan en geniş tahta; yatay modda kaydırmadan görünsün diye.
    static func maxWidth(forHeight height: CGFloat) -> CGFloat {
        height.isFinite ? height / heightInHexes * widthInHexes : .infinity
    }

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

import SwiftUI

/// Bir seviye tahtası: solda "Sv 8" etiketi, yanında birim kareleri.
/// Veride olmayan id'ler atlanır; kompun birim listesinde olmayanlar eşyasız gösterilir.
struct UnitTileRow: View {
    var ids: [String] = []
    let comp: Comp
    /// Küratörlü aşamalarda birimler hazır gelir; o zaman `ids` kullanılmaz.
    var units: [CompUnit]?
    var label: String?
    var size: CGFloat = 56
    var showItems: Bool = true

    @Environment(DataStore.self) private var store

    static let labelWidth: CGFloat = 32
    static let spacing: CGFloat = 4

    var body: some View {
        HStack(alignment: .top, spacing: Self.spacing) {
            if let label {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: Self.labelWidth, alignment: .leading)
                    .padding(.top, UnitTile.starHeight + size * 0.3)
            }
            FlowRow(spacing: Self.spacing) {
                ForEach(Array(resolvedUnits.enumerated()), id: \.offset) { _, unit in
                    UnitTile(unit: unit, size: size, showItems: showItems)
                }
            }
        }
    }

    private var resolvedUnits: [CompUnit] { units ?? store.units(ids, in: comp) }
}

/// Küratörlü aşama satırı: üstte aşamanın kendi etiketi, altında eşyalı birimler.
struct StageTileRow: View {
    let stage: CompStage
    let comp: Comp
    var size: CGFloat = 56
    var showItems: Bool = true

    static let labelHeight: CGFloat = 13
    static let spacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Text(stage.label)
                .font(.caption2.bold())
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: Self.labelHeight, alignment: .leading)
            UnitTileRow(comp: comp, units: stage.units, size: size, showItems: showItems)
        }
    }

    /// Satırın birimlerin dışında kapladığı yükseklik.
    static var chromeHeight: CGFloat { labelHeight + spacing }
}

extension UnitTileRow {
    /// Etiket + `count` kare + aralar verilen alana sığsın.
    static func tileSize(height: CGFloat, width: CGFloat, count: Int, labelled: Bool = true, showItems: Bool) -> CGFloat {
        let count = max(count, 1)
        let label = labelled ? labelWidth + spacing : 0
        let gaps = spacing * CGFloat(count - 1)
        // Yuvarlama yüzünden satır alta kaymasın diye küçük bir pay bırak.
        let byWidth = (width - label - gaps - 2) / CGFloat(count) - UnitTile.horizontalPadding
        let byHeight = height - UnitTile.spacing - UnitTile.chromeHeight(showItems: showItems)
        let size = min(max(min(byWidth, byHeight), UnitTile.minSize), UnitTile.maxSize)
        return (size * 2).rounded(.down) / 2
    }
}

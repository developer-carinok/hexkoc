import SwiftUI

/// Son tahta: solda altıgen dizilim (isim etiketleriyle), sağda 9-10. seviye
/// kadrosu ve aktif özellikler.
struct GameModeBoardPage: View {
    let comp: Comp
    let pageSize: CGSize

    private static let columnSpacing: CGFloat = 12
    private static let rowSpacing: CGFloat = 8
    private static let captionHeight: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: Self.columnSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    BoardView(units: comp.units, maxHeight: boardHeight)
                    Text("Üst sıra = ön hat (rakibe yakın)")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if !comp.traits.isEmpty {
                    FlowRow(spacing: 6) {
                        ForEach(comp.traits) { entry in
                            NavigationLink(value: Route.trait(entry.id)) {
                                TraitCountChip(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: boardWidth)

            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(boards, id: \.level) { board in
                    UnitTileRow(ids: board.ids, comp: comp, label: "Sv \(board.level)", size: tileSize)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                if let stage = curatedStage {
                    UnitTileRow(comp: comp, units: stage.units, label: "Tavan", size: tileSize)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var curatedStage: CompStage? { comp.stage(\.late) }

    /// 9 ve 10. seviye kadroları — veride varsa.
    private var boards: [(level: Int, ids: [String])] {
        [9, 10].compactMap { level in
            let ids = comp.levelBoards[String(level)] ?? []
            return ids.isEmpty ? nil : (level: level, ids: ids)
        }
    }

    /// Tahtanın altında özellik rozetleri de var; onlara pay bırak.
    private var boardHeight: CGFloat {
        max(pageSize.height - Self.captionHeight - traitsHeight, 80)
    }

    /// Tahta tamamı görünecek kadar; ekranın %40'ını geçmesin.
    private var boardWidth: CGFloat {
        min(pageSize.width * 0.40, BoardLayout.maxWidth(forHeight: boardHeight))
    }

    private var rightWidth: CGFloat {
        max(pageSize.width - boardWidth - Self.columnSpacing, 120)
    }

    private var traitsHeight: CGFloat {
        guard !comp.traits.isEmpty else { return 0 }
        let perLine = max(1, Int(pageSize.width * 0.40 / 110))
        let lines = (comp.traits.count + perLine - 1) / perLine
        return CGFloat(lines) * 28 + Self.rowSpacing
    }

    private var tileSize: CGFloat {
        let stageRow: CGFloat = curatedStage == nil ? 0 : 1
        let rows = max(CGFloat(boards.count) + stageRow, 1)
        let cellHeight = (pageSize.height - Self.rowSpacing * rows) / rows
        let count = max(boards.map(\.ids.count).max() ?? 1, curatedStage?.units.count ?? 1)
        return UnitTileRow.tileSize(height: cellHeight, width: rightWidth, count: count, showItems: true)
    }
}

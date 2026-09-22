import SwiftUI

/// Erken oyun: küratörlü erken tahta, ardından MetaTFT'nin 4-7. seviye tahtaları,
/// seviye atlama zamanlaması ve tek cümlelik plan.
struct GameModeEarlyPage: View {
    let comp: Comp
    let pageSize: CGSize

    @Environment(DataStore.self) private var store

    private static let rowSpacing: CGFloat = 8
    private static let columnSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            if let stage = curatedStage {
                StageTileRow(stage: stage, comp: comp, size: tileSize)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if levels.isEmpty {
                if curatedStage == nil {
                    Text("Bu komp için erken oyun tahtası verisi yok.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                ForEach(Array(levelRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: Self.columnSpacing) {
                        ForEach(0..<columns, id: \.self) { index in
                            Group {
                                if index < row.count {
                                    UnitTileRow(
                                        ids: comp.earlyBoards[String(row[index])] ?? [],
                                        comp: comp,
                                        label: "Sv \(row[index])",
                                        size: tileSize,
                                        showItems: showsLevelItems
                                    )
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                Spacer(minLength: 0)
            }
            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !timings.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(timings) { timing in
                        Chip(text: timing.label, color: Theme.accent)
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered")
                    .font(.caption.weight(.bold))
                Text(comp.playstyle.plan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
    }

    private var curatedStage: CompStage? { comp.stage(\.early) }

    /// Küratörlü satır eşyaları taşıyor; dört satır ekrana sığsın diye seviye
    /// satırlarında eşya şeridi yer kaplamaz.
    private var showsLevelItems: Bool { curatedStage == nil }

    /// Erken tahtası olan seviyeler; boş listeler ve küratörlü satırın eşi atlanır.
    private var levels: [Int] {
        comp.earlyLevels.filter { level in
            let ids = comp.earlyBoards[String(level)] ?? []
            return !ids.isEmpty && !matchesCurated(ids)
        }
    }

    /// Aynı kadro hem küratörlü satırda hem seviye satırında durmasın.
    private func matchesCurated(_ ids: [String]) -> Bool {
        guard let stage = curatedStage else { return false }
        return canonical(ids) == canonical(stage.units.map(\.id))
    }

    private func canonical(_ ids: [String]) -> Set<String> {
        Set(ids.map { store.champion($0)?.id ?? $0 })
    }

    /// Seviye atlama zamanlaması erken oyun için 6. seviyeye kadar anlamlı.
    private var timings: [LevelTiming] {
        comp.levelTiming.filter { $0.level <= 6 }
    }

    private var columns: Int { levels.count > 2 ? 2 : 1 }

    private var levelRows: [[Int]] {
        stride(from: 0, to: levels.count, by: columns).map {
            Array(levels[$0..<min($0 + columns, levels.count)])
        }
    }

    private var footerHeight: CGFloat {
        (timings.isEmpty ? 0 : 32) + 22
    }

    private var tileSize: CGFloat {
        let stageRow: CGFloat = curatedStage == nil ? 0 : 1
        let rows = max(CGFloat(levelRows.count) + stageRow, 1)
        // Küratörlü satır etiketi ve eşya şeridi kadar fazladan yer kaplar.
        let stageChrome = curatedStage == nil
            ? 0
            : StageTileRow.chromeHeight + UnitTile.itemHeight + UnitTile.spacing
        let cellHeight = (pageSize.height - footerHeight - stageChrome - Self.rowSpacing * rows) / rows
        let columnWidth = (pageSize.width - Self.columnSpacing * CGFloat(columns - 1)) / CGFloat(columns)
        let boardCount = levels.map { (comp.earlyBoards[String($0)] ?? []).count }.max() ?? 1
        let count = max(boardCount, curatedStage?.units.count ?? 1)
        return UnitTileRow.tileSize(height: cellHeight, width: columnWidth, count: count, showItems: showsLevelItems)
    }
}

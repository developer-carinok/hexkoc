import SwiftUI

/// Orta oyun: küratörlü orta tahta, 7 ve 8. seviye tahtaları, zamanlama ve
/// (çevirme kompuysa) 3★ hedefleri.
struct GameModeMidPage: View {
    let comp: Comp
    let pageSize: CGSize

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private static let rowSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            if let stage = curatedStage {
                StageTileRow(stage: stage, comp: comp, size: tileSize)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if boards.isEmpty {
                if curatedStage == nil {
                    Text("Bu komp için orta oyun tahtası verisi yok.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                ForEach(boards, id: \.level) { board in
                    UnitTileRow(
                        ids: board.ids,
                        comp: comp,
                        label: "Sv \(board.level)",
                        size: tileSize,
                        showItems: showsLevelItems
                    )
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            Spacer(minLength: 0)
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
            if !starTargets.isEmpty {
                HStack(spacing: 6) {
                    StarMarker(size: 8)
                    Text("3★ hedefler: " + starTargets.joined(separator: ", "))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var curatedStage: CompStage? { comp.stage(\.mid) }

    /// Küratörlü satır eşyaları taşıyor; seviye satırları eşyasız daha kısa.
    private var showsLevelItems: Bool { curatedStage == nil }

    /// 7 ve 8; veri yoksa en yakın seviyeye düşer, aynı tahtayı iki kez göstermez.
    private var boards: [(level: Int, ids: [String])] {
        var result: [(level: Int, ids: [String])] = []
        for wanted in [7, 8] {
            guard let board = comp.closestLevelBoard(to: wanted),
                  !result.contains(where: { $0.level == board.level })
            else { continue }
            result.append(board)
        }
        return result
    }

    private var timings: [LevelTiming] {
        comp.levelTiming.filter { (7...8).contains($0.level) }
    }

    /// Çevirme kompunda 3 yıldıza çıkarılacak birimler.
    private var starTargets: [String] {
        guard comp.playstyle.isReroll else { return [] }
        let ids = comp.starPriority.isEmpty
            ? comp.units.filter { $0.stars >= 3 }.map(\.id)
            : comp.starPriority
        return ids.compactMap { store.champion($0)?.name.text(settings.nameLanguage) }
    }

    private var footerHeight: CGFloat {
        (timings.isEmpty ? 0 : 32) + (starTargets.isEmpty ? 0 : 22)
    }

    private var tileSize: CGFloat {
        let stageRow: CGFloat = curatedStage == nil ? 0 : 1
        let rows = max(CGFloat(boards.count) + stageRow, 1)
        // Küratörlü satır etiketi ve eşya şeridi kadar fazladan yer kaplar.
        let stageChrome = curatedStage == nil
            ? 0
            : StageTileRow.chromeHeight + UnitTile.itemHeight + UnitTile.spacing
        let cellHeight = (pageSize.height - footerHeight - stageChrome - Self.rowSpacing * rows) / rows
        let count = max(boards.map(\.ids.count).max() ?? 1, curatedStage?.units.count ?? 1)
        return UnitTileRow.tileSize(height: cellHeight, width: pageSize.width, count: count, showItems: showsLevelItems)
    }
}

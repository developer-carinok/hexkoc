import SwiftUI

struct CompLevelBoardsCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store
    @State private var selection: BoardSelection = .early

    private enum BoardSelection: Hashable {
        case early
        case mid
        case late
        case level(Int)

        var title: String {
            switch self {
            case .early: "Erken"
            case .mid: "Orta"
            case .late: "Tavan"
            case .level(let level): "\(level)"
            }
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Seviye Tahtaları")

                if segments.count > 1 {
                    Picker("Seviye", selection: $selection) {
                        ForEach(segments, id: \.self) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let stage = curatedStage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(stage.label)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                        tileGrid(units: stage.units)
                    }
                }

                ForEach(visibleLevels, id: \.self) { level in
                    VStack(alignment: .leading, spacing: 6) {
                        if visibleLevels.count > 1 {
                            Text("\(level). seviye")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.secondaryText)
                        }
                        tileGrid(ids: comp.board(level: level))
                    }
                }

                if !comp.levelTiming.isEmpty {
                    Hairline()
                    FlowRow(spacing: 6) {
                        ForEach(comp.levelTiming) { timing in
                            Chip(text: timing.label, color: Theme.accent)
                        }
                    }
                }
            }
        }
        .onAppear {
            if !segments.contains(selection), let first = segments.first {
                selection = first
            }
        }
    }

    private var earlyLevels: [Int] { comp.earlyLevels }

    private var lateLevels: [Int] { comp.lateLevels }

    private var segments: [BoardSelection] {
        var result: [BoardSelection] = []
        if !earlyLevels.isEmpty || comp.stage(\.early) != nil { result.append(.early) }
        if comp.stage(\.mid) != nil { result.append(.mid) }
        if comp.stage(\.late) != nil { result.append(.late) }
        return result + lateLevels.map { .level($0) }
    }

    /// Seçili sekmenin küratörlü tahtası; MetaTFT seviyelerinde yok.
    private var curatedStage: CompStage? {
        switch selection {
        case .early: comp.stage(\.early)
        case .mid: comp.stage(\.mid)
        case .late: comp.stage(\.late)
        case .level: nil
        }
    }

    private var visibleLevels: [Int] {
        switch selection {
        case .early: earlyLevels
        case .mid, .late: []
        case .level(let level): [level]
        }
    }

    /// Dikeyde de isim + eşya görünsün diye kareler kullanılır.
    private func tileGrid(ids: [String]) -> some View {
        tileGrid(units: store.units(ids, in: comp))
    }

    private func tileGrid(units: [CompUnit]) -> some View {
        FlowRow(spacing: 6) {
            ForEach(Array(units.enumerated()), id: \.offset) { _, unit in
                UnitTile(unit: unit, size: 44)
            }
        }
    }
}

import SwiftUI

struct CompLevelBoardsCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store
    @State private var selection: BoardSelection = .early

    private enum BoardSelection: Hashable {
        case early
        case level(Int)

        var title: String {
            switch self {
            case .early: "Erken"
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
        (earlyLevels.isEmpty ? [] : [.early]) + lateLevels.map { .level($0) }
    }

    private var visibleLevels: [Int] {
        switch selection {
        case .early: earlyLevels
        case .level(let level): [level]
        }
    }

    /// Dikeyde de isim + eşya görünsün diye kareler kullanılır.
    private func tileGrid(ids: [String]) -> some View {
        FlowRow(spacing: 6) {
            ForEach(Array(store.units(ids, in: comp).enumerated()), id: \.offset) { _, unit in
                UnitTile(unit: unit, size: 44)
            }
        }
    }
}

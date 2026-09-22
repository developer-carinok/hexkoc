import SwiftUI

struct CompRowView: View {
    let comp: Comp
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    TierBadge(tier: comp.tier)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(comp.name.text(settings.nameLanguage))
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            Chip(text: comp.playstyle.title, color: Theme.accent)
                            Chip(text: comp.difficulty.title, color: difficultyColor)
                            if comp.listedSourceCount >= 2 {
                                Chip(text: "\(comp.listedSourceCount) kaynak", color: Theme.secondaryText)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 4) {
                        // Durumsal komplar için sıralama eğilimi anlamsız.
                        if comp.isSituational {
                            Chip(text: "Durumsal", color: Theme.secondaryText)
                        } else {
                            Image(systemName: comp.trend.symbol)
                                .font(.caption.bold())
                                .foregroundStyle(Theme.trend(comp.trend))
                                .accessibilityLabel(comp.trend.title)
                        }
                        Text("Ort. \(Format.placement(comp.stats.avgPlacement))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                unitStrip
            }
        }
        .frame(minHeight: Theme.rowMinHeight)
    }

    private var difficultyColor: Color {
        switch comp.difficulty {
        case .easy: Theme.cost(2)
        case .medium: Theme.accent
        case .hard: Theme.tier(.s)
        }
    }

    private var unitStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(comp.units) { unit in
                    VStack(spacing: 3) {
                        ChampionIcon(champion: store.champion(unit.id), size: 38, stars: unit.stars)
                        if !unit.items.isEmpty {
                            ItemStrip(itemIDs: unit.items, size: 11)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

import SwiftUI

struct CompUnitsCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Birimler", subtitle: "\(comp.units.count) birim")
                    .padding(.bottom, 8)

                ForEach(Array(comp.units.enumerated()), id: \.offset) { index, unit in
                    if index > 0 { Hairline().padding(.vertical, 2) }
                    CompUnitRow(unit: unit, champion: store.champion(unit.id))
                }
            }
        }
    }
}

struct CompUnitRow: View {
    let unit: CompUnit
    let champion: Champion?

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(value: Route.champion(champion?.id ?? unit.id)) {
                HStack(spacing: 10) {
                    ChampionIcon(champion: champion, size: 44, stars: unit.stars)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(champion?.name.text(settings.nameLanguage) ?? unit.id)
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            CostBadge(cost: champion?.cost ?? 1)
                        }
                        HStack(spacing: 6) {
                            if let subtitle = champion.flatMap({ settings.subtitle(for: $0.name) }) {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(1)
                            }
                            if unit.isCarry {
                                Chip(text: "Taşıyıcı", color: Theme.accent)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                ForEach(Array(unit.items.enumerated()), id: \.offset) { _, itemID in
                    NavigationLink(value: Route.item(itemID)) {
                        ItemIcon(item: store.item(itemID), size: 26)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: Theme.rowMinHeight)
    }
}

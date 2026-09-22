import SwiftUI

struct CompAugmentsCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Güçlendirmeler")

                ForEach(tiers, id: \.title) { tier in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tier.title)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.secondaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tier.ids, id: \.self) { id in
                                    NavigationLink(value: Route.augment(id)) {
                                        augmentChip(id)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private var tiers: [(title: String, ids: [String])] {
        [("S seviye", comp.augments["S"] ?? []), ("A seviye", comp.augments["A"] ?? [])]
            .filter { !$0.1.isEmpty }
            .map { (title: $0.0, ids: $0.1) }
    }

    private func augmentChip(_ id: String) -> some View {
        let augment = store.augment(id)
        let color = Theme.rarity(augment?.rarity ?? .unknown)
        return HStack(spacing: 6) {
            AugmentIcon(augment: augment, size: 26)
            Text(augment?.name.text(settings.nameLanguage) ?? id)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
    }
}

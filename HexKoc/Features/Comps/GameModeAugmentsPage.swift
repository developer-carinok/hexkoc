import SwiftUI

/// Güçlendirme sayfası: S ve A seviye öneriler, satır sonunda alta sarar.
struct GameModeAugmentsPage: View {
    let comp: Comp

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tiers.isEmpty {
                Text("Bu komp için güçlendirme verisi yok")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(tiers, id: \.title) { tier in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tier.title)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.secondaryText)
                        FlowRow(spacing: 6) {
                            ForEach(tier.ids, id: \.self) { id in
                                NavigationLink(value: Route.augment(id)) {
                                    AugmentChip(augmentID: id)
                                }
                                .buttonStyle(.plain)
                            }
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
}

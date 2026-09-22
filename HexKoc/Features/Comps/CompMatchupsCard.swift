import SwiftUI

struct CompMatchupsCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Karşı Komplar")

                if !comp.counters.isEmpty {
                    section(title: "Bunlara dikkat", matchups: comp.counters, color: Theme.tier(.s))
                }
                if !comp.goodAgainst.isEmpty {
                    section(title: "Bunlara karşı iyi", matchups: comp.goodAgainst, color: Theme.cost(2))
                }
            }
        }
    }

    private func section(title: String, matchups: [CompMatchup], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(Theme.secondaryText)

            ForEach(matchups) { matchup in
                if let other = store.comp(matchup.compId) {
                    NavigationLink(value: Route.comp(other.id)) {
                        HStack(spacing: 8) {
                            TierBadge(tier: other.tier, size: 22)
                            Text(other.name.text(settings.nameLanguage))
                                .font(.subheadline)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(signed(matchup.placeChange))
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(color)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func signed(_ value: Double) -> String {
        (value > 0 ? "+" : "") + Format.placement(value)
    }
}

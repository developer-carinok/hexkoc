import SwiftUI

struct ChampionDetailView: View {
    let championID: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var abilityLanguage: NameLanguage?

    var body: some View {
        Group {
            if let champion = store.champion(championID) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        splash(champion)
                        titleCard(champion)
                        abilityCard(champion)
                        statsCard(champion)
                        if !champion.recommendedItems.isEmpty {
                            itemsCard(champion)
                        }
                        compsCard(champion)
                        footer(champion)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .navigationTitle(champion.name.text(settings.nameLanguage))
            } else {
                EmptyStateView(title: "Şampiyon bulunamadı", message: "Bu şampiyon güncel veride yok.")
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func splash(_ champion: Champion) -> some View {
        if let splash = champion.splashURL, let url = URL(string: splash) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Theme.elevated
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, Theme.background],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .accessibilityHidden(true)
        }
    }

    private func titleCard(_ champion: Champion) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ChampionIcon(champion: champion, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(champion.name.text(settings.nameLanguage))
                            .font(.title3.bold())
                            .foregroundStyle(Theme.text)
                        if let subtitle = champion.name.subtitle(settings.nameLanguage) {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    CostBadge(cost: champion.cost)
                }

                FlowRow(spacing: 6) {
                    ForEach(champion.traits, id: \.self) { id in
                        NavigationLink(value: Route.trait(id)) {
                            Chip(
                                text: store.trait(id)?.name.text(settings.nameLanguage) ?? id,
                                color: Theme.accent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func abilityCard(_ champion: Champion) -> some View {
        let language = abilityLanguage ?? settings.nameLanguage
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionHeader(title: "Yetenek")
                    Spacer(minLength: 8)
                    Button {
                        abilityLanguage = language.other
                    } label: {
                        Chip(text: language.other.rawValue.uppercased(), color: Theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Yetenek dilini değiştir")
                }

                Text(champion.ability.name.text(language))
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.accent)

                Text(champion.ability.desc.text(language))
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statsCard(_ champion: Champion) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "İstatistikler")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    statBox("Can", Format.decimal(champion.stats.hp, fractionDigits: 0))
                    statBox("Zırh", Format.decimal(champion.stats.armor, fractionDigits: 0))
                    statBox("BD", Format.decimal(champion.stats.mr, fractionDigits: 0))
                    statBox("SG", Format.decimal(champion.stats.ad, fractionDigits: 0))
                    statBox("SH", Format.decimal(champion.stats.attackSpeed, fractionDigits: 2))
                    statBox("Menzil", Format.decimal(champion.stats.range, fractionDigits: 0))
                    statBox("Mana", "\(Int(champion.stats.startMana))/\(Int(champion.stats.maxMana))")
                }
            }
        }
    }

    private func statBox(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Theme.text)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
    }

    private func itemsCard(_ champion: Champion) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Önerilen Eşyalar")
                FlowRow(spacing: 8) {
                    ForEach(champion.recommendedItems, id: \.self) { id in
                        NavigationLink(value: Route.item(id)) {
                            VStack(spacing: 4) {
                                ItemIcon(item: store.item(id), size: 40)
                                Text(store.item(id)?.name.text(settings.nameLanguage) ?? id)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(1)
                                    .frame(maxWidth: 76)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func compsCard(_ champion: Champion) -> some View {
        let comps = store.compsUsing(champion: champion.id)
        if !comps.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Kullanan Komplar", subtitle: "\(comps.count)")
                    ForEach(comps.prefix(12)) { comp in
                        NavigationLink(value: Route.comp(comp.id)) {
                            HStack(spacing: 8) {
                                TierBadge(tier: comp.tier, size: 22)
                                Text(comp.name.text(settings.nameLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("Ort. \(Format.placement(comp.stats.avgPlacement))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.secondaryText)
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
    }

    private func footer(_ champion: Champion) -> some View {
        HStack(spacing: 12) {
            Text("Havuz: \(champion.poolCount) kopya")
            if !champion.teamCode.isEmpty {
                Text("Takım kodu: \(champion.teamCode)")
                    .monospaced()
            }
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(Theme.secondaryText)
    }
}

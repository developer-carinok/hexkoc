import SwiftUI

struct TraitDetailView: View {
    let traitID: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        Group {
            if let trait = store.trait(traitID) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        headerCard(trait)
                        if !trait.breakpoints.isEmpty {
                            breakpointsCard(trait)
                        }
                        championsCard(trait)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .navigationTitle(trait.name.text(settings.nameLanguage))
            } else {
                EmptyStateView(title: "Özellik bulunamadı", message: "Bu özellik güncel veride yok.")
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(_ trait: Trait) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TraitIcon(trait: trait, size: 36, style: trait.breakpoints.last?.style ?? .none)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trait.name.text(settings.nameLanguage))
                            .font(.title3.bold())
                            .foregroundStyle(Theme.text)
                        if let subtitle = trait.name.subtitle(settings.nameLanguage) {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    Chip(text: trait.type.title, color: Theme.accent)
                }

                if !trait.desc.text(settings.nameLanguage).isEmpty {
                    Text(trait.desc.text(settings.nameLanguage))
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func breakpointsCard(_ trait: Trait) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Eşikler")
                ForEach(trait.breakpoints) { breakpoint in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.traitStyle(breakpoint.style))
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        Text("\(breakpoint.min)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Theme.traitStyle(breakpoint.style))
                            .frame(minWidth: 18, alignment: .leading)
                        Text(breakpoint.desc.text(settings.nameLanguage))
                            .font(.subheadline)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func championsCard(_ trait: Trait) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Şampiyonlar", subtitle: "\(store.champions(inTrait: trait.id).count)")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.champions(inTrait: trait.id)) { champion in
                        NavigationLink(value: Route.champion(champion.id)) {
                            VStack(spacing: 4) {
                                ChampionIcon(champion: champion, size: 52)
                                Text(champion.name.text(settings.nameLanguage))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

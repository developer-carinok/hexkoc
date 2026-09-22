import SwiftUI

struct TraitsListView: View {
    let search: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if traits.isEmpty {
                    EmptyStateView(
                        title: store.hasData ? "Sonuç yok" : "Veri bulunamadı",
                        message: store.hasData ? "Başka bir isim dene." : "Özellik verisi henüz yüklenmedi.",
                        systemImage: "sparkle.magnifyingglass"
                    )
                } else {
                    ForEach(traits) { trait in
                        NavigationLink(value: Route.trait(trait.id)) {
                            TraitRowView(trait: trait)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var traits: [Trait] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.traits }
        return store.traits.filter {
            $0.name.tr.localizedCaseInsensitiveContains(query) || $0.name.en.localizedCaseInsensitiveContains(query)
        }
    }
}

struct TraitRowView: View {
    let trait: Trait

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TraitIcon(trait: trait, size: 28, style: trait.breakpoints.last?.style ?? .none)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(trait.name.text(settings.nameLanguage))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if let subtitle = settings.subtitle(for: trait.name) {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)
                    Chip(text: trait.type.title, color: Theme.secondaryText)
                }

                HStack(spacing: 5) {
                    ForEach(trait.breakpoints) { breakpoint in
                        Text("\(breakpoint.min)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(Theme.traitStyle(breakpoint.style))
                            .frame(width: 24, height: 22)
                            .background(Theme.traitStyle(breakpoint.style).opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer(minLength: 0)
                }

                if !champions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(champions) { champion in
                                ChampionIcon(champion: champion, size: 30)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .frame(minHeight: Theme.rowMinHeight)
    }

    private var champions: [Champion] {
        store.champions(inTrait: trait.id)
    }
}

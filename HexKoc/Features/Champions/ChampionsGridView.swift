import SwiftUI

struct ChampionsGridView: View {
    let search: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var selectedTraits: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                traitFilter

                if groups.isEmpty {
                    EmptyStateView(
                        title: store.hasData ? "Sonuç yok" : "Veri bulunamadı",
                        message: store.hasData ? "Aramanı veya filtreleri değiştir." : "Şampiyon verisi henüz yüklenmedi.",
                        systemImage: "person.slash"
                    )
                } else {
                    ForEach(groups, id: \.cost) { group in
                        Text("\(group.cost) Altın")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.cost(group.cost))
                            .padding(.top, 4)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(group.champions) { champion in
                                NavigationLink(value: Route.champion(champion.id)) {
                                    cell(champion)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var traitFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !selectedTraits.isEmpty {
                    Button {
                        selectedTraits.removeAll()
                    } label: {
                        Chip(text: "Temizle", systemImage: "xmark", color: Theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(store.traits) { trait in
                    Button {
                        toggle(trait.id)
                    } label: {
                        Chip(
                            text: trait.name.text(settings.nameLanguage),
                            color: Theme.accent,
                            filled: selectedTraits.contains(trait.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func cell(_ champion: Champion) -> some View {
        VStack(spacing: 5) {
            ChampionIcon(champion: champion, size: 68)
            Text(champion.name.text(settings.nameLanguage))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle = settings.subtitle(for: champion.name) {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func toggle(_ id: String) {
        if selectedTraits.contains(id) {
            selectedTraits.remove(id)
        } else {
            selectedTraits.insert(id)
        }
        Haptics.tap()
    }

    private var groups: [(cost: Int, champions: [Champion])] {
        let filtered = store.champions.filter { champion in
            guard selectedTraits.isEmpty || !selectedTraits.isDisjoint(with: champion.traits) else { return false }
            return matches(champion)
        }
        return (1...5).compactMap { cost in
            let champions = filtered.filter { $0.cost == cost }
            return champions.isEmpty ? nil : (cost, champions)
        }
    }

    private func matches(_ champion: Champion) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if champion.name.tr.localizedCaseInsensitiveContains(query) { return true }
        if champion.name.en.localizedCaseInsensitiveContains(query) { return true }
        return champion.traits.contains { id in
            guard let trait = store.trait(id) else { return false }
            return trait.name.tr.localizedCaseInsensitiveContains(query)
                || trait.name.en.localizedCaseInsensitiveContains(query)
        }
    }
}

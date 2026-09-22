import SwiftUI

struct ItemListView: View {
    let search: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if sections.isEmpty {
                    EmptyStateView(
                        title: store.hasData ? "Sonuç yok" : "Veri bulunamadı",
                        message: store.hasData ? "Başka bir isim dene." : "Eşya verisi henüz yüklenmedi.",
                        systemImage: "shield.slash"
                    )
                } else {
                    ForEach(sections, id: \.kind) { section in
                        Text(section.kind.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 6)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(section.items) { item in
                                NavigationLink(value: Route.item(item.id)) {
                                    ItemRowView(item: item)
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

    private var sections: [(kind: ItemKind, items: [Item])] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? store.items : store.items.filter {
            $0.name.tr.localizedCaseInsensitiveContains(query) || $0.name.en.localizedCaseInsensitiveContains(query)
        }
        return ItemKind.displayOrder.compactMap { kind in
            let items = filtered.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }
}

struct ItemRowView: View {
    let item: Item

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card(padding: 10) {
            HStack(spacing: 10) {
                ItemIcon(item: item, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.text(settings.nameLanguage))
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if let subtitle = settings.subtitle(for: item.name) {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if let recipe = item.recipe, recipe.count == 2 {
                    HStack(spacing: 3) {
                        ItemIcon(item: store.item(recipe[0]), size: 22)
                        Text("+")
                            .font(.caption2)
                            .foregroundStyle(Theme.secondaryText)
                        ItemIcon(item: store.item(recipe[1]), size: 22)
                    }
                }
            }
        }
        .frame(minHeight: Theme.rowMinHeight)
    }
}

import SwiftUI

/// İki bileşen seç → sonucu gör. Maç sırasında tek elle kullanılacak şekilde büyük hedefler.
struct ItemCombinerView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var selection: [String] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if components.isEmpty {
                    EmptyStateView(
                        title: "Veri bulunamadı",
                        message: "Eşya verisi henüz yüklenmedi.",
                        systemImage: "shield.slash"
                    )
                } else {
                    pickerCard
                    resultsCard
                    RecipeTableView(components: components)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var components: [Item] { store.components }

    private var pickerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Bileşenler", subtitle: "En fazla 2 seç")
                    if !selection.isEmpty {
                        Button("Temizle") { selection.removeAll() }
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                            .padding(.leading, 8)
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(components) { component in
                        Button {
                            toggle(component.id)
                        } label: {
                            componentCell(component)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func componentCell(_ component: Item) -> some View {
        let isSelected = selection.contains(component.id)
        return VStack(spacing: 4) {
            ItemIcon(item: component, size: 44)
            Text(component.name.text(settings.nameLanguage))
                .font(.system(size: 9))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isSelected ? Theme.accent.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var resultsCard: some View {
        switch selection.count {
        case 1:
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(
                        title: "\(store.item(selection[0])?.name.text(settings.nameLanguage) ?? "") ile",
                        subtitle: "Bir bileşen daha seç"
                    )
                    ForEach(components) { other in
                        if let result = store.itemsByRecipe(selection[0], other.id) {
                            NavigationLink(value: Route.item(result.id)) {
                                pairRow(other: other, result: result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case 2:
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Sonuç")
                    if let result = store.itemsByRecipe(selection[0], selection[1]) {
                        NavigationLink(value: Route.item(result.id)) {
                            resultDetail(result)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Bu iki bileşen birleşmiyor.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        default:
            Card {
                Text("Elindeki bileşene dokun; onunla çıkan bütün eşyaları göreyim.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func pairRow(other: Item, result: Item) -> some View {
        HStack(spacing: 8) {
            ItemIcon(item: other, size: 30)
            Image(systemName: "plus")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            ItemIcon(item: store.item(selection[0]), size: 30)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            ItemIcon(item: result, size: 34)
            Text(result.name.text(settings.nameLanguage))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(minHeight: Theme.rowMinHeight)
    }

    private func resultDetail(_ result: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ItemIcon(item: result, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name.text(settings.nameLanguage))
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    if let subtitle = settings.subtitle(for: result.name) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            if !result.stats.isEmpty {
                ItemStatsRow(stats: result.stats)
            }

            let desc = result.desc.text(settings.nameLanguage)
            if !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggle(_ id: String) {
        Haptics.tap()
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else if selection.count < 2 {
            selection.append(id)
        } else {
            selection = [selection[1], id]
        }
    }
}

/// Eşya istatistiklerini küçük etiketler hâlinde gösterir.
struct ItemStatsRow: View {
    let stats: [String: Double]

    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(stats.sorted(by: { StatLabel.title($0.key) < StatLabel.title($1.key) }), id: \.key) { key, value in
                Chip(text: StatLabel.text(key, value), color: Theme.accent)
            }
        }
    }
}

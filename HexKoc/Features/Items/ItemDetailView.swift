import SwiftUI

struct ItemDetailView: View {
    let itemID: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if let item = store.item(itemID) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        headerCard(item)
                        if let recipe = item.recipe, recipe.count == 2 {
                            recipeCard(recipe)
                        }
                        if !item.stats.isEmpty {
                            statsCard(item)
                        }
                        if let traitID = item.traitId, let trait = store.trait(traitID) {
                            emblemCard(trait)
                        }
                        compsCard(item)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .navigationTitle(item.name.text(settings.nameLanguage))
            } else {
                EmptyStateView(title: "Eşya bulunamadı", message: "Bu eşya güncel veride yok.")
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(_ item: Item) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ItemIcon(item: item, size: 60)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name.text(settings.nameLanguage))
                            .font(.title3.bold())
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle = item.name.subtitle(settings.nameLanguage) {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        HStack(spacing: 6) {
                            Chip(text: item.kind.title, color: Theme.accent)
                            if item.unique {
                                Chip(text: "Benzersiz", color: Theme.tier(.a))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                let desc = item.desc.text(settings.nameLanguage)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func recipeCard(_ recipe: [String]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Tarif")
                HStack(spacing: 10) {
                    ForEach(Array(recipe.enumerated()), id: \.offset) { index, id in
                        if index > 0 {
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        NavigationLink(value: Route.item(id)) {
                            VStack(spacing: 4) {
                                ItemIcon(item: store.item(id), size: 44)
                                Text(store.item(id)?.name.text(settings.nameLanguage) ?? id)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 88)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func statsCard(_ item: Item) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "İstatistikler")
                ForEach(item.stats.sorted(by: { StatLabel.title($0.key) < StatLabel.title($1.key) }), id: \.key) { key, value in
                    HStack {
                        Text(StatLabel.title(key))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                        Spacer(minLength: 8)
                        Text(StatLabel.value(key, value))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Theme.text)
                    }
                }
            }
        }
    }

    private func emblemCard(_ trait: Trait) -> some View {
        Card {
            NavigationLink(value: Route.trait(trait.id)) {
                HStack(spacing: 10) {
                    TraitIcon(trait: trait, size: 26, style: .gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verdiği özellik")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Text(trait.name.text(settings.nameLanguage))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.text)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func compsCard(_ item: Item) -> some View {
        let comps = store.comps(carrying: item.id)
        if !comps.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Bu eşyayı taşıyan komplar", subtitle: "\(comps.count)")
                    ForEach(comps.prefix(12)) { comp in
                        NavigationLink(value: Route.comp(comp.id)) {
                            HStack(spacing: 8) {
                                TierBadge(tier: comp.tier, size: 22)
                                Text(comp.name.text(settings.nameLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
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
}

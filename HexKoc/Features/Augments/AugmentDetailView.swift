import SwiftUI

struct AugmentDetailView: View {
    let augmentID: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if let augment = store.augment(augmentID) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        headerCard(augment)
                        if let traitID = augment.traitId, let trait = store.trait(traitID) {
                            traitCard(trait)
                        }
                        compsCard(augment)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .navigationTitle(augment.name.text(settings.nameLanguage))
            } else {
                EmptyStateView(title: "Güçlendirme bulunamadı", message: "Bu güçlendirme güncel veride yok.")
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(_ augment: Augment) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    AugmentIcon(augment: augment, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(augment.name.text(settings.nameLanguage))
                            .font(.title3.bold())
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle = augment.name.subtitle(settings.nameLanguage) {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    if let tier = augment.metaTier {
                        MetaTierBadge(tier: tier)
                    }
                }

                HStack(spacing: 6) {
                    Chip(text: augment.rarity.title, color: Theme.rarity(augment.rarity))
                    Chip(text: augment.category.title, color: Theme.secondaryText)
                }

                let desc = augment.desc.text(settings.nameLanguage)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func traitCard(_ trait: Trait) -> some View {
        Card {
            NavigationLink(value: Route.trait(trait.id)) {
                HStack(spacing: 10) {
                    TraitIcon(trait: trait, size: 26, style: .gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("İlgili özellik")
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
    private func compsCard(_ augment: Augment) -> some View {
        let comps = store.comps(recommending: augment.id)
        if !comps.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Öneren komplar", subtitle: "\(comps.count)")
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

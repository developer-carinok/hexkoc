import SwiftUI

struct AugmentListView: View {
    @Binding var path: [Route]

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var search = ""
    @State private var rarity: RarityFilter = .all

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 8)]

    enum RarityFilter: String, CaseIterable, Identifiable {
        case all
        case silver
        case gold
        case prismatic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "Tümü"
            case .silver: "Gümüş"
            case .gold: "Altın"
            case .prismatic: "Prizmatik"
            }
        }

        func matches(_ value: AugmentRarity) -> Bool {
            switch self {
            case .all: true
            case .silver: value == .silver
            case .gold: value == .gold
            case .prismatic: value == .prismatic
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Nadirlik", selection: $rarity) {
                    ForEach(RarityFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                ScrollView {
                    Group {
                        if augments.isEmpty {
                            EmptyStateView(
                                title: store.hasData ? "Sonuç yok" : "Veri bulunamadı",
                                message: store.hasData ? "Başka bir isim dene." : "Güçlendirme verisi henüz yüklenmedi.",
                                systemImage: "sparkles"
                            )
                        } else {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(augments) { augment in
                                    NavigationLink(value: Route.augment(augment.id)) {
                                        AugmentRowView(augment: augment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Theme.background)
            .navigationTitle("Güçlendirmeler")
            .searchable(text: $search, prompt: "Güçlendirme ara")
            .hexKocDestinations()
        }
    }

    private var augments: [Augment] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return store.augments
            .filter { rarity.matches($0.rarity) }
            .filter { augment in
                guard !query.isEmpty else { return true }
                return augment.name.tr.localizedCaseInsensitiveContains(query)
                    || augment.name.en.localizedCaseInsensitiveContains(query)
            }
            .sorted { lhs, rhs in
                let left = lhs.metaTier?.rank ?? Int.max
                let right = rhs.metaTier?.rank ?? Int.max
                if left != right { return left < right }
                return lhs.name.tr.localizedCaseInsensitiveCompare(rhs.name.tr) == .orderedAscending
            }
    }
}

struct AugmentRowView: View {
    let augment: Augment
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card(padding: 10) {
            HStack(spacing: 10) {
                AugmentIcon(augment: augment, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.rarity(augment.rarity))
                            .frame(width: 7, height: 7)
                        Text(augment.name.text(settings.nameLanguage))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                    }
                    Chip(text: augment.category.title, color: Theme.secondaryText)
                }

                Spacer(minLength: 4)

                if let tier = augment.metaTier {
                    MetaTierBadge(tier: tier)
                }
            }
        }
        .frame(minHeight: Theme.rowMinHeight)
    }
}

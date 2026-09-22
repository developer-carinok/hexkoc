import SwiftUI

struct CompListView: View {
    @Binding var path: [Route]

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var search = ""
    @State private var filter: CompFilter = .all
    @State private var easyOnly = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                    header
                    filters

                    if !store.hasData {
                        EmptyStateView(
                            title: "Veri bulunamadı",
                            message: "Komp verisi henüz yüklenmedi. Ayarlar'dan güncellemeyi deneyebilirsin.",
                            systemImage: "square.stack.3d.up.slash"
                        )
                    } else if groups.isEmpty {
                        EmptyStateView(
                            title: "Sonuç yok",
                            message: "Aramanı veya filtreleri değiştirmeyi dene.",
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        ForEach(groups, id: \.tier) { group in
                            Section {
                                ForEach(group.comps) { comp in
                                    NavigationLink(value: Route.comp(comp.id)) {
                                        CompRowView(comp: comp)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                tierHeader(group.tier, count: group.comps.count)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Komplar")
            .searchable(text: $search, prompt: "Komp veya şampiyon ara")
            .hexKocDestinations()
        }
        // Yatayda komp detayı oyun moduna geçip tüm ekranı kullanıyor. Gizleme yığının
        // kökünde duruyor; itilmiş ekranda yapılırsa sekme çubuğu geri gelmiyor.
        .toolbar(hidesTabBar ? .hidden : .visible, for: .tabBar)
    }

    /// Yatayda bir detay açıkken sekme çubuğu yer kaplamasın.
    private var hidesTabBar: Bool {
        verticalSizeClass == .compact && !path.isEmpty
    }

    private var header: some View {
        Text("Yama \(store.patch) · \(sourceSummary) · \(Format.dateTime(store.generatedDate))")
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 4)
    }

    /// Kaynak listesi geldiyse kaç kaynaktan derlendiğini yaz.
    private var sourceSummary: String {
        let count = store.compSources.count
        return count > 0 ? "\(count) kaynak" : "MetaTFT verisi"
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CompFilter.allCases) { option in
                        Button {
                            filter = option
                            Haptics.tap()
                        } label: {
                            Chip(text: option.title, color: Theme.accent, filled: filter == option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            Toggle("Sadece kolay komplar", isOn: $easyOnly)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .tint(Theme.accent)
        }
        .padding(.bottom, 4)
    }

    private func tierHeader(_ tier: CompTier, count: Int) -> some View {
        HStack(spacing: 8) {
            TierBadge(tier: tier, size: 24)
            Text("\(tier.rawValue) seviye")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.text)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    // MARK: - Süzme

    private var groups: [(tier: CompTier, comps: [Comp])] {
        let filtered = store.comps.filter { comp in
            guard filter.matches(comp.playstyle) else { return false }
            guard !easyOnly || comp.difficulty == .easy else { return false }
            return matchesSearch(comp)
        }
        return CompTier.allCases.compactMap { tier in
            let comps = filtered.filter { $0.tier == tier }
            return comps.isEmpty ? nil : (tier, comps)
        }
    }

    private func matchesSearch(_ comp: Comp) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if comp.name.tr.localizedCaseInsensitiveContains(query) { return true }
        if comp.name.en.localizedCaseInsensitiveContains(query) { return true }
        return comp.units.contains { unit in
            guard let champion = store.champion(unit.id) else { return false }
            return champion.name.tr.localizedCaseInsensitiveContains(query)
                || champion.name.en.localizedCaseInsensitiveContains(query)
        }
    }
}

enum CompFilter: String, CaseIterable, Identifiable {
    case all
    case fast8
    case fast9
    case reroll
    case standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Tümü"
        case .fast8: "Hızlı 8"
        case .fast9: "Hızlı 9"
        case .reroll: "Yeniden Çevir"
        case .standard: "Standart"
        }
    }

    func matches(_ playstyle: Playstyle) -> Bool {
        switch self {
        case .all: true
        case .fast8: playstyle == .fast8
        case .fast9: playstyle == .fast9
        case .reroll: playstyle == .reroll5 || playstyle == .reroll6 || playstyle == .reroll7
        case .standard: playstyle == .standard
        }
    }
}

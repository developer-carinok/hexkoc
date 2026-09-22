import SwiftUI

struct CompDetailView: View {
    let compID: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var toast: String?
    @State private var layout: CGSize = .zero

    /// Bu genişlikten sonra yatay "oyun modu" açılır (yatay iPhone hâlâ compact sınıfta).
    private static let gameModeWidth: CGFloat = 640

    var body: some View {
        Group {
            if let comp = store.comp(compID) {
                if isGameMode {
                    CompGameModeView(comp: comp, toast: $toast)
                } else {
                    ScrollView {
                        cards(comp)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                    }
                    .navigationTitle(comp.name.text(settings.nameLanguage))
                }
            } else {
                EmptyStateView(title: "Komp bulunamadı", message: "Bu komp güncel veride yok.")
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { layout = $0 }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        // Oyun modu kendi üst çubuğunu taşır; ekranın tamamı içeriğe kalsın.
        // (Sekme çubuğunu CompListView gizler: itilmiş ekranda geri açılmıyor.)
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        .toast($toast)
    }

    private var isGameMode: Bool { layout.width >= Self.gameModeWidth }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private func cards(_ comp: Comp) -> some View {
        LazyVStack(spacing: 12) {
            CompHeaderCard(comp: comp)
            if !(comp.sources ?? []).isEmpty {
                CompSourcesRow(comp: comp)
            }
            CompTeamCodeCard(comp: comp, toast: $toast)
            CompBoardCard(comp: comp, maxBoardHeight: boardMaxHeight)
            remainingCards(comp)
        }
    }

    @ViewBuilder
    private func remainingCards(_ comp: Comp) -> some View {
        CompUnitsCard(comp: comp)
        if !comp.boardLevels.isEmpty {
            CompLevelBoardsCard(comp: comp)
        }
        if !comp.traits.isEmpty {
            CompTraitsCard(comp: comp)
        }
        if !comp.augments.isEmpty {
            CompAugmentsCard(comp: comp)
        }
        if !comp.counters.isEmpty || !comp.goodAgainst.isEmpty {
            CompMatchupsCard(comp: comp)
        }
        if !(comp.sourceTips ?? []).isEmpty {
            CompSourceTipsCard(comp: comp)
        }
        if !comp.tips(settings.nameLanguage).isEmpty {
            CompTipsCard(comp: comp)
        }
        Text("Veri: \(dataCredit(comp))")
            .font(.caption2)
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 4)
    }

    /// Kompu besleyen kaynaklar; veri eski biçimdeyse MetaTFT'ye düşer.
    private func dataCredit(_ comp: Comp) -> String {
        let labels = (comp.sources ?? []).map(\.title)
        return labels.isEmpty ? "MetaTFT · CommunityDragon" : labels.joined(separator: " · ")
    }

    /// Tahta ekranın %70'inden uzun olmasın; yatayda kaydırmadan görünsün.
    private var boardMaxHeight: CGFloat {
        layout.height > 0 ? layout.height * 0.7 : .infinity
    }
}

struct CompHeaderCard: View {
    let comp: Comp
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    TierBadge(tier: comp.tier, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(comp.name.text(settings.nameLanguage))
                            .font(.title3.bold())
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    Chip(text: comp.playstyle.title, color: Theme.accent)
                    Chip(text: comp.difficulty.title, color: Theme.secondaryText)
                    Chip(text: comp.trend.title, systemImage: comp.trend.symbol, color: Theme.trend(comp.trend))
                }

                HStack(spacing: 0) {
                    statColumn("Ort. sıralama", Format.placement(comp.stats.avgPlacement))
                    Divider().frame(height: 28).overlay(Theme.hairline)
                    statColumn("Seçilme", Format.percent(comp.stats.playRate, fractionDigits: 2))
                    Divider().frame(height: 28).overlay(Theme.hairline)
                    statColumn("Oyun", Format.count(comp.stats.games))
                }
            }
        }
    }

    /// Küratörlü İngilizce başlık varsa onu, yoksa diğer dildeki ismi göster.
    private var subtitle: String? {
        guard let curated = comp.subtitle?.text(.en), !curated.isEmpty else {
            return settings.subtitle(for: comp.name)
        }
        guard settings.showEnglishSubtitle, curated != comp.name.text(settings.nameLanguage) else { return nil }
        return curated
    }

    private func statColumn(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Theme.text)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

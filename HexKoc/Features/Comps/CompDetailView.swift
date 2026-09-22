import SwiftUI

struct CompDetailView: View {
    let compID: String

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var toast: String?
    @State private var layout: CGSize = .zero

    /// Bu genişlikten sonra kartlar iki sütuna ayrılır (yatay iPhone hâlâ compact sınıfta).
    private static let twoColumnWidth: CGFloat = 640

    var body: some View {
        Group {
            if let comp = store.comp(compID) {
                ScrollView {
                    cards(comp)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }
                .navigationTitle(comp.name.text(settings.nameLanguage))
            } else {
                EmptyStateView(title: "Komp bulunamadı", message: "Bu komp güncel veride yok.")
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { layout = $0 }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    /// Yatayda sol sütun tahtayı, sağ sütun kodu ve birimleri tutar:
    /// üçü de kaydırmadan görünsün diye tahta en üste alınır. Dikeyde sıra değişmez.
    @ViewBuilder
    private func cards(_ comp: Comp) -> some View {
        if layout.width >= Self.twoColumnWidth {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    CompBoardCard(comp: comp, maxBoardHeight: boardMaxHeight)
                    CompHeaderCard(comp: comp)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    CompTeamCodeCard(comp: comp, toast: $toast)
                    remainingCards(comp)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            LazyVStack(spacing: 12) {
                CompHeaderCard(comp: comp)
                CompTeamCodeCard(comp: comp, toast: $toast)
                CompBoardCard(comp: comp, maxBoardHeight: boardMaxHeight)
                remainingCards(comp)
            }
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
        if !comp.tips(settings.nameLanguage).isEmpty {
            CompTipsCard(comp: comp)
        }
        Text("Veri: MetaTFT · CommunityDragon")
            .font(.caption2)
            .foregroundStyle(Theme.secondaryText)
            .padding(.top, 4)
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
                        if let subtitle = settings.subtitle(for: comp.name) {
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

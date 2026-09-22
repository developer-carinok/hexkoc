import SwiftUI

/// Yatay "oyun modu". Kullanıcı TFT'yi yatay oynayıp birkaç saniyeliğine buraya geçiyor:
/// kart yığını yerine, altı sayfalık kaydırmasız bir panel. Sayfa seçimi hatırlanır.
struct CompGameModeView: View {
    let comp: Comp
    @Binding var toast: String?

    @AppStorage("gameModePage") private var page: GameModePage = .early
    @State private var pageSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 6) {
            GameModeTopBar(comp: comp, toast: $toast)
            // Rozet satırı sayfa alanından en fazla 26 pt alır.
            if !(comp.sources ?? []).isEmpty {
                CompSourcesRow(comp: comp, compact: true)
            }
            GameModeTabBar(page: $page)

            TabView(selection: $page) {
                ForEach(GameModePage.allCases) { item in
                    ScrollView {
                        content(item)
                            .frame(maxWidth: .infinity, minHeight: measuredSize.height, alignment: .topLeading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { pageSize = $0 }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Theme.background)
    }

    @ViewBuilder
    private func content(_ item: GameModePage) -> some View {
        switch item {
        case .early: GameModeEarlyPage(comp: comp, pageSize: measuredSize)
        case .mid: GameModeMidPage(comp: comp, pageSize: measuredSize)
        case .board: GameModeBoardPage(comp: comp, pageSize: measuredSize)
        case .items: GameModeItemsPage(comp: comp, pageSize: measuredSize)
        case .augments: GameModeAugmentsPage(comp: comp)
        case .tips: GameModeTipsPage(comp: comp, pageSize: measuredSize)
        }
    }

    /// İlk karede ölçüm gelmeden makul bir varsayılan kullan.
    private var measuredSize: CGSize {
        CGSize(
            width: pageSize.width > 0 ? pageSize.width : 720,
            height: pageSize.height > 0 ? pageSize.height : 240
        )
    }
}

/// Oyun modunun sayfaları. Ham değer `@AppStorage`'da saklanır.
enum GameModePage: Int, CaseIterable, Identifiable {
    case early
    case mid
    case board
    case items
    case augments
    case tips

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .early: "Erken Oyun"
        case .mid: "Orta Oyun"
        case .board: "Son Tahta"
        case .items: "Eşyalar"
        case .augments: "Güçlendirme"
        case .tips: "İpuçları"
        }
    }

    var symbol: String {
        switch self {
        case .early: "sunrise.fill"
        case .mid: "sun.max.fill"
        case .board: "hexagon.fill"
        case .items: "shield.lefthalf.filled"
        case .augments: "sparkles"
        case .tips: "lightbulb.fill"
        }
    }
}

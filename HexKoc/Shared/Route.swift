import SwiftUI

/// Her ekran her varlığa gidebilsin diye tek bir değer tipi.
enum Route: Hashable {
    case comp(String)
    case champion(String)
    case trait(String)
    case item(String)
    case augment(String)
    case article(String)
}

extension View {
    /// Tüm sekmelerin NavigationStack'ine aynı hedefleri bağlar.
    func hexKocDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .comp(let id): CompDetailView(compID: id)
            case .champion(let id): ChampionDetailView(championID: id)
            case .trait(let id): TraitDetailView(traitID: id)
            case .item(let id): ItemDetailView(itemID: id)
            case .augment(let id): AugmentDetailView(augmentID: id)
            case .article(let id): ArticleView(articleID: id)
            }
        }
    }

    /// Koyu zemin + kaydırmaya uygun arkaplan.
    func hexKocBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

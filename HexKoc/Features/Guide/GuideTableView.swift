import SwiftUI

/// `[[table:*]]` gömülerini gerçek tablolara çevirir.
struct GuideTableView: View {
    let kind: GuideTableKind
    @Environment(DataStore.self) private var store

    var body: some View {
        switch kind {
        case .shopOdds:
            Card { ShopOddsTable(rules: store.rules) }
        case .xp:
            Card { XPTable(rules: store.rules) }
        case .poolSizes:
            Card { PoolSizeTable(rules: store.rules) }
        case .economy:
            Card { EconomyTable(rules: store.rules) }
        case .itemRecipes:
            RecipeTableView(components: store.components)
        case .unknown:
            EmptyView()
        }
    }
}

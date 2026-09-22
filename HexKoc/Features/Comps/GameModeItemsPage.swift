import SwiftUI

/// "Hangi şampiyona hangi eşya": taşıyıcılar önce, her satırda birim → eşya kartları.
/// Eşya kartı bileşenleri de gösterir; oyunda hangi parçayı saklayacağın belli olsun.
struct GameModeItemsPage: View {
    let comp: Comp
    let pageSize: CGSize

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private static let columns = 2
    private static let columnSpacing: CGFloat = 12
    private static let rowSpacing: CGFloat = 8
    private static let cardSpacing: CGFloat = 6
    private static let arrowWidth: CGFloat = 14
    private static let nameHeight: CGFloat = 26
    private static let recipeHeight: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            if units.isEmpty {
                Text("Bu komp için eşya önerisi yok.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(Array(unitRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: Self.columnSpacing) {
                        ForEach(0..<Self.columns, id: \.self) { index in
                            Group {
                                if index < row.count {
                                    unitRow(row[index])
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private func unitRow(_ unit: CompUnit) -> some View {
        HStack(alignment: .top, spacing: Self.cardSpacing) {
            UnitTile(unit: unit, size: tileSize, showItems: false)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: Self.arrowWidth)
                .padding(.top, UnitTile.starHeight + tileSize * 0.4)
                .accessibilityHidden(true)

            ForEach(Array(unit.items.prefix(3).enumerated()), id: \.offset) { _, itemID in
                itemCard(itemID)
            }
            Spacer(minLength: 0)
        }
    }

    private func itemCard(_ itemID: String) -> some View {
        let item = store.item(itemID)
        return NavigationLink(value: Route.item(itemID)) {
            VStack(spacing: 3) {
                ItemIcon(item: item, size: iconSize)
                Text(item?.name.text(settings.nameLanguage) ?? itemID)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(height: Self.nameHeight)
                recipeRow(item)
            }
            .frame(width: cardWidth)
            .padding(.vertical, 5)
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item?.name.text(settings.nameLanguage) ?? itemID)
    }

    @ViewBuilder
    private func recipeRow(_ item: Item?) -> some View {
        if let recipe = item?.recipe, recipe.count == 2 {
            HStack(spacing: 3) {
                ItemIcon(item: store.item(recipe[0]), size: Self.recipeHeight)
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                ItemIcon(item: store.item(recipe[1]), size: Self.recipeHeight)
            }
            .frame(height: Self.recipeHeight)
            .accessibilityHidden(true)
        } else {
            Color.clear.frame(height: Self.recipeHeight)
        }
    }

    /// Önce taşıyıcılar, sonra eşyası olan diğer birimler.
    private var units: [CompUnit] {
        let withItems = comp.units.filter { !$0.items.isEmpty }
        return withItems.filter(\.isCarry) + withItems.filter { !$0.isCarry }
    }

    private var unitRows: [[CompUnit]] {
        stride(from: 0, to: units.count, by: Self.columns).map {
            Array(units[$0..<min($0 + Self.columns, units.count)])
        }
    }

    private var rowHeight: CGFloat {
        let rows = CGFloat(max(unitRows.count, 1))
        return max((pageSize.height - Self.rowSpacing * (rows - 1)) / rows, 92)
    }

    private var iconSize: CGFloat {
        let chrome = 3 + Self.nameHeight + 3 + Self.recipeHeight + 10
        return min(max(rowHeight - chrome, 26), 52)
    }

    private var tileSize: CGFloat {
        min(max(rowHeight - UnitTile.chromeHeight(showItems: false) - UnitTile.spacing, UnitTile.minSize), 56)
    }

    private var cardWidth: CGFloat {
        let cellWidth = (pageSize.width - Self.columnSpacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
        let used = tileSize + UnitTile.horizontalPadding + Self.arrowWidth + Self.cardSpacing * 4
        return max((cellWidth - used) / 3, 56)
    }
}

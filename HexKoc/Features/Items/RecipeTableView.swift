import SwiftUI

/// 10 × 10 tarif tablosu. Yatay kaydırılır.
struct RecipeTableView: View {
    let components: [Item]
    @Environment(DataStore.self) private var store

    private let cell: CGFloat = 30
    private let spacing: CGFloat = 3

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Tarif Tablosu", subtitle: "\(components.count) bileşen")

                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: spacing) {
                        HStack(spacing: spacing) {
                            Color.clear.frame(width: cell, height: cell)
                            ForEach(components) { column in
                                ItemIcon(item: column, size: cell)
                            }
                        }
                        ForEach(components) { row in
                            HStack(spacing: spacing) {
                                ItemIcon(item: row, size: cell)
                                ForEach(components) { column in
                                    resultCell(row: row, column: column)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func resultCell(row: Item, column: Item) -> some View {
        if let result = store.itemsByRecipe(row.id, column.id) {
            NavigationLink(value: Route.item(result.id)) {
                ItemIcon(item: result, size: cell)
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: cell * 0.2)
                .fill(Theme.elevated.opacity(0.5))
                .frame(width: cell, height: cell)
        }
    }
}

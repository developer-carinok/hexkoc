import SwiftUI

/// Oyun modunun yapı taşı: 3★ göstergesi, maliyet çerçeveli ikon, ismin kendisi
/// ve birimin eşyaları. İkon asla isimsiz gösterilmez — maç sırasında tek bakışta okunur.
struct UnitTile: View {
    let unit: CompUnit
    var size: CGFloat = 56
    var showItems: Bool = true

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let champion = store.champion(unit.id)
        NavigationLink(value: Route.champion(champion?.id ?? unit.id)) {
            VStack(spacing: Self.spacing) {
                stars
                icon(champion)
                Text(champion?.name.text(settings.nameLanguage) ?? unit.id)
                    .font(.system(size: Self.nameFontSize, weight: unit.isCarry ? .bold : .semibold))
                    .foregroundStyle(unit.isCarry ? Theme.accent : Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: Self.nameHeight)
                if showItems, !items.isEmpty {
                    ItemStrip(itemIDs: items, size: itemSize)
                }
            }
            .frame(width: size + Self.horizontalPadding)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(champion))
    }

    private var stars: some View {
        Group {
            if unit.stars >= 3 {
                StarMarker(size: Self.starHeight * 0.8)
            } else {
                Color.clear
            }
        }
        .frame(height: Self.starHeight)
    }

    private func icon(_ champion: Champion?) -> some View {
        IconView(path: champion?.icon, url: champion?.iconURL, size: size, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.14)
                    .strokeBorder(Theme.cost(champion?.cost ?? 1), lineWidth: 2)
            )
            // Taşıyıcı: ikonun altında ince altın çizgi.
            .overlay(alignment: .bottom) {
                if unit.isCarry {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: size * 0.55, height: 2.5)
                        .offset(y: 1.5)
                }
            }
    }

    private var items: [String] { Array(unit.items.prefix(3)) }

    /// Üç eşya ikon genişliğine sığsın.
    private var itemSize: CGFloat { min(Self.itemHeight, (size - 4) / 3) }

    private func accessibilityLabel(_ champion: Champion?) -> String {
        var parts = [champion?.name.text(settings.nameLanguage) ?? unit.id]
        if unit.stars >= 3 { parts.append("3 yıldız hedefi") }
        if unit.isCarry { parts.append("Taşıyıcı") }
        if showItems, !items.isEmpty {
            parts.append(items.compactMap { store.item($0)?.name.text(settings.nameLanguage) }.joined(separator: ", "))
        }
        return parts.joined(separator: ", ")
    }
}

extension UnitTile {
    static let spacing: CGFloat = 3
    static let starHeight: CGFloat = 10
    static let nameHeight: CGFloat = 13
    static let nameFontSize: CGFloat = 11
    static let itemHeight: CGFloat = 16
    static let horizontalPadding: CGFloat = 6
    static let minSize: CGFloat = 26
    static let maxSize: CGFloat = 64

    /// İkonun dışında kalan sabit yükseklik (yıldız + isim + eşya şeridi).
    static func chromeHeight(showItems: Bool) -> CGFloat {
        starHeight + spacing + nameHeight + (showItems ? spacing + itemHeight : 0)
    }
}

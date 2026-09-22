import SwiftUI

/// Kare şampiyon simgesi, maliyet renginde 2 px çerçeve.
struct ChampionIcon: View {
    let champion: Champion?
    var size: CGFloat = 48
    var stars: Int = 2

    var body: some View {
        VStack(spacing: 2) {
            if stars >= 3 {
                StarMarker(size: max(6, size * 0.16))
            }
            IconView(path: champion?.icon, url: champion?.iconURL, size: size, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.14)
                        .strokeBorder(Theme.cost(champion?.cost ?? 1), lineWidth: 2)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(champion?.name.tr ?? "Bilinmeyen şampiyon")
    }
}

struct ItemIcon: View {
    let item: Item?
    var size: CGFloat = 22

    var body: some View {
        IconView(path: item?.icon, url: item?.iconURL, size: size, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
            .accessibilityLabel(item?.name.tr ?? "Eşya")
    }
}

struct TraitIcon: View {
    let trait: Trait?
    var size: CGFloat = 20
    var style: TraitStyle = .none

    var body: some View {
        IconView(path: trait?.icon, url: trait?.iconURL, size: size)
            .foregroundStyle(Theme.traitStyle(style))
            .accessibilityLabel(trait?.name.tr ?? "Özellik")
    }
}

struct AugmentIcon: View {
    let augment: Augment?
    var size: CGFloat = 34

    var body: some View {
        IconView(path: augment?.icon, url: augment?.iconURL, size: size, contentMode: .fill)
            .clipShape(HexagonShape())
            .accessibilityLabel(augment?.name.tr ?? "Güçlendirme")
    }
}

/// Bir taşıyıcının eşyalarını simge şeridi olarak gösterir.
struct ItemStrip: View {
    let itemIDs: [String]
    var size: CGFloat = 16
    @Environment(DataStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(itemIDs.enumerated()), id: \.offset) { _, id in
                ItemIcon(item: store.item(id), size: size)
            }
        }
    }
}

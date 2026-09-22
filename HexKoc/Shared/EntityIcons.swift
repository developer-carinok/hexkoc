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

/// Güçlendirme rozeti: altıgen simge + isim.
struct AugmentChip: View {
    let augmentID: String
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let augment = store.augment(augmentID)
        let color = Theme.rarity(augment?.rarity ?? .unknown)
        return HStack(spacing: 6) {
            AugmentIcon(augment: augment, size: 26)
            Text(augment?.name.text(settings.nameLanguage) ?? augmentID)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
    }
}

/// Aktif özellik rozeti: simge + isim + birim sayısı, kademe renginde.
struct TraitCountChip: View {
    let entry: CompTrait
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let trait = store.trait(entry.id)
        let color = Theme.traitStyle(entry.style)
        return HStack(spacing: 5) {
            TraitIcon(trait: trait, size: 16, style: entry.style)
            Text(trait?.name.text(settings.nameLanguage) ?? entry.id)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("\(entry.count)")
                .font(.caption.bold().monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
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

/// Alternatif eşya kurgusu: birim → eşyalar.
struct AltBuildChip: View {
    let build: AltBuild
    var iconSize: CGFloat = 22
    var itemSize: CGFloat = 16

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let champion = store.champion(build.unit)
        return NavigationLink(value: Route.champion(champion?.id ?? build.unit)) {
            HStack(spacing: 5) {
                ChampionIcon(champion: champion, size: iconSize)
                Text(champion?.name.text(settings.nameLanguage) ?? build.unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .accessibilityHidden(true)
                ItemStrip(itemIDs: build.items, size: itemSize)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Theme.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

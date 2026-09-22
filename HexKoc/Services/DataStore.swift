import Foundation
import Observation

/// Uygulamanın tek veri kaynağı. Açılışta paketteki JSON'u okur, daha yeni bir
/// önbellek varsa ona geçer, sonra arka planda uzak sunucuyu yoklar.
@MainActor
@Observable
final class DataStore {
    private(set) var gameData: GameData
    private(set) var compsFile: CompsFile
    private(set) var guidesFile: GuidesFile
    private(set) var isRefreshing = false
    /// Ayarlar ekranında gösterilecek son güncelleme sonucu.
    private(set) var lastRefreshMessage: String?

    private var championsByID: [String: Champion] = [:]
    private var traitsByID: [String: Trait] = [:]
    private var itemsByID: [String: Item] = [:]
    private var augmentsByID: [String: Augment] = [:]
    private var compsByID: [String: Comp] = [:]
    private var compsByChampion: [String: [String]] = [:]
    private var itemsByRecipePair: [Set<String>: Item] = [:]

    init(bundle: DataBundle? = nil) {
        let loaded = bundle ?? Self.bestAvailable()
        gameData = loaded.gameData
        compsFile = loaded.comps
        guidesFile = loaded.guides
        rebuildIndexes()
    }

    private static func bestAvailable() -> DataBundle {
        let bundled = DataLoader.loadBundled()
        guard let cached = DataLoader.loadCached(), cached.isUsable else { return bundled }
        guard let cachedDate = cached.generatedDate else { return bundled }
        guard let bundledDate = bundled.generatedDate else { return cached }
        return cachedDate > bundledDate ? cached : bundled
    }

    // MARK: - Durum

    var comps: [Comp] { compsFile.comps }
    var champions: [Champion] { gameData.champions }
    var traits: [Trait] { gameData.traits }
    var items: [Item] { gameData.items }
    var augments: [Augment] { gameData.augments }
    var rules: Rules { gameData.rules }
    var articles: [GuideArticle] { guidesFile.articles }

    /// Komp verisini besleyen kaynaklar; eski dosyalarda boş.
    var compSources: [SourceStatus] { compsFile.sources ?? [] }

    var patch: String {
        let value = gameData.set.patch.isEmpty ? compsFile.patch : gameData.set.patch
        return value.isEmpty ? "—" : value
    }

    var generatedDate: Date? { compsFile.generatedDate ?? gameData.generatedDate }

    /// Boru hattı henüz veri üretmediyse arayüz boş durum gösterir.
    var hasData: Bool { !gameData.champions.isEmpty }

    var components: [Item] { items.filter { $0.kind == .component } }

    // MARK: - Aramalar

    func champion(_ id: String?) -> Champion? {
        guard let id else { return nil }
        return championsByID[id]
    }

    func trait(_ id: String?) -> Trait? {
        guard let id else { return nil }
        return traitsByID[id]
    }

    func item(_ id: String?) -> Item? {
        guard let id else { return nil }
        return itemsByID[id]
    }

    func augment(_ id: String?) -> Augment? {
        guard let id else { return nil }
        return augmentsByID[id]
    }

    func comp(_ id: String?) -> Comp? {
        guard let id else { return nil }
        return compsByID[id]
    }

    func article(_ id: String?) -> GuideArticle? {
        guard let id else { return nil }
        return articles.first { $0.id == id }
    }

    func compsUsing(champion id: String) -> [Comp] {
        (compsByChampion[id] ?? []).compactMap { compsByID[$0] }
    }

    func itemsByRecipe(_ componentA: String, _ componentB: String) -> Item? {
        itemsByRecipePair[Set([componentA, componentB])]
    }

    func champions(inTrait id: String) -> [Champion] {
        guard let trait = traitsByID[id] else { return [] }
        return trait.champions.compactMap { championsByID[$0] }
    }

    func comps(carrying itemID: String) -> [Comp] {
        comps.filter { comp in comp.units.contains { $0.items.contains(itemID) } }
    }

    func comps(recommending augmentID: String) -> [Comp] {
        comps.filter { comp in comp.augments.values.contains { $0.contains(augmentID) } }
    }

    /// Seviye tahtasındaki id'leri gösterilebilir birimlere çevirir: id kompun birim
    /// listesindeyse eşyaları ve yıldızıyla, değilse yalın olarak. Bilinmeyen id atlanır.
    func units(_ ids: [String], in comp: Comp) -> [CompUnit] {
        ids.compactMap { id in
            guard let champion = champion(id) else { return nil }
            let match = comp.units.first { (self.champion($0.id)?.id ?? $0.id) == champion.id }
            return match ?? CompUnit(id: champion.id)
        }
    }

    /// Bir kompun aktif özelliklerini, isimleriyle birlikte.
    func resolvedTraits(of comp: Comp) -> [(trait: Trait, entry: CompTrait)] {
        comp.traits.compactMap { entry in
            traitsByID[entry.id].map { (trait: $0, entry: entry) }
        }
    }

    // MARK: - Yenileme

    func refresh(force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let current = force ? nil : generatedDate
        switch await RemoteDataService.refreshIfNeeded(currentGeneratedAt: current) {
        case .upToDate:
            lastRefreshMessage = "Veriler zaten güncel."
        case .updated(let bundle):
            apply(bundle)
            lastRefreshMessage = "Veriler güncellendi."
        case .failed(let reason):
            lastRefreshMessage = reason
        }
    }

    private func apply(_ bundle: DataBundle) {
        guard bundle.isUsable else { return }
        gameData = bundle.gameData
        compsFile = bundle.comps
        guidesFile = bundle.guides
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        championsByID = [:]
        for champion in gameData.champions {
            championsByID[champion.id] = champion
            for alias in champion.aliases { championsByID[alias] = champion }
        }
        traitsByID = Dictionary(gameData.traits.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        itemsByID = Dictionary(gameData.items.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        augmentsByID = Dictionary(gameData.augments.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        compsByID = Dictionary(compsFile.comps.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })

        itemsByRecipePair = [:]
        for item in gameData.items {
            guard let pair = item.recipePair else { continue }
            // Aynı tariften birden fazla varsa birleştirilmiş eşyayı tercih et.
            if let existing = itemsByRecipePair[pair], existing.kind == .craftable { continue }
            itemsByRecipePair[pair] = item
        }

        compsByChampion = [:]
        for comp in compsFile.comps {
            for unit in comp.units {
                let canonical = championsByID[unit.id]?.id ?? unit.id
                compsByChampion[canonical, default: []].append(comp.id)
            }
        }
    }
}

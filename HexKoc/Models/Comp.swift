import Foundation

enum CompTier: String, TolerantEnum, CaseIterable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"

    static let unknownCase = CompTier.c

    var rank: Int {
        switch self {
        case .s: 0
        case .a: 1
        case .b: 2
        case .c: 3
        }
    }
}

enum Playstyle: String, TolerantEnum {
    case fast8
    case fast9
    case reroll5
    case reroll6
    case reroll7
    case standard

    static let unknownCase = Playstyle.standard

    var title: String {
        switch self {
        case .fast8: "Hızlı 8"
        case .fast9: "Hızlı 9"
        case .reroll5: "5. sv Reroll"
        case .reroll6: "6. sv Reroll"
        case .reroll7: "7. sv Reroll"
        case .standard: "Standart"
        }
    }

    /// Oyun modunda erken oyun sayfasındaki tek cümlelik yol haritası.
    var plan: String {
        switch self {
        case .fast8: "Ekonomi yap, 8'e koş."
        case .fast9: "Ekonomi yap, 9'a koş."
        case .reroll5: "5. seviyede dur ve çevir."
        case .reroll6: "6. seviyede dur ve çevir."
        case .reroll7: "7. seviyede dur ve çevir."
        case .standard: "Seviye atla, tahtayı güçlü tut."
        }
    }

    var isReroll: Bool {
        switch self {
        case .reroll5, .reroll6, .reroll7: true
        case .fast8, .fast9, .standard: false
        }
    }
}

enum Difficulty: String, TolerantEnum {
    case easy
    case medium
    case hard

    static let unknownCase = Difficulty.medium

    var title: String {
        switch self {
        case .easy: "Kolay"
        case .medium: "Orta"
        case .hard: "Zor"
        }
    }
}

enum Trend: String, TolerantEnum {
    case rising
    case falling
    case stable

    static let unknownCase = Trend.stable

    var symbol: String {
        switch self {
        case .rising: "arrow.up.right"
        case .falling: "arrow.down.right"
        case .stable: "minus"
        }
    }

    var title: String {
        switch self {
        case .rising: "Yükselişte"
        case .falling: "Düşüşte"
        case .stable: "Sabit"
        }
    }
}

struct CompsFile: Decodable {
    var schemaVersion: Int
    var generatedAt: String
    var source: String
    var set: String
    var patch: String
    var clusterId: Int?
    var comps: [Comp]
    /// Boru hattının kullandığı kaynaklar ve son çekim durumu.
    var sources: [SourceStatus]?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, source, set, patch, clusterId, comps, sources
    }

    init() {
        schemaVersion = DataSchema.version
        generatedAt = ""
        source = "MetaTFT"
        set = "TFTSet18"
        patch = ""
        clusterId = nil
        comps = []
        sources = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.value(.schemaVersion, DataSchema.version)
        generatedAt = c.value(.generatedAt, "")
        source = c.value(.source, "MetaTFT")
        set = c.value(.set, "TFTSet18")
        patch = c.value(.patch, "")
        clusterId = c.maybe(.clusterId)
        comps = c.value(.comps, [])
        sources = c.maybe(.sources)
    }

    var generatedDate: Date? { ISO8601.date(generatedAt) }
}

struct Comp: Decodable, Identifiable, Hashable {
    var id: String
    var name: LocalizedText
    var tier: CompTier
    var playstyle: Playstyle
    var difficulty: Difficulty
    var stats: CompStats
    var trend: Trend
    var units: [CompUnit]
    var traits: [CompTrait]
    var teamCode: String
    var levelBoards: [String: [String]]
    var earlyBoards: [String: [String]]
    var levelTiming: [LevelTiming]
    var augments: [String: [String]]
    var counters: [CompMatchup]
    var goodAgainst: [CompMatchup]
    var starPriority: [String]
    var coreUnits: [String]
    var tips: [String: [String]]
    /// Kompu listeleyen kaynaklar, ağırlık sırasında.
    var sources: [CompSource]?
    var sourceCount: Int?
    /// Harf kademesi veren her kaynak "durumsal" diyorsa true.
    var situational: Bool?
    /// Küratörlü İngilizce başlık; isim satırının altında gösterilir.
    var subtitle: LocalizedText?
    /// Küratörlü erken/orta/tavan tahtaları.
    var stages: CompStages?
    var altBuilds: [AltBuild]?
    /// İlk karusel için bileşen önceliği.
    var carousel: [String]?
    var sourceTips: [SourceTip]?

    private enum CodingKeys: String, CodingKey {
        case id, name, tier, playstyle, difficulty, stats, trend, units, traits, teamCode
        case levelBoards, earlyBoards, levelTiming, augments, counters, goodAgainst
        case starPriority, coreUnits, tips
        case sources, sourceCount, situational, subtitle, stages, altBuilds, carousel, sourceTips
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        name = c.value(.name, .empty)
        tier = c.value(.tier, .c)
        playstyle = c.value(.playstyle, .standard)
        difficulty = c.value(.difficulty, .medium)
        stats = c.value(.stats, CompStats())
        trend = c.value(.trend, .stable)
        units = c.value(.units, [])
        traits = c.value(.traits, [])
        teamCode = c.value(.teamCode, "")
        levelBoards = c.value(.levelBoards, [:])
        earlyBoards = c.value(.earlyBoards, [:])
        levelTiming = c.value(.levelTiming, [])
        augments = c.value(.augments, [:])
        counters = c.value(.counters, [])
        goodAgainst = c.value(.goodAgainst, [])
        starPriority = c.value(.starPriority, [])
        coreUnits = c.value(.coreUnits, [])
        tips = c.value(.tips, [:])
        sources = c.maybe(.sources)
        sourceCount = c.maybe(.sourceCount)
        situational = c.maybe(.situational)
        subtitle = c.maybe(.subtitle)
        stages = c.maybe(.stages)
        altBuilds = c.maybe(.altBuilds)
        carousel = c.maybe(.carousel)
        sourceTips = c.maybe(.sourceTips)
    }

    init(id: String, name: LocalizedText, tier: CompTier = .a, units: [CompUnit] = []) {
        self.id = id
        self.name = name
        self.tier = tier
        self.playstyle = .standard
        self.difficulty = .medium
        self.stats = CompStats()
        self.trend = .stable
        self.units = units
        self.traits = []
        self.teamCode = ""
        self.levelBoards = [:]
        self.earlyBoards = [:]
        self.levelTiming = []
        self.augments = [:]
        self.counters = []
        self.goodAgainst = []
        self.starPriority = []
        self.coreUnits = []
        self.tips = [:]
    }

    func tips(_ language: NameLanguage) -> [String] {
        let primary = tips[language.rawValue] ?? []
        return primary.isEmpty ? (tips[language.other.rawValue] ?? []) : primary
    }

    /// Kompu listeleyen kaynak sayısı; anahtar yoksa kaynak listesinden sayılır.
    var listedSourceCount: Int { sourceCount ?? sources?.count ?? 0 }

    var isSituational: Bool { situational == true }

    /// Küratörlü aşama tahtası; birimi yoksa yok sayılır.
    func stage(_ slot: KeyPath<CompStages, CompStage?>) -> CompStage? {
        guard let stage = stages?[keyPath: slot], !stage.units.isEmpty else { return nil }
        return stage
    }

    /// Rozette kaynağın yanında yazan değer: harf kademesi, yoksa istatistik kaynaklarının
    /// ortalama sıralaması. İkisi de yoksa sadece kaynağın adı gösterilir.
    func sourceValue(for source: CompSource) -> String? {
        if let tier = source.tier, CompSource.letterTiers.contains(tier) { return tier }
        if let score = source.score, score > 0 { return Format.placement(score) }
        guard source.tier == nil, source.key == CompSource.statsKey, stats.avgPlacement > 0 else { return nil }
        return Format.placement(stats.avgPlacement)
    }

    /// İpucundaki kaynak anahtarının okunur adı.
    func sourceLabel(_ key: String) -> String {
        sources?.first { $0.key == key }?.title ?? key
    }

    /// Erken + geç tahtaların seviye anahtarları, artan.
    var boardLevels: [Int] {
        (Array(earlyBoards.keys) + Array(levelBoards.keys)).compactMap(Int.init).sorted()
    }

    func board(level: Int) -> [String] {
        levelBoards[String(level)] ?? earlyBoards[String(level)] ?? []
    }

    /// `earlyBoards` seviyeleri, artan.
    var earlyLevels: [Int] { earlyBoards.keys.compactMap(Int.init).sorted() }

    /// `levelBoards` seviyeleri, artan.
    var lateLevels: [Int] { levelBoards.keys.compactMap(Int.init).sorted() }

    /// İstenen seviyeye en yakın geç oyun tahtası; veri yoksa nil.
    func closestLevelBoard(to level: Int) -> (level: Int, ids: [String])? {
        guard let closest = lateLevels.min(by: { abs($0 - level) < abs($1 - level) }),
              let ids = levelBoards[String(closest)], !ids.isEmpty
        else { return nil }
        return (closest, ids)
    }
}

struct CompStats: Decodable, Hashable {
    var avgPlacement: Double = 0
    var playRate: Double = 0
    var games: Int = 0
    var winRate: Double?
    var top4Rate: Double?

    private enum CodingKeys: String, CodingKey { case avgPlacement, playRate, games, winRate, top4Rate }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avgPlacement = c.value(.avgPlacement, 0)
        playRate = c.value(.playRate, 0)
        games = c.value(.games, 0)
        winRate = c.maybe(.winRate)
        top4Rate = c.maybe(.top4Rate)
    }
}

struct CompUnit: Decodable, Hashable, Identifiable {
    var id: String
    var items: [String]
    var stars: Int
    var isCarry: Bool
    var cell: Int?
    var importance: Double

    private enum CodingKeys: String, CodingKey { case id, items, stars, isCarry, cell, importance }

    init(id: String, items: [String] = [], stars: Int = 2, isCarry: Bool = false, cell: Int? = nil) {
        self.id = id
        self.items = items
        self.stars = stars
        self.isCarry = isCarry
        self.cell = cell
        self.importance = 1
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        items = c.value(.items, [])
        stars = c.value(.stars, 2)
        isCarry = c.value(.isCarry, false)
        cell = c.maybe(.cell)
        importance = c.value(.importance, 0)
    }
}

struct CompTrait: Decodable, Hashable, Identifiable {
    var id: String
    var count: Int
    var style: TraitStyle

    private enum CodingKeys: String, CodingKey { case id, count, style }

    init(id: String, count: Int, style: TraitStyle) {
        self.id = id
        self.count = count
        self.style = style
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        count = c.value(.count, 0)
        style = c.value(.style, .none)
    }
}

struct LevelTiming: Decodable, Hashable, Identifiable {
    var level: Int
    var stage: Int
    var round: Int

    var id: Int { level }

    private enum CodingKeys: String, CodingKey { case level, stage, round }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = c.value(.level, 0)
        stage = c.value(.stage, 0)
        round = c.value(.round, 0)
    }

    var label: String { "\(level). sv → \(stage)-\(round)" }
}

struct CompMatchup: Decodable, Hashable, Identifiable {
    var compId: String
    var placeChange: Double

    var id: String { compId }

    private enum CodingKeys: String, CodingKey { case compId, placeChange }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compId = c.value(.compId, "")
        placeChange = c.value(.placeChange, 0)
    }
}

/// Kompu listeleyen bir kaynak ve o kaynağın kendi kademesi.
struct CompSource: Decodable, Hashable {
    var key: String
    var label: String
    /// Kaynağın harf kademesi; istatistik kaynaklarında null olabilir.
    var tier: String?
    /// Kaynağın kompa verdiği isim.
    var name: String?
    var url: String?
    /// Harf kademesi olmayan kaynaklarda ortalama sıralama.
    var score: Double?

    /// Rozette gösterilebilen harf kademeleri.
    static let letterTiers: Set<String> = ["S+", "S", "A", "B", "C", "D"]

    /// Kademe yerine ortalama sıralama gösteren kaynak.
    static let statsKey = "metatft"

    private enum CodingKeys: String, CodingKey { case key, label, tier, name, url, score }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.value(.key, "")
        label = c.value(.label, "")
        tier = c.maybe(.tier)
        name = c.maybe(.name)
        url = c.maybe(.url)
        score = c.maybe(.score)
    }

    /// Etiket boşsa anahtarı göster.
    var title: String { label.isEmpty ? key : label }

    var link: URL? { url.flatMap(URL.init(string:)) }
}

/// Küratörlü bir aşama tahtası: kendi etiketi ve eşyalı/yıldızlı birimleri.
struct CompStage: Decodable, Hashable {
    var label: String
    var units: [CompUnit]

    private enum CodingKeys: String, CodingKey { case label, units }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = c.value(.label, "")
        units = c.value(.units, [])
    }
}

struct CompStages: Decodable, Hashable {
    var early: CompStage?
    var mid: CompStage?
    var late: CompStage?

    private enum CodingKeys: String, CodingKey { case early, mid, late }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        early = c.maybe(.early)
        mid = c.maybe(.mid)
        late = c.maybe(.late)
    }
}

/// Bir birimin alternatif eşya kurgusu.
struct AltBuild: Decodable, Hashable {
    var unit: String
    var items: [String]

    private enum CodingKeys: String, CodingKey { case unit, items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unit = c.value(.unit, "")
        items = c.value(.items, [])
    }
}

/// Kaynağın kendi ipucu. Türkçesi yoksa İngilizce metin gösterilir.
struct SourceTip: Decodable, Hashable {
    var source: String
    var stage: String
    var en: String
    var tr: String?

    private enum CodingKeys: String, CodingKey { case source, stage, en, tr }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = c.value(.source, "")
        stage = c.value(.stage, "")
        en = c.value(.en, "")
        tr = c.maybe(.tr)
    }

    /// Gösterilecek metin ve İngilizce'ye düşülüp düşülmediği.
    var text: (value: String, isEnglish: Bool) {
        if let tr, !tr.isEmpty { return (tr, false) }
        return (en, true)
    }

    /// "Stage 2" → "2. aşama"; tanınmayan etiket olduğu gibi kalır.
    var stageTitle: String {
        guard stage.hasPrefix("Stage "),
              let number = Int(stage.dropFirst(6).trimmingCharacters(in: .whitespaces))
        else { return stage }
        return "\(number). aşama"
    }
}

/// `comps.json` üst seviyesindeki kaynak durumu (Ayarlar → Hakkında).
struct SourceStatus: Decodable, Hashable {
    var key: String
    var label: String
    var url: String?
    var fetchedAt: String?
    var ok: Bool
    var count: Int

    private enum CodingKeys: String, CodingKey { case key, label, url, fetchedAt, ok, count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.value(.key, "")
        label = c.value(.label, "")
        ok = c.value(.ok, true)
        count = c.value(.count, 0)
        url = c.maybe(.url)
        fetchedAt = c.maybe(.fetchedAt)
    }

    var title: String { label.isEmpty ? key : label }

    var fetchedDate: Date? { fetchedAt.flatMap(ISO8601.date) }
}

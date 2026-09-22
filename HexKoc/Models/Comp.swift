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

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, source, set, patch, clusterId, comps
    }

    init() {
        schemaVersion = DataSchema.version
        generatedAt = ""
        source = "MetaTFT"
        set = "TFTSet18"
        patch = ""
        clusterId = nil
        comps = []
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

    private enum CodingKeys: String, CodingKey {
        case id, name, tier, playstyle, difficulty, stats, trend, units, traits, teamCode
        case levelBoards, earlyBoards, levelTiming, augments, counters, goodAgainst
        case starPriority, coreUnits, tips
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

    private enum CodingKeys: String, CodingKey { case avgPlacement, playRate, games }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avgPlacement = c.value(.avgPlacement, 0)
        playRate = c.value(.playRate, 0)
        games = c.value(.games, 0)
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

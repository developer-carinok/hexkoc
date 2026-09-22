import Foundation

struct Rules: Decodable, Hashable {
    var shopOdds: [String: [Int]]
    var xpToLevel: [String: Int]
    var poolSizes: [String: Int]
    var economy: Economy
    var rounds: GameRounds
    var patch: String?
    var sources: [String]

    private enum CodingKeys: String, CodingKey {
        case shopOdds, xpToLevel, poolSizes, economy, rounds, patch, sources
    }

    init() {
        shopOdds = [:]
        xpToLevel = [:]
        poolSizes = [:]
        economy = Economy()
        rounds = GameRounds()
        patch = nil
        sources = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shopOdds = c.value(.shopOdds, [:])
        xpToLevel = c.value(.xpToLevel, [:])
        poolSizes = c.value(.poolSizes, [:])
        economy = c.value(.economy, Economy())
        rounds = c.value(.rounds, GameRounds())
        patch = c.maybe(.patch)
        sources = c.value(.sources, [])
    }

    /// 1..5 maliyet yüzdeleri; veri yoksa boş dizi.
    func odds(level: Int) -> [Int] { shopOdds[String(level)] ?? [] }

    /// Şans tablosunda satırı olan seviyeler, artan.
    var oddsLevels: [Int] {
        shopOdds.keys.compactMap(Int.init).sorted()
    }

    /// Bir önceki seviyeden bu seviyeye geçmek için gereken XP.
    func xp(toLevel level: Int) -> Int? { xpToLevel[String(level)] }

    /// Şemada anahtarı olan seviyeler, artan.
    var xpLevels: [Int] {
        xpToLevel.keys.compactMap(Int.init).sorted()
    }

    /// 1. seviyeden verilen seviyeye kadar toplam XP.
    func cumulativeXP(toLevel level: Int) -> Int {
        xpLevels.filter { $0 <= level }.reduce(0) { $0 + (xpToLevel[String($1)] ?? 0) }
    }

    func poolSize(cost: Int) -> Int? { poolSizes[String(cost)] }
}

struct Economy: Decodable, Hashable {
    var interestPer10Gold: Int?
    var maxInterest: Int?
    var baseIncome: Int?
    var pvpWinGold: Int?
    var streakGold: [String: Int]
    var xpPerRound: Int?
    var xpPurchaseCost: Int?
    var xpPurchaseAmount: Int?
    var rerollCost: Int?
    var stage1Income: [Int]?

    private enum CodingKeys: String, CodingKey {
        case interestPer10Gold, maxInterest, baseIncome, pvpWinGold, streakGold
        case xpPerRound, xpPurchaseCost, xpPurchaseAmount, rerollCost, stage1Income
    }

    init() {
        streakGold = [:]
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        interestPer10Gold = c.maybe(.interestPer10Gold)
        maxInterest = c.maybe(.maxInterest)
        baseIncome = c.maybe(.baseIncome)
        pvpWinGold = c.maybe(.pvpWinGold)
        streakGold = c.value(.streakGold, [:])
        xpPerRound = c.maybe(.xpPerRound)
        xpPurchaseCost = c.maybe(.xpPurchaseCost)
        xpPurchaseAmount = c.maybe(.xpPurchaseAmount)
        rerollCost = c.maybe(.rerollCost)
        stage1Income = c.maybe(.stage1Income)
    }

    /// Seri uzunluğu → bonus altın, artan sırada. Son giriş "ve üzeri".
    var streakTiers: [(length: Int, gold: Int)] {
        streakGold.compactMap { key, value in Int(key).map { ($0, value) } }
            .sorted { $0.0 < $1.0 }
            .map { (length: $0.0, gold: $0.1) }
    }
}

struct GameRounds: Decodable, Hashable {
    var stage1Rounds: Int?
    var stageRounds: Int?
    var augmentRounds: [String]
    var carouselRound: Int?
    var pveRound: Int?

    private enum CodingKeys: String, CodingKey {
        case stage1Rounds, stageRounds, augmentRounds, carouselRound, pveRound
    }

    init() {
        augmentRounds = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage1Rounds = c.maybe(.stage1Rounds)
        stageRounds = c.maybe(.stageRounds)
        augmentRounds = c.value(.augmentRounds, [])
        carouselRound = c.maybe(.carouselRound)
        pveRound = c.maybe(.pveRound)
    }
}

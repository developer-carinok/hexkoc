import Foundation

struct Champion: Decodable, Identifiable, Hashable {
    var id: String
    var aliases: [String]
    var name: LocalizedText
    var cost: Int
    var traits: [String]
    var role: String?
    var stats: ChampionStats
    var ability: ChampionAbility
    var icon: String?
    var iconURL: String?
    var splashURL: String?
    var teamCode: String
    var poolCount: Int
    var recommendedItems: [String]
    var avgPlacement: Double?
    var popularity: Double?

    private enum CodingKeys: String, CodingKey {
        case id, aliases, name, cost, traits, role, stats, ability
        case icon, iconURL, splashURL, teamCode, poolCount, recommendedItems
        case avgPlacement, popularity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        aliases = c.value(.aliases, [])
        name = c.value(.name, .empty)
        cost = c.value(.cost, 1)
        traits = c.value(.traits, [])
        role = c.maybe(.role)
        stats = c.value(.stats, ChampionStats())
        ability = c.value(.ability, ChampionAbility())
        icon = c.maybe(.icon)
        iconURL = c.maybe(.iconURL)
        splashURL = c.maybe(.splashURL)
        teamCode = c.value(.teamCode, "")
        poolCount = c.value(.poolCount, 0)
        recommendedItems = c.value(.recommendedItems, [])
        avgPlacement = c.maybe(.avgPlacement)
        popularity = c.maybe(.popularity)
    }

    init(id: String, name: LocalizedText, cost: Int, traits: [String] = [], teamCode: String = "000") {
        self.id = id
        self.aliases = []
        self.name = name
        self.cost = cost
        self.traits = traits
        self.role = nil
        self.stats = ChampionStats()
        self.ability = ChampionAbility()
        self.icon = nil
        self.iconURL = nil
        self.splashURL = nil
        self.teamCode = teamCode
        self.poolCount = 0
        self.recommendedItems = []
        self.avgPlacement = nil
        self.popularity = nil
    }
}

struct ChampionStats: Decodable, Hashable {
    var hp: Double = 0
    var armor: Double = 0
    var mr: Double = 0
    var ad: Double = 0
    var attackSpeed: Double = 0
    var range: Double = 0
    var startMana: Double = 0
    var maxMana: Double = 0

    private enum CodingKeys: String, CodingKey {
        case hp, armor, mr, ad, attackSpeed, range, startMana, maxMana
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hp = c.value(.hp, 0)
        armor = c.value(.armor, 0)
        mr = c.value(.mr, 0)
        ad = c.value(.ad, 0)
        attackSpeed = c.value(.attackSpeed, 0)
        range = c.value(.range, 0)
        startMana = c.value(.startMana, 0)
        maxMana = c.value(.maxMana, 0)
    }
}

struct ChampionAbility: Decodable, Hashable {
    var name: LocalizedText = .empty
    var desc: LocalizedText = .empty

    private enum CodingKeys: String, CodingKey { case name, desc }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.value(.name, .empty)
        desc = c.value(.desc, .empty)
    }
}

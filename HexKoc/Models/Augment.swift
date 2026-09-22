import Foundation

enum AugmentRarity: String, TolerantEnum, CaseIterable {
    case silver
    case gold
    case prismatic
    case unknown

    static let unknownCase = AugmentRarity.unknown

    var title: String {
        switch self {
        case .silver: "Gümüş"
        case .gold: "Altın"
        case .prismatic: "Prizmatik"
        case .unknown: "Bilinmiyor"
        }
    }
}

enum AugmentCategory: String, TolerantEnum {
    case combat
    case economy
    case trait
    case utility
    case unknown

    static let unknownCase = AugmentCategory.unknown

    var title: String {
        switch self {
        case .combat: "Savaş"
        case .economy: "Ekonomi"
        case .trait: "Özellik"
        case .utility: "Fayda"
        case .unknown: "Diğer"
        }
    }
}

enum MetaTier: String, TolerantEnum, CaseIterable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    static let unknownCase = MetaTier.c

    var rank: Int {
        switch self {
        case .s: 0
        case .a: 1
        case .b: 2
        case .c: 3
        case .d: 4
        }
    }
}

struct Augment: Decodable, Identifiable, Hashable {
    var id: String
    var name: LocalizedText
    var desc: LocalizedText
    var rarity: AugmentRarity
    var category: AugmentCategory
    var icon: String?
    var iconURL: String?
    var metaTier: MetaTier?
    var traitId: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, desc, rarity, category, icon, iconURL, metaTier, traitId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        name = c.value(.name, .empty)
        desc = c.value(.desc, .empty)
        rarity = c.value(.rarity, .unknown)
        category = c.value(.category, .unknown)
        icon = c.maybe(.icon)
        iconURL = c.maybe(.iconURL)
        metaTier = c.maybe(.metaTier)
        traitId = c.maybe(.traitId)
    }

    init(id: String, name: LocalizedText, rarity: AugmentRarity = .gold, category: AugmentCategory = .combat) {
        self.id = id
        self.name = name
        self.desc = .empty
        self.rarity = rarity
        self.category = category
        self.icon = nil
        self.iconURL = nil
        self.metaTier = nil
        self.traitId = nil
    }
}

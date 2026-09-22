import Foundation

struct GameData: Decodable {
    var schemaVersion: Int
    var generatedAt: String
    var set: SetInfo
    var champions: [Champion]
    var traits: [Trait]
    var items: [Item]
    var augments: [Augment]
    var rules: Rules

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, set, champions, traits, items, augments, rules
    }

    init() {
        schemaVersion = DataSchema.version
        generatedAt = ""
        set = SetInfo()
        champions = []
        traits = []
        items = []
        augments = []
        rules = Rules()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.value(.schemaVersion, DataSchema.version)
        generatedAt = c.value(.generatedAt, "")
        set = c.value(.set, SetInfo())
        champions = c.value(.champions, [])
        traits = c.value(.traits, [])
        items = c.value(.items, [])
        augments = c.value(.augments, [])
        rules = c.value(.rules, Rules())
    }

    var generatedDate: Date? { ISO8601.date(generatedAt) }
    var isEmpty: Bool { champions.isEmpty && items.isEmpty }
}

struct SetInfo: Decodable, Hashable {
    var key: String
    var number: Int
    var name: String
    var patch: String

    private enum CodingKeys: String, CodingKey { case key, number, name, patch }

    init(key: String = "TFTSet18", number: Int = 18, name: String = "Enchanted Wilds", patch: String = "") {
        self.key = key
        self.number = number
        self.name = name
        self.patch = patch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.value(.key, "TFTSet18")
        number = c.value(.number, 18)
        name = c.value(.name, "")
        patch = c.value(.patch, "")
    }
}

enum DataSchema {
    static let version = 1
}

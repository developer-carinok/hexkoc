import Foundation

enum ItemKind: String, TolerantEnum, CaseIterable {
    case component
    case craftable
    case emblem
    case artifact
    case radiant
    case unknown

    static let unknownCase = ItemKind.unknown

    var title: String {
        switch self {
        case .component: "Bileşenler"
        case .craftable: "Birleştirilmiş"
        case .emblem: "Amblemler"
        case .artifact: "Yapıtlar"
        case .radiant: "Işıltılı"
        case .unknown: "Diğer"
        }
    }

    /// "Tüm Eşyalar" bölüm sırası.
    static let displayOrder: [ItemKind] = [.component, .craftable, .emblem, .artifact, .radiant, .unknown]
}

struct Item: Decodable, Identifiable, Hashable {
    var id: String
    var name: LocalizedText
    var desc: LocalizedText
    var kind: ItemKind
    var recipe: [String]?
    var icon: String?
    var iconURL: String?
    var unique: Bool
    var stats: [String: Double]
    var traitId: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, desc, kind, recipe, icon, iconURL, unique, stats, traitId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        name = c.value(.name, .empty)
        desc = c.value(.desc, .empty)
        kind = c.value(.kind, .unknown)
        recipe = c.maybe(.recipe)
        icon = c.maybe(.icon)
        iconURL = c.maybe(.iconURL)
        unique = c.value(.unique, false)
        stats = c.value(.stats, [:])
        traitId = c.maybe(.traitId)
    }

    init(id: String, name: LocalizedText, kind: ItemKind = .craftable, recipe: [String]? = nil) {
        self.id = id
        self.name = name
        self.desc = .empty
        self.kind = kind
        self.recipe = recipe
        self.icon = nil
        self.iconURL = nil
        self.unique = false
        self.stats = [:]
        self.traitId = nil
    }

    /// Tarif iki bileşenden oluşur; sırası önemsiz.
    var recipePair: Set<String>? {
        guard let recipe, recipe.count == 2 else { return nil }
        return Set(recipe)
    }
}

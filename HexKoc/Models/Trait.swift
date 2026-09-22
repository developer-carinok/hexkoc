import Foundation

enum TraitKind: String, TolerantEnum {
    case origin
    case `class`
    case unique

    static let unknownCase = TraitKind.origin

    var title: String {
        switch self {
        case .origin: "Köken"
        case .class: "Sınıf"
        case .unique: "Özel"
        }
    }

    /// Şemadaki sıralama: type sonra name.
    var sortOrder: Int {
        switch self {
        case .origin: 0
        case .class: 1
        case .unique: 2
        }
    }
}

enum TraitStyle: String, TolerantEnum {
    case none
    case bronze
    case silver
    case gold
    case prismatic
    case unique

    static let unknownCase = TraitStyle.bronze
}

struct Trait: Decodable, Identifiable, Hashable {
    var id: String
    var name: LocalizedText
    var type: TraitKind
    var desc: LocalizedText
    var breakpoints: [TraitBreakpoint]
    var icon: String?
    var iconURL: String?
    var champions: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, type, desc, breakpoints, icon, iconURL, champions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        name = c.value(.name, .empty)
        type = c.value(.type, .origin)
        desc = c.value(.desc, .empty)
        breakpoints = c.value(.breakpoints, [])
        icon = c.maybe(.icon)
        iconURL = c.maybe(.iconURL)
        champions = c.value(.champions, [])
    }

    init(id: String, name: LocalizedText, type: TraitKind = .origin, breakpoints: [TraitBreakpoint] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.desc = .empty
        self.breakpoints = breakpoints
        self.icon = nil
        self.iconURL = nil
        self.champions = []
    }

    /// Verilen birim sayısının ulaştığı en yüksek eşik.
    func breakpoint(for count: Int) -> TraitBreakpoint? {
        breakpoints.last { count >= $0.min }
    }

    func style(for count: Int) -> TraitStyle {
        breakpoint(for: count)?.style ?? .none
    }
}

struct TraitBreakpoint: Decodable, Hashable, Identifiable {
    var min: Int
    var max: Int?
    var style: TraitStyle
    var desc: LocalizedText

    var id: Int { min }

    private enum CodingKeys: String, CodingKey { case min, max, style, desc }

    init(min: Int, style: TraitStyle, desc: LocalizedText = .empty) {
        self.min = min
        self.max = nil
        self.style = style
        self.desc = desc
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        min = c.value(.min, 0)
        max = c.maybe(.max)
        style = c.value(.style, .bronze)
        desc = c.value(.desc, .empty)
    }
}

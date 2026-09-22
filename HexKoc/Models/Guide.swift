import Foundation

enum GuideCategory: String, TolerantEnum, CaseIterable {
    case baslangic
    case ekonomi
    case strateji
    case set18
    case sozluk
    case diger

    static let unknownCase = GuideCategory.diger

    var title: String {
        switch self {
        case .baslangic: "Başlangıç"
        case .ekonomi: "Ekonomi"
        case .strateji: "Strateji"
        case .set18: "Set 18"
        case .sozluk: "Sözlük"
        case .diger: "Diğer"
        }
    }

    var sortOrder: Int {
        switch self {
        case .baslangic: 0
        case .ekonomi: 1
        case .strateji: 2
        case .set18: 3
        case .sozluk: 4
        case .diger: 5
        }
    }
}

struct GuidesFile: Decodable {
    var schemaVersion: Int
    var generatedAt: String
    var articles: [GuideArticle]

    private enum CodingKeys: String, CodingKey { case schemaVersion, generatedAt, articles }

    init() {
        schemaVersion = DataSchema.version
        generatedAt = ""
        articles = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.value(.schemaVersion, DataSchema.version)
        generatedAt = c.value(.generatedAt, "")
        articles = c.value(.articles, [])
    }
}

struct GuideArticle: Decodable, Identifiable, Hashable {
    var id: String
    var category: GuideCategory
    var title: String
    var summary: String
    var icon: String
    var minutes: Int
    var body: String

    private enum CodingKeys: String, CodingKey {
        case id, category, title, summary, icon, minutes, body
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, "")
        category = c.value(.category, .diger)
        title = c.value(.title, "")
        summary = c.value(.summary, "")
        icon = c.value(.icon, "book.fill")
        minutes = c.value(.minutes, 0)
        body = c.value(.body, "")
    }

    init(id: String, category: GuideCategory, title: String, summary: String, icon: String = "book.fill", minutes: Int = 3, body: String = "") {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.icon = icon
        self.minutes = minutes
        self.body = body
    }
}

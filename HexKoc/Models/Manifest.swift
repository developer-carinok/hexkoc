import Foundation

struct Manifest: Decodable {
    var schemaVersion: Int
    var generatedAt: String
    var patch: String
    var files: [String: String]

    private enum CodingKeys: String, CodingKey { case schemaVersion, generatedAt, patch, files }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.value(.schemaVersion, 0)
        generatedAt = c.value(.generatedAt, "")
        patch = c.value(.patch, "")
        files = c.value(.files, [:])
    }

    var generatedDate: Date? { ISO8601.date(generatedAt) }

    func fileName(_ key: DataFileKind) -> String {
        files[key.rawValue] ?? key.defaultFileName
    }
}

enum DataFileKind: String, CaseIterable {
    case gamedata
    case comps
    case guides

    var defaultFileName: String { rawValue + ".json" }
}

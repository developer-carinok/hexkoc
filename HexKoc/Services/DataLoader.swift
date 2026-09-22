import Foundation

/// Üç JSON dosyasının bir arada hâli.
struct DataBundle {
    var gameData: GameData
    var comps: CompsFile
    var guides: GuidesFile

    var generatedDate: Date? { gameData.generatedDate ?? comps.generatedDate }

    /// Boş veya bozuk bir set yayınlamayalım.
    var isUsable: Bool { !gameData.champions.isEmpty }

    static let empty = DataBundle(gameData: GameData(), comps: CompsFile(), guides: GuidesFile())
}

/// Paket ve disk önbelleğinden JSON okur.
enum DataLoader {
    static let cacheDirectoryName = "HexKoc/data"

    static var cacheDirectory: URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return support.appendingPathComponent(cacheDirectoryName, isDirectory: true)
    }

    /// `Resources/Data` klasörü pakete `Data/` olarak kopyalanır.
    static func bundleURL(for kind: DataFileKind) -> URL? {
        for directory in ["Data", "Resources/Data"] {
            if let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "json", subdirectory: directory) {
                return url
            }
        }
        guard let root = Bundle.main.resourceURL else { return nil }
        let direct = root.appendingPathComponent("Data/\(kind.defaultFileName)")
        return FileManager.default.fileExists(atPath: direct.path) ? direct : nil
    }

    static func loadBundled() -> DataBundle {
        DataBundle(
            gameData: decode(GameData.self, from: bundleURL(for: .gamedata)) ?? GameData(),
            comps: decode(CompsFile.self, from: bundleURL(for: .comps)) ?? CompsFile(),
            guides: decode(GuidesFile.self, from: bundleURL(for: .guides)) ?? GuidesFile()
        )
    }

    static func loadCached() -> DataBundle? {
        guard let directory = cacheDirectory else { return nil }
        guard let gameData = decode(GameData.self, from: directory.appendingPathComponent(DataFileKind.gamedata.defaultFileName)),
              !gameData.champions.isEmpty
        else { return nil }
        return DataBundle(
            gameData: gameData,
            comps: decode(CompsFile.self, from: directory.appendingPathComponent(DataFileKind.comps.defaultFileName)) ?? CompsFile(),
            guides: decode(GuidesFile.self, from: directory.appendingPathComponent(DataFileKind.guides.defaultFileName)) ?? GuidesFile()
        )
    }

    static func decode<T: Decodable>(_ type: T.Type, from url: URL?) -> T? {
        guard let url, let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

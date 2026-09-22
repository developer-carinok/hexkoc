import Foundation

/// GitHub'daki `data/v1/` klasöründen daha yeni veri çeker.
/// Başarısızlık sessizdir: paketteki veri her zaman çalışır.
enum RemoteDataService {
    static let baseURL = URL(string: "https://raw.githubusercontent.com/developer-carinok/hexkoc/main/data/v1/")!

    enum Outcome {
        case upToDate
        case updated(DataBundle)
        case failed(String)
    }

    static func refreshIfNeeded(currentGeneratedAt: Date?) async -> Outcome {
        do {
            let manifestData = try await download("manifest.json")
            let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
            guard manifest.schemaVersion == DataSchema.version else {
                return .failed("Sunucudaki veri sürümü bu uygulamayla uyumlu değil.")
            }
            guard let remoteDate = manifest.generatedDate else {
                return .failed("Sunucudaki verinin tarihi okunamadı.")
            }
            if let currentGeneratedAt, remoteDate <= currentGeneratedAt {
                return .upToDate
            }

            // Önce hepsini indir, sonra hepsini çöz: biri bozuksa hiçbirine geçmeyiz.
            var payload: [DataFileKind: Data] = [:]
            for kind in DataFileKind.allCases {
                payload[kind] = try await download(manifest.fileName(kind))
            }
            let decoder = JSONDecoder()
            let bundle = DataBundle(
                gameData: try decoder.decode(GameData.self, from: payload[.gamedata] ?? Data()),
                comps: try decoder.decode(CompsFile.self, from: payload[.comps] ?? Data()),
                guides: try decoder.decode(GuidesFile.self, from: payload[.guides] ?? Data())
            )
            guard bundle.isUsable else {
                return .failed("Sunucudan gelen veri eksik görünüyor.")
            }

            try store(payload)
            return .updated(bundle)
        } catch is CancellationError {
            return .upToDate
        } catch {
            return .failed(message(for: error))
        }
    }

    // MARK: - Ağ

    private static func download(_ name: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(name))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RefreshError.badStatus(http.statusCode, name)
        }
        return data
    }

    // MARK: - Disk

    /// Önce geçici bir klasöre yazar, sonra önbellek klasörünü tek hamlede değiştirir.
    private static func store(_ payload: [DataFileKind: Data]) throws {
        guard let destination = DataLoader.cacheDirectory else { throw RefreshError.noCacheDirectory }
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("hexkoc-data-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        for (kind, data) in payload {
            try data.write(to: staging.appendingPathComponent(kind.defaultFileName), options: .atomic)
        }

        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: staging, to: destination)
    }

    private static func message(for error: Error) -> String {
        if let refresh = error as? RefreshError { return refresh.message }
        if error is DecodingError { return "Gelen veri okunamadı." }
        return "Güncelleme başarısız: bağlantıyı kontrol et."
    }

    private enum RefreshError: Error {
        case badStatus(Int, String)
        case noCacheDirectory

        var message: String {
            switch self {
            case .badStatus(let code, let name): "Sunucu \(name) için \(code) döndü."
            case .noCacheDirectory: "Veri klasörü açılamadı."
            }
        }
    }
}

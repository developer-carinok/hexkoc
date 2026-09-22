import SwiftUI
import UIKit

/// Paket içindeki PNG'leri ana iş parçacığını tıkamadan yükler ve önbelleğe alır.
final class ImageProvider {
    static let shared = ImageProvider()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 600
        return cache
    }()

    /// Pakette bulunamayan yollar — her seferinde diske gitmemek için.
    private let missing = MissingSet()

    private init() {}

    func cachedImage(path: String) -> UIImage? {
        cache.object(forKey: path as NSString)
    }

    func isMissing(path: String) -> Bool {
        missing.contains(path)
    }

    /// Paketteki görseli çözer. Ana aktörde değil — çözme işi arka planda olur.
    func image(path: String) async -> UIImage? {
        if let cached = cachedImage(path: path) { return cached }
        if missing.contains(path) { return nil }
        guard let url = Self.bundleURL(for: path),
              let decoded = UIImage(contentsOfFile: url.path)
        else {
            missing.insert(path)
            return nil
        }
        let image = Self.forceDecoded(decoded)
        cache.setObject(image, forKey: path as NSString)
        return image
    }

    /// Bitmap'i şimdi üret ki çizim anında ana iş parçacığı PNG çözmesin.
    /// (`preparingForDisplay()` bu PNG'lerde ImageIO hata kaydı bırakıyor, onu kullanmıyoruz.)
    private static func forceDecoded(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in image.draw(at: .zero) }
    }

    /// `Resources/Images` klasör referansı pakete `Images/` olarak kopyalanır:
    /// Images/champions/DA_18_Ahri.png
    static func bundleURL(for path: String) -> URL? {
        let ns = path as NSString
        let file = ns.lastPathComponent as NSString
        let name = file.deletingPathExtension
        let ext = file.pathExtension.isEmpty ? "png" : file.pathExtension

        for root in ["Images/", "Resources/Images/"] {
            let directory = root + ns.deletingLastPathComponent
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory) {
                return url
            }
        }
        // Yedek: doğrudan paket köküne göre çöz.
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let direct = resourceURL.appendingPathComponent("Images/").appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: direct.path) ? direct : nil
    }
}

/// NSCache gibi iş parçacığı güvenli küçük bir küme.
private final class MissingSet {
    private var storage = Set<String>()
    private let lock = NSLock()

    func contains(_ value: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.contains(value)
    }

    func insert(_ value: String) {
        lock.lock()
        storage.insert(value)
        lock.unlock()
    }
}

import Foundation

/// Boru hattı şemadan saparsa uygulama çökmesin diye her alanı hoşgörülü okuyoruz:
/// eksik anahtar veya beklenmeyen tip = varsayılan değer.
extension KeyedDecodingContainerProtocol {
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    func maybe<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

/// Bilinmeyen enum değerleri hata fırlatmak yerine bilinen bir duruma düşer.
protocol TolerantEnum: RawRepresentable, Decodable, Hashable where RawValue == String {
    static var unknownCase: Self { get }
}

extension TolerantEnum {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self(rawValue: raw) ?? Self.unknownCase
    }
}

enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain = ISO8601DateFormatter()

    static func date(_ string: String) -> Date? {
        plain.date(from: string) ?? withFraction.date(from: string)
    }
}

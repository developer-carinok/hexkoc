import Foundation

/// Arayüzde gösterilecek isim dili. Varsayılan Türkçe.
enum NameLanguage: String, CaseIterable, Identifiable, Codable {
    case tr
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tr: "Türkçe"
        case .en: "İngilizce"
        }
    }

    var other: NameLanguage { self == .tr ? .en : .tr }
}

/// `{"en": "...", "tr": "..."}` çifti. Bir dil boşsa diğerine düşer.
struct LocalizedText: Decodable, Hashable {
    var en: String
    var tr: String

    private enum CodingKeys: String, CodingKey { case en, tr }

    init(en: String, tr: String) {
        self.en = en
        self.tr = tr
    }

    init(from decoder: Decoder) throws {
        // Boru hattı düz bir metin üretirse de kabul et.
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            self.init(en: single, tr: single)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(en: c.value(.en, ""), tr: c.value(.tr, ""))
    }

    func text(_ language: NameLanguage) -> String {
        switch language {
        case .tr: tr.isEmpty ? en : tr
        case .en: en.isEmpty ? tr : en
        }
    }

    /// Alt başlıkta gösterilecek diğer dil; aynıysa nil.
    func subtitle(_ language: NameLanguage) -> String? {
        let primary = text(language)
        let secondary = text(language.other)
        return secondary.isEmpty || secondary == primary ? nil : secondary
    }

    var isEmpty: Bool { en.isEmpty && tr.isEmpty }

    static let empty = LocalizedText(en: "", tr: "")
}

import Foundation
import Observation

/// Kullanıcı tercihleri. UserDefaults'ta saklanır, uygulama genelinde paylaşılır.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let nameLanguage = "nameLanguage"
        static let showEnglishSubtitle = "showEnglishSubtitle"
    }

    private let defaults: UserDefaults

    var nameLanguage: NameLanguage {
        didSet { defaults.set(nameLanguage.rawValue, forKey: Key.nameLanguage) }
    }

    /// Alt başlıkta diğer dildeki ismi göster.
    var showEnglishSubtitle: Bool {
        didSet { defaults.set(showEnglishSubtitle, forKey: Key.showEnglishSubtitle) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Key.nameLanguage) ?? NameLanguage.tr.rawValue
        self.nameLanguage = NameLanguage(rawValue: raw) ?? .tr
        self.showEnglishSubtitle = defaults.object(forKey: Key.showEnglishSubtitle) as? Bool ?? true
    }

    /// Bir ismin alt başlığı — ayar kapalıysa nil.
    func subtitle(for text: LocalizedText) -> String? {
        showEnglishSubtitle ? text.subtitle(nameLanguage) : nil
    }
}

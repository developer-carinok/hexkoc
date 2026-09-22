import Foundation

enum Format {
    /// "4.34"
    static func placement(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// 0.0246 → "%2,5"
    static func percent(_ value: Double, fractionDigits: Int = 1) -> String {
        "%" + String(format: "%.\(fractionDigits)f", value * 100).replacingOccurrences(of: ".", with: ",")
    }

    /// 21152 → "21.152"
    static func count(_ value: Int) -> String {
        countFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// 0.8 → "0,8"
    static func decimal(_ value: Double, fractionDigits: Int = 1) -> String {
        if value == value.rounded() && fractionDigits <= 1 {
            return String(Int(value))
        }
        return String(format: "%.\(fractionDigits)f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// "22 Eyl 2026 19:00"
    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dateTimeFormatter.string(from: date)
    }

    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM yyyy HH:mm"
        return f
    }()
}

/// Eşya istatistik anahtarlarının Türkçe karşılıkları.
/// Veri hem "AP" hem "AbilityPower" gibi eş anlamlılar üretiyor; ikisi de aynı etikete düşer.
/// Yüzde olan değerler Türkçe istemcideki gibi "%15" biçiminde yazılır.
enum StatLabel {
    private struct Entry {
        let title: String
        let isPercent: Bool
    }

    private static let map: [String: Entry] = [
        "AbilityPower": Entry(title: "YG", isPercent: false),
        "AP": Entry(title: "YG", isPercent: false),
        "AbilityPowerMultiplier": Entry(title: "YG Çarpanı", isPercent: true),
        "AttackDamage": Entry(title: "SG", isPercent: false),
        "AD": Entry(title: "SG", isPercent: false),
        "AD%": Entry(title: "SG", isPercent: true),
        "ADAP": Entry(title: "SG/YG", isPercent: false),
        "AttackSpeed": Entry(title: "SH", isPercent: true),
        "AS": Entry(title: "SH", isPercent: true),
        "Armor": Entry(title: "Zırh", isPercent: false),
        "MagicResist": Entry(title: "BD", isPercent: false),
        "MR": Entry(title: "BD", isPercent: false),
        "ArmorMR": Entry(title: "Zırh/BD", isPercent: false),
        "Health": Entry(title: "Can", isPercent: false),
        "HP": Entry(title: "Can", isPercent: false),
        "HealthMax": Entry(title: "Maks. Can", isPercent: false),
        "MaxHealth": Entry(title: "Maks. Can", isPercent: false),
        "Mana": Entry(title: "Mana", isPercent: false),
        "ManaPerSecond": Entry(title: "Mana/sn", isPercent: false),
        "ManaRegen": Entry(title: "Mana Yenileme", isPercent: false),
        "AbilityHaste": Entry(title: "Mana Yenileme", isPercent: false),
        "CritChance": Entry(title: "Krit", isPercent: true),
        "CriticalStrikeChance": Entry(title: "Krit", isPercent: true),
        "CritDamage": Entry(title: "Krit Hasarı", isPercent: true),
        "Omnivamp": Entry(title: "Omnivamp", isPercent: true),
        "Durability": Entry(title: "Dayanıklılık", isPercent: true),
        "DamageAmp": Entry(title: "Hasar Artışı", isPercent: true),
        "OutgoingDamageMultiplier": Entry(title: "Hasar Artışı", isPercent: true),
        "HealShieldBoost": Entry(title: "İyileşme/Kalkan", isPercent: true),
        "IncomingDmgMod": Entry(title: "Alınan Hasar", isPercent: true)
    ]

    static func title(_ key: String) -> String {
        map[key]?.title ?? splitOnCapitals(key)
    }

    /// "%15" veya "20"
    static func value(_ key: String, _ value: Double) -> String {
        let number = Format.decimal(value)
        return map[key]?.isPercent == true ? "%" + number : number
    }

    /// "SH %15"
    static func text(_ key: String, _ value: Double) -> String {
        title(key) + " " + self.value(key, value)
    }

    /// Bilinmeyen anahtar: "HealShieldBoost" → "Heal Shield Boost"
    private static func splitOnCapitals(_ key: String) -> String {
        var result = ""
        for (index, character) in key.enumerated() {
            if index > 0, character.isUppercase, !result.hasSuffix(" ") {
                result.append(" ")
            }
            result.append(character)
        }
        return result
    }
}

import SwiftUI

/// Oyunun kendi diline yakın, koyu ve yüksek kontrastlı bir palet.
/// Maç sırasında tek elle kullanılıyor: büyük dokunma hedefleri, kalın rakamlar.
enum Theme {
    // MARK: - Yüzeyler
    static let background = Color(hex: 0x0A0F1E)
    static let surface = Color(hex: 0x141B2E)
    static let elevated = Color(hex: 0x1C2540)
    static let hairline = Color(hex: 0x2A3550)

    // MARK: - Metin
    static let text = Color(hex: 0xF1F5F9)
    static let secondaryText = Color(hex: 0x94A3B8)
    static let accent = Color(hex: 0xC9A55A)

    // MARK: - Ölçüler
    static let cardRadius: CGFloat = 14
    static let cardPadding: CGFloat = 14
    static let rowMinHeight: CGFloat = 56

    /// Şampiyon maliyet renkleri (1-5).
    static func cost(_ cost: Int) -> Color {
        switch cost {
        case 1: Color(hex: 0x8C97A5)
        case 2: Color(hex: 0x2FBF71)
        case 3: Color(hex: 0x3B82F6)
        case 4: Color(hex: 0xA855F7)
        case 5: Color(hex: 0xF59E0B)
        default: Color(hex: 0x8C97A5)
        }
    }

    static func tier(_ tier: CompTier) -> Color {
        switch tier {
        case .s: Color(hex: 0xFF5C5C)
        case .a: Color(hex: 0xFFB020)
        case .b: Color(hex: 0x3FA9F5)
        case .c: Color(hex: 0x8A94A6)
        }
    }

    static func metaTier(_ tier: MetaTier) -> Color {
        switch tier {
        case .s: Color(hex: 0xFF5C5C)
        case .a: Color(hex: 0xFFB020)
        case .b: Color(hex: 0x3FA9F5)
        case .c: Color(hex: 0x8A94A6)
        case .d: Color(hex: 0x6B7280)
        }
    }

    static func traitStyle(_ style: TraitStyle) -> Color {
        switch style {
        case .bronze: Color(hex: 0xA0664B)
        case .silver: Color(hex: 0xB8C4D0)
        case .gold: Color(hex: 0xE8B84A)
        case .prismatic: Color(hex: 0x9FE0FF)
        case .unique: Color(hex: 0xE6D3A0)
        case .none: secondaryText
        }
    }

    static func rarity(_ rarity: AugmentRarity) -> Color {
        switch rarity {
        case .silver: Color(hex: 0xB8C4D0)
        case .gold: Color(hex: 0xE8B84A)
        case .prismatic: Color(hex: 0x9FE0FF)
        case .unknown: secondaryText
        }
    }

    static func trend(_ trend: Trend) -> Color {
        switch trend {
        case .rising: Color(hex: 0x2FBF71)
        case .falling: Color(hex: 0xFF5C5C)
        case .stable: secondaryText
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

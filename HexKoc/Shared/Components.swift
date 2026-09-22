import SwiftUI

/// Uygulamanın kart yüzeyi.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

struct CostBadge: View {
    let cost: Int

    var body: some View {
        Text("\(cost)")
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(Theme.cost(cost))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.cost(cost).opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.cost(cost).opacity(0.5), lineWidth: 1))
            .accessibilityLabel("\(cost) altın")
    }
}

struct TierBadge: View {
    let tier: CompTier
    var size: CGFloat = 30

    var body: some View {
        Text(tier.rawValue)
            .font(.system(size: size * 0.52, weight: .heavy))
            .foregroundStyle(Theme.background)
            .frame(width: size, height: size)
            .background(Theme.tier(tier), in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityLabel("\(tier.rawValue) seviye komp")
    }
}

struct MetaTierBadge: View {
    let tier: MetaTier

    var body: some View {
        Text(tier.rawValue)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Theme.background)
            .frame(width: 20, height: 20)
            .background(Theme.metaTier(tier), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct Chip: View {
    let text: String
    var systemImage: String?
    var color: Color = Theme.secondaryText
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(filled ? Theme.background : color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(filled ? color : color.opacity(0.15), in: Capsule())
    }
}

/// 3 yıldız hedefi göstergesi.
struct StarMarker: View {
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(Theme.accent)
            }
        }
        .accessibilityLabel("3 yıldız hedefi")
    }
}

/// Liste/ızgara başlıklarında kullanılan ince ayırıcı.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

/// Veri henüz yokken veya arama sonucu boşken.
struct EmptyStateView: View {
    let title: String
    var message: String
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Theme.secondaryText)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }
}

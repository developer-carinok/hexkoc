import SwiftUI

/// Kompu listeleyen kaynaklar: etiket + o kaynağın kendi kademesi.
/// Dokunulunca kaynağın kendi sayfası açılır. Etiketler veriden gelir.
struct CompSourcesRow: View {
    let comp: Comp
    /// Yatay oyun modunda dikeyde yer yok; rozetler alçalır.
    var compact: Bool = false

    @Environment(\.openURL) private var openURL

    /// Oyun modunda satırın sabit yüksekliği.
    static let compactHeight: CGFloat = 20

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                    badge(source)
                }
            }
            .padding(.vertical, compact ? 0 : 2)
        }
        .frame(height: compact ? Self.compactHeight : nil)
    }

    @ViewBuilder
    private func badge(_ source: CompSource) -> some View {
        if let url = source.link {
            Button {
                Haptics.tap()
                openURL(url)
            } label: {
                label(source)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(source))
            .accessibilityHint("Kaynağı tarayıcıda açar")
        } else {
            label(source)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(source))
        }
    }

    private func label(_ source: CompSource) -> some View {
        HStack(spacing: 4) {
            Text(source.title)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(Theme.text)
            if let value = comp.sourceValue(for: source) {
                Text(value)
                    .font((compact ? Font.caption2 : Font.caption).weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            if source.link != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: compact ? 7 : 8, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(Theme.elevated, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func accessibilityLabel(_ source: CompSource) -> String {
        [source.title, comp.sourceValue(for: source)].compactMap { $0 }.joined(separator: " ")
    }

    private var sources: [CompSource] { comp.sources ?? [] }
}

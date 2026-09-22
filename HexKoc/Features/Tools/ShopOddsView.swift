import SwiftUI

struct ShopOddsView: View {
    @Environment(DataStore.self) private var store
    @State private var level = 8

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper(value: $level, in: levelRange) {
                            HStack {
                                Text("Seviye")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                Spacer()
                                Text("\(level)")
                                    .font(.title3.bold().monospacedDigit())
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .tint(Theme.accent)

                        Text("Mağazada her slot için maliyete göre çıkma yüzdesi.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Card { ShopOddsTable(rules: store.rules, highlight: level) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Theme.background)
        .navigationTitle("Şans Tablosu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var levelRange: ClosedRange<Int> {
        let levels = store.rules.oddsLevels
        guard let first = levels.first, let last = levels.last, first < last else { return 1...10 }
        return first...last
    }
}

struct ShopOddsTable: View {
    let rules: Rules
    var highlight: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Mağaza Şansları", subtitle: "%")

            VStack(spacing: 0) {
                headerRow
                ForEach(rules.oddsLevels, id: \.self) { level in
                    row(level: level)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Sv")
                .frame(width: 32, alignment: .leading)
            ForEach(1...5, id: \.self) { cost in
                Text("\(cost)")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Theme.cost(cost))
            }
        }
        .font(.caption.bold().monospacedDigit())
        .foregroundStyle(Theme.secondaryText)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func row(level: Int) -> some View {
        let odds = rules.odds(level: level)
        let isHighlighted = highlight == level
        return HStack(spacing: 0) {
            Text("\(level)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(isHighlighted ? Theme.accent : Theme.text)
                .frame(width: 32, alignment: .leading)
            ForEach(0..<5, id: \.self) { index in
                Text(index < odds.count ? "\(odds[index])" : "—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(index < odds.count && odds[index] == 0 ? Theme.secondaryText.opacity(0.4) : Theme.text)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 7)
        .background(isHighlighted ? Theme.accent.opacity(0.14) : Color.clear)
        .overlay(alignment: .bottom) { Hairline().opacity(0.4) }
    }
}

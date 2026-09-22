import SwiftUI

/// Kaynakların kendi ipuçları, aşamaya göre gruplanmış. Türkçesi yoksa
/// İngilizce metin küçük bir "EN" etiketiyle gösterilir.
struct SourceTipsView: View {
    let comp: Comp
    /// Oyun modunda daha küçük yazı ve aralık.
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                    Text(group.title)
                        .font(.caption.bold())
                        .foregroundStyle(Theme.secondaryText)
                    ForEach(Array(group.tips.enumerated()), id: \.offset) { _, tip in
                        row(tip)
                    }
                }
            }
        }
    }

    private func row(_ tip: SourceTip) -> some View {
        let content = tip.text
        return HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .padding(.top, compact ? 6 : 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(content.value)
                    .font(compact ? .footnote : .subheadline)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    if content.isEnglish {
                        Text("EN")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.secondaryText, in: RoundedRectangle(cornerRadius: 3))
                    }
                    Text(comp.sourceLabel(tip.source))
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Aşama sırası veride geldiği gibi korunur.
    private var groups: [(title: String, tips: [SourceTip])] {
        var order: [String] = []
        var byStage: [String: [SourceTip]] = [:]
        for tip in comp.sourceTips ?? [] where !tip.text.value.isEmpty {
            if byStage[tip.stage] == nil { order.append(tip.stage) }
            byStage[tip.stage, default: []].append(tip)
        }
        return order.compactMap { stage in
            guard let tips = byStage[stage], let first = tips.first else { return nil }
            return (title: first.stageTitle, tips: tips)
        }
    }
}

struct CompSourceTipsCard: View {
    let comp: Comp

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Kaynak İpuçları")
                SourceTipsView(comp: comp)
            }
        }
    }
}

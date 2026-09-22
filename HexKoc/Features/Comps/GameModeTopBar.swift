import SwiftUI
import UIKit

/// Oyun modunun tek satırlık üst çubuğu: geri, komp kimliği ve kod kopyalama.
struct GameModeTopBar: View {
    let comp: Comp
    @Binding var toast: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")

            TierBadge(tier: comp.tier, size: 28)

            Text(comp.name.text(settings.nameLanguage))
                .font(.headline)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Chip(text: comp.playstyle.title, color: Theme.accent)

            Text("Ort. \(Format.placement(comp.stats.avgPlacement))")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .accessibilityLabel("Ortalama sıralama \(Format.placement(comp.stats.avgPlacement))")

            Spacer(minLength: 8)

            Button {
                copyCode()
            } label: {
                Label("Kodu Kopyala", systemImage: "doc.on.doc.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(comp.teamCode.isEmpty)
            .opacity(comp.teamCode.isEmpty ? 0.4 : 1)
        }
        .frame(height: 44)
    }

    private func copyCode() {
        UIPasteboard.general.string = comp.teamCode
        Haptics.success()
        toast = "Kod kopyalandı"
    }
}

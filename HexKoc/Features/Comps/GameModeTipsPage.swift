import SwiftUI

/// İpuçları: kompun cümleleri ve kompu yenen rakip komplar.
struct GameModeTipsPage: View {
    let comp: Comp
    let pageSize: CGSize

    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    /// Tek sütunda bir ipucunun kabaca kapladığı yükseklik.
    private static let tipHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tips.isEmpty {
                Text("Bu komp için ipucu yok.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    column(Array(tips.prefix(splitIndex)))
                    if splitIndex < tips.count {
                        column(Array(tips.dropFirst(splitIndex)))
                    }
                }
            }

            if !counters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bunlara dikkat")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.secondaryText)
                    FlowRow(spacing: 6) {
                        ForEach(counters) { other in
                            NavigationLink(value: Route.comp(other.id)) {
                                Chip(
                                    text: other.name.text(settings.nameLanguage),
                                    systemImage: "exclamationmark.triangle.fill",
                                    color: Theme.tier(.s)
                                )
                                .frame(minHeight: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func column(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(tip)
                        .font(.footnote)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tips: [String] { comp.tips(settings.nameLanguage) }

    private var counters: [Comp] {
        comp.counters.compactMap { store.comp($0.compId) }
    }

    /// Tek sütuna sığmıyorsa ikiye böl.
    private var splitIndex: Int {
        let available = pageSize.height - (counters.isEmpty ? 0 : 70)
        guard CGFloat(tips.count) * Self.tipHeight > available else { return tips.count }
        return (tips.count + 1) / 2
    }
}

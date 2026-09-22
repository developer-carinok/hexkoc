import SwiftUI

struct CompTraitsCard: View {
    let comp: Comp
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Aktif Özellikler")

                FlowRow(spacing: 6) {
                    ForEach(comp.traits) { entry in
                        NavigationLink(value: Route.trait(entry.id)) {
                            traitChip(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func traitChip(_ entry: CompTrait) -> some View {
        let trait = store.trait(entry.id)
        let color = Theme.traitStyle(entry.style)
        return HStack(spacing: 5) {
            TraitIcon(trait: trait, size: 16, style: entry.style)
            Text(trait?.name.text(settings.nameLanguage) ?? entry.id)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("\(entry.count)")
                .font(.caption.bold().monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
    }
}

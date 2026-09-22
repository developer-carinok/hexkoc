import SwiftUI

struct CompTraitsCard: View {
    let comp: Comp

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Aktif Özellikler")

                FlowRow(spacing: 6) {
                    ForEach(comp.traits) { entry in
                        NavigationLink(value: Route.trait(entry.id)) {
                            TraitCountChip(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

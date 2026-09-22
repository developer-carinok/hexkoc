import SwiftUI

struct ItemsTabView: View {
    @Binding var path: [Route]

    @State private var segment: Segment = .combiner
    @State private var search = ""

    enum Segment: String, CaseIterable, Identifiable {
        case combiner
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .combiner: "Birleştirici"
            case .all: "Tüm Eşyalar"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Görünüm", selection: $segment) {
                    ForEach(Segment.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                switch segment {
                case .combiner: ItemCombinerView()
                case .all: ItemListView(search: search)
                }
            }
            .background(Theme.background)
            .navigationTitle("Eşyalar")
            .searchable(text: $search, prompt: "Eşya ara")
            .hexKocDestinations()
        }
    }
}

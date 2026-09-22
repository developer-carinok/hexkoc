import SwiftUI

struct ChampionsTabView: View {
    @State private var segment: Segment = .champions
    @State private var search = ""

    enum Segment: String, CaseIterable, Identifiable {
        case champions
        case traits

        var id: String { rawValue }

        var title: String {
            switch self {
            case .champions: "Şampiyonlar"
            case .traits: "Özellikler"
            }
        }
    }

    var body: some View {
        NavigationStack {
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
                case .champions: ChampionsGridView(search: search)
                case .traits: TraitsListView(search: search)
                }
            }
            .background(Theme.background)
            .navigationTitle(segment.title)
            .searchable(text: $search, prompt: "Şampiyon veya özellik ara")
            .hexKocDestinations()
        }
    }
}

import SwiftUI

struct RootView: View {
    @SceneStorage("navigation") private var storedNavigation = ""
    @SceneStorage("navigationSavedAt") private var storedNavigationAt: Double = 0

    @State private var tab: RootTab = .comps
    @State private var compsPath: [Route] = []
    @State private var championsPath: [Route] = []
    @State private var itemsPath: [Route] = []
    @State private var augmentsPath: [Route] = []
    @State private var guidePath: [Route] = []
    @State private var restored = false

    /// Oyun uygulamayı bellekten atarsa bu süre içinde dönüldüğünde kaldığı yerden devam eder.
    private static let restoreWindow: TimeInterval = 12 * 60 * 60

    var body: some View {
        TabView(selection: $tab) {
            Tab("Komplar", systemImage: "list.bullet.rectangle.portrait", value: RootTab.comps) {
                CompListView(path: $compsPath)
            }
            Tab("Şampiyonlar", systemImage: "person.3.fill", value: RootTab.champions) {
                ChampionsTabView(path: $championsPath)
            }
            Tab("Eşyalar", systemImage: "shield.lefthalf.filled", value: RootTab.items) {
                ItemsTabView(path: $itemsPath)
            }
            Tab("Güçlendirmeler", systemImage: "sparkles", value: RootTab.augments) {
                AugmentListView(path: $augmentsPath)
            }
            Tab("Rehber", systemImage: "book.fill", value: RootTab.guide) {
                GuideView(path: $guidePath)
            }
        }
        .tint(Theme.accent)
        .onAppear { restore() }
        .onChange(of: snapshot) { _, state in save(state) }
    }

    private var snapshot: NavigationState {
        NavigationState(
            tab: tab,
            comps: compsPath,
            champions: championsPath,
            items: itemsPath,
            augments: augmentsPath,
            guide: guidePath
        )
    }

    private func save(_ state: NavigationState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        storedNavigation = String(decoding: data, as: UTF8.self)
        storedNavigationAt = Date.now.timeIntervalSince1970
    }

    /// Bozuk veya eskimiş kayıt sessizce yok sayılır.
    private func restore() {
        guard !restored else { return }
        restored = true
        guard Date.now.timeIntervalSince1970 - storedNavigationAt < Self.restoreWindow,
              let data = storedNavigation.data(using: .utf8),
              let state = try? JSONDecoder().decode(NavigationState.self, from: data)
        else { return }

        tab = state.tab
        compsPath = state.comps
        championsPath = state.champions
        itemsPath = state.items
        augmentsPath = state.augments
        guidePath = state.guide
    }
}

enum RootTab: String, Codable {
    case comps
    case champions
    case items
    case augments
    case guide
}

/// Sahne durumuna yazılan sekme + yığın kaydı.
struct NavigationState: Codable, Equatable {
    var tab: RootTab = .comps
    var comps: [Route] = []
    var champions: [Route] = []
    var items: [Route] = []
    var augments: [Route] = []
    var guide: [Route] = []
}

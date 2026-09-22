import SwiftUI

@main
struct HexKocApp: App {
    @State private var store = DataStore()
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .preferredColorScheme(.dark)
                .task { await store.refresh() }
        }
    }
}

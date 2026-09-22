import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Komplar", systemImage: "list.bullet.rectangle.portrait") {
                CompListView()
            }
            Tab("Şampiyonlar", systemImage: "person.3.fill") {
                ChampionsTabView()
            }
            Tab("Eşyalar", systemImage: "shield.lefthalf.filled") {
                ItemsTabView()
            }
            Tab("Güçlendirmeler", systemImage: "sparkles") {
                AugmentListView()
            }
            Tab("Rehber", systemImage: "book.fill") {
                GuideView()
            }
        }
        .tint(Theme.accent)
    }
}

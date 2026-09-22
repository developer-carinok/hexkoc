import SwiftUI

struct GuideView: View {
    @Binding var path: [Route]

    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    toolsRow

                    if groups.isEmpty {
                        EmptyStateView(
                            title: "Rehber bulunamadı",
                            message: "Rehber içeriği henüz yüklenmedi.",
                            systemImage: "book.closed"
                        )
                    } else {
                        ForEach(groups, id: \.category) { group in
                            Text(group.category.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.accent)
                                .padding(.top, 6)

                            ForEach(group.articles) { article in
                                NavigationLink(value: Route.article(article.id)) {
                                    articleRow(article)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Rehber")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Ayarlar")
                }
            }
            .hexKocDestinations()
        }
    }

    private var toolsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Araçlar")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.accent)
                .padding(.top, 4)

            HStack(spacing: 8) {
                NavigationLink { ShopOddsView() } label: {
                    toolCard("Şans Tablosu", systemImage: "percent")
                }
                .buttonStyle(.plain)

                NavigationLink { XPView() } label: {
                    toolCard("Seviye & XP", systemImage: "chart.bar.fill")
                }
                .buttonStyle(.plain)

                NavigationLink { TeamCodeDecoderView() } label: {
                    toolCard("Kod Çözücü", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolCard(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func articleRow(_ article: GuideArticle) -> some View {
        Card(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: article.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.text)
                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                Text("\(article.minutes) dk")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(minHeight: Theme.rowMinHeight)
    }

    private var groups: [(category: GuideCategory, articles: [GuideArticle])] {
        GuideCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                let articles = store.articles.filter { $0.category == category }
                return articles.isEmpty ? nil : (category, articles)
            }
    }
}

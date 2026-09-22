import SwiftUI

struct ArticleView: View {
    let articleID: String
    @Environment(DataStore.self) private var store

    var body: some View {
        Group {
            if let article = store.article(articleID) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        header(article)
                        ForEach(GuideMarkdown.parse(article.body)) { block in
                            blockView(block)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .navigationTitle(article.title)
            } else {
                EmptyStateView(title: "Yazı bulunamadı", message: "Bu rehber yazısı güncel veride yok.")
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ article: GuideArticle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(article.title)
                .font(.title2.bold())
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Chip(text: article.category.title, color: Theme.accent)
                Text("\(article.minutes) dk")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Hairline().padding(.top, 4)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func blockView(_ block: GuideBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .foregroundStyle(level == 1 ? Theme.text : Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level == 1 ? 8 : 4)

        case .paragraph(let text):
            Text(.init(text))
                .font(.body)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(.init(item))
                            .font(.body)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .numbered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.body.bold().monospacedDigit())
                            .foregroundStyle(Theme.accent)
                        Text(.init(item))
                            .font(.body)
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .callout(let lines):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
                Text(.init(lines.joined(separator: " ")))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))

        case .table(let kind):
            GuideTableView(kind: kind)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.bold()
        case 2: .title3.bold()
        default: .headline
        }
    }
}

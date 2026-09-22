import SwiftUI

/// Paketteki PNG'yi (varsa) gösterir, yoksa uzak adrese düşer.
/// Liste hücrelerinde disk okuması ana iş parçacığında yapılmaz.
struct IconView: View {
    let path: String?
    let url: URL?
    var size: CGFloat
    var contentMode: ContentMode = .fit

    @State private var image: UIImage?
    @State private var bundleResolved = false

    init(path: String?, url: String?, size: CGFloat, contentMode: ContentMode = .fit) {
        self.path = path
        self.url = url.flatMap(URL.init(string:))
        self.size = size
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if bundleResolved, let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .task(id: path) { await load() }
    }

    private var placeholder: some View {
        HexagonShape()
            .fill(Theme.elevated)
            .overlay(HexagonShape().strokeBorder(Theme.hairline, lineWidth: 1))
            .padding(size * 0.08)
    }

    private func load() async {
        guard let path, !path.isEmpty else {
            bundleResolved = true
            return
        }
        if let cached = ImageProvider.shared.cachedImage(path: path) {
            image = cached
            return
        }
        if ImageProvider.shared.isMissing(path: path) {
            bundleResolved = true
            return
        }
        let loaded = await ImageProvider.shared.image(path: path)
        guard !Task.isCancelled else { return }
        image = loaded
        bundleResolved = true
    }
}

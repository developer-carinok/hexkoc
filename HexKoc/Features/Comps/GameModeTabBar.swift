import SwiftUI

/// Oyun modunun sayfa seçicisi. Baş parmakla erişilsin diye her hedef 44 pt yüksekliğinde.
struct GameModeTabBar: View {
    @Binding var page: GameModePage

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GameModePage.allCases) { item in
                Button {
                    guard item != page else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { page = item }
                    Haptics.tap()
                } label: {
                    label(item)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == page ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func label(_ item: GameModePage) -> some View {
        let selected = item == page
        return HStack(spacing: 5) {
            Image(systemName: item.symbol)
                .font(.caption.weight(.bold))
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(selected ? Theme.background : Theme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(selected ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1)
        )
    }
}

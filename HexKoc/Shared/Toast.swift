import SwiftUI

/// Kopyalama gibi geri bildirimler için 1,6 saniyelik küçük bir bildirim.
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.elevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(1.6))
                            withAnimation(.easeOut(duration: 0.2)) { self.message = nil }
                        }
                }
            }
            .animation(.spring(duration: 0.28), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

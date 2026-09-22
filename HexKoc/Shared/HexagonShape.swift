import SwiftUI

/// Sivri tepeli (pointy-top) altıgen. Genişlik = düz kenarlar arası,
/// yükseklik = tepe noktaları arası (genişlik × 2/√3).
struct HexagonShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        let quarter = rect.height / 4
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + quarter))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - quarter))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - quarter))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + quarter))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> HexagonShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

enum Hex {
    /// Sivri tepeli altıgende yükseklik / genişlik.
    static let heightRatio: CGFloat = 2 / 1.7320508

    /// Satırlar hafifçe iç içe geçer.
    static let pitchRatio: CGFloat = 0.866
}

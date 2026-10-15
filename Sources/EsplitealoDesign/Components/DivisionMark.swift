import SwiftUI

/// The ÷ from the logo: two dots and a bar. Decorative; it never carries meaning on its own.
/// Path data is the `--div-mask` of the mockups (viewBox 24 × 24).
public struct DivisionMark: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let originX = rect.midX - 12 * scale
        let originY = rect.midY - 12 * scale
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: originX + x * scale, y: originY + y * scale) }
        var path = Path()
        path.addEllipse(in: CGRect(origin: point(12 - 2.5, 4.6 - 2.5), size: CGSize(width: 5 * scale, height: 5 * scale)))
        path.addRoundedRect(
            in: CGRect(origin: point(3, 10.4), size: CGSize(width: 18 * scale, height: 3.2 * scale)),
            cornerSize: CGSize(width: 1.6 * scale, height: 1.6 * scale)
        )
        path.addEllipse(in: CGRect(origin: point(12 - 2.5, 19.4 - 2.5), size: CGSize(width: 5 * scale, height: 5 * scale)))
        return path
    }
}

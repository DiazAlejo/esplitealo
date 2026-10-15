import Foundation

/// Size and scale math shared by the SwiftUI view and the SVG export.
public enum ChavitoMetrics {
    /// The `viewBox="0 6 200 190"` the mockup uses for the bare head.
    public static let headViewBox = ChavitoRect(x: 0, y: 6, width: 200, height: 190)

    /// Disc from `sceneHome`: radius 104, centred on head art point (100, 114).
    public static let discCenter = ChavitoPoint(x: 100, y: 114)
    public static let discRadius = 104.0
    public static let discViewBox = ChavitoRect(x: -4, y: 10, width: 208, height: 208)

    public static func viewBox(disc: Bool) -> ChavitoRect { disc ? discViewBox : headViewBox }

    private static func sanitized(_ width: Double) -> Double { width.isFinite ? max(0, width) : 0 }

    /// Points per art unit when the artwork is `width` points wide.
    public static func scale(forWidth width: Double, disc: Bool) -> Double {
        sanitized(width) / viewBox(disc: disc).width
    }

    public static func layoutSize(forWidth width: Double, disc: Bool) -> (width: Double, height: Double) {
        let box = viewBox(disc: disc)
        let w = sanitized(width)
        return (w, w * box.height / box.width)
    }
}

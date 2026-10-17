import CoreGraphics

/// The only findings of `performAccessibilityAudit()` that are not failures, and why. Nothing is switched off: every
/// finding is still logged, and anything not described here fails the test.
///
/// - Anything drawn by the system on top of the app (the keyboard, an alert): not ours to change.
/// - Dynamic Type for text inside the navigation bar: UIKit does not scale the bar's items past a point, so "Paso 3 de 5"
///   and the back buttons cannot grow. Text that has to grow is checked in the content of the screen and by the AX3 and AX5 snapshots.
struct AuditWaiver {
    enum Reason: Equatable {
        case systemView
        case navigationBarDoesNotScale
    }

    /// `elementCenter` is where the element is on screen; the frames are those of the keyboard, alerts and the navigation bar
    /// when they are showing.
    static func reason(isDynamicTypeIssue: Bool, elementCenter: CGPoint, navigationBar: CGRect?, systemFrames: [CGRect]) -> Reason? {
        if systemFrames.contains(where: { $0.contains(elementCenter) }) { return .systemView }
        if isDynamicTypeIssue, let navigationBar, navigationBar.contains(elementCenter) { return .navigationBarDoesNotScale }
        return nil
    }
}

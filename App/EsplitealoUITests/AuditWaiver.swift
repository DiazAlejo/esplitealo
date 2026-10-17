import CoreGraphics

/// The only findings of `performAccessibilityAudit()` that are not failures, and why. Nothing is switched off: every
/// finding is still logged with its element, and anything not described here fails the test.
///
/// - **A system view**: the element is inside the keyboard or an alert, which the app does not draw.
/// - **The navigation bar and Dynamic Type**: UIKit does not scale the bar's items ("Paso 3 de 5", the back button), so
///   they cannot grow. Text that has to grow is in the content of the screen, where the audit does check it.
/// - **Contrast of an element that is partly off screen**: the audit reads pixels, and the pixels past the edge of the
///   screen (under the status bar, behind the pinned bottom bar or the keyboard) are not the element's own. The pairs of
///   colours themselves are decided by `ContrastTests` and `AccessibilityContrastTests`.
/// - **"Potentially inaccessible text" under a sheet**: a sheet that does not cover the whole screen leaves the screen
///   behind it visible but, as it should be, hidden from VoiceOver.
struct AuditWaiver {
    enum Reason: Equatable {
        case systemView
        case navigationBarDoesNotScale
        case contrastOfAPartlyHiddenElement
        case screenBehindASheet
    }

    enum Kind: Equatable {
        case dynamicType
        case contrast
        case inaccessibleText
        case other
    }

    /// `elementFrame` is the element on screen; the other frames are those of the window, the keyboard and alerts, and the
    /// navigation bar, when they are showing.
    static func reason(
        kind: Kind,
        elementFrame: CGRect?,
        window: CGRect,
        navigationBar: CGRect?,
        systemFrames: [CGRect],
        underSheet: Bool
    ) -> Reason? {
        if kind == .inaccessibleText, underSheet { return .screenBehindASheet }
        guard let elementFrame else { return nil }
        let center = CGPoint(x: elementFrame.midX, y: elementFrame.midY)
        if systemFrames.contains(where: { $0.contains(center) }) { return .systemView }
        if kind == .dynamicType, let navigationBar, navigationBar.contains(center) { return .navigationBarDoesNotScale }
        if kind == .contrast, !window.insetBy(dx: -0.5, dy: -0.5).contains(elementFrame) { return .contrastOfAPartlyHiddenElement }
        return nil
    }
}

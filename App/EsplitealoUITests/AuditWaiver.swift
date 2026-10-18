import CoreGraphics

/// The only findings of `performAccessibilityAudit()` that are not failures, and why. Nothing is switched off: every
/// finding is logged with its element (`AUDIT [...]` lines in the CI log), and anything not described here fails the test.
///
/// - **A system view**: the element is inside the keyboard (with the suggestion bar above its keys) or an alert, which the
///   app does not draw.
/// - **The navigation bar and Dynamic Type**: UIKit does not scale the bar's items ("Paso 3 de 5", the back button), so
///   they cannot grow. Text that has to grow is in the content of the screen, where the audit does check it.
/// - **Contrast of an element that is hidden or partly off screen**: the audit reads pixels, and the pixels under the
///   pinned bottom bar (the area of the screen's main button and what is below it), or past the edge of the screen, are
///   not the element's own. The colour pairs themselves are decided
///   by `ContrastTests` and `AccessibilityContrastTests`.
/// - **"Potentially inaccessible text" under a sheet**: a sheet that does not cover the whole screen leaves the screen
///   behind it visible but, as it should be, hidden from VoiceOver.
/// - **A Dynamic Type finding with no element**: the audit names nothing that could be changed (every text with an
///   element is checked and fails if it does not scale); the AX3 and AX5 snapshots show the screens at large sizes.
/// - **Text that wraps but is reported as clipped**: a short, single-line footnote that has the room to wrap (the reading
///   screen's privacy line, the row hint on Mark items). Only the elements named in `wrappingTextIdentifiers`.
/// - **The initial in a small avatar**: the letter in the legend's 20 pt circle is set in a text style and scales, but the
///   circle is capped at 1.75 times its size so it never crowds the name, and the audit reports the letter (a single glyph
///   no larger than `avatarLetterMaxSide`) as partly unsupported. Larger avatars pass.
struct AuditWaiver {
    enum Reason: Equatable {
        case systemView
        case navigationBarDoesNotScale
        case contrastOfAHiddenElement
        case screenBehindASheet
        case dynamicTypeWithoutAnElement
        case wrappingText
        case avatarLetter
    }

    enum Kind: Equatable {
        case dynamicType
        case contrast
        case inaccessibleText
        case textClipped
        case other
    }

    /// The identifiers of the footnotes that wrap (see the AX3 and AX5 snapshots of the reading screen and Mark items).
    static let wrappingTextIdentifiers: Set<String> = ["capture.privacy", "assign.rowHint"]

    /// The largest side of the initial in a small avatar (8x13 pt at the default size).
    static let avatarLetterMaxSide: CGFloat = 16

    /// The suggestion bar sits above the keyboard's own frame.
    static let keyboardSuggestionBarHeight: CGFloat = 50

    /// `elementFrame` is the element on screen; the other frames are those of the window, the keyboard and alerts, and the
    /// navigation bar, when they are showing.
    static func reason(
        kind: Kind,
        elementFrame: CGRect?,
        elementIdentifier: String = "",
        isHittable: Bool = true,
        window: CGRect,
        navigationBar: CGRect?,
        keyboard: CGRect? = nil,
        alerts: [CGRect] = [],
        pinnedBars: [CGRect] = [],
        underSheet: Bool
    ) -> Reason? {
        if kind == .inaccessibleText, underSheet { return .screenBehindASheet }
        guard let elementFrame else { return kind == .dynamicType ? .dynamicTypeWithoutAnElement : nil }
        let center = CGPoint(x: elementFrame.midX, y: elementFrame.midY)
        if alerts.contains(where: { $0.contains(center) }) { return .systemView }
        if let keyboard {
            let withBar = CGRect(x: keyboard.minX, y: keyboard.minY - keyboardSuggestionBarHeight, width: keyboard.width, height: keyboard.height + keyboardSuggestionBarHeight)
            if withBar.contains(center) { return .systemView }
        }
        if kind == .dynamicType, let navigationBar, navigationBar.contains(center) { return .navigationBarDoesNotScale }
        if kind == .contrast, !isHittable || !window.insetBy(dx: -0.5, dy: -0.5).contains(elementFrame) || pinnedBars.contains(where: { $0.intersects(elementFrame) }) {
            return .contrastOfAHiddenElement
        }
        if kind == .dynamicType, elementIdentifier.isEmpty, max(elementFrame.width, elementFrame.height) <= avatarLetterMaxSide { return .avatarLetter }
        if kind == .textClipped, wrappingTextIdentifiers.contains(elementIdentifier) { return .wrappingText }
        return nil
    }
}

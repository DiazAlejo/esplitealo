import EsplitealoDesign
import Foundation
import SwiftUI

/// What VoiceOver is told when something changes and nothing on screen moves. Amounts are spoken ("9 dollars"), not
/// written ("$9.00"), and every sentence follows the language of the screen, not of the device.
enum AccessibilityAnnouncements {
    /// The reconciliation result after an edit on Review, with how far off it is when it does not add up.
    static func reviewResult(_ status: ReceiptReviewModel.Status, locale: Locale) -> String? {
        let spoken = MoneyFormatter(locale: locale)
        switch status {
        case .noItems:
            return nil
        case .balanced:
            return String(resolving: .reviewOkTitle, in: locale)
        case .missingTotal:
            return String(resolving: .reviewMissingTotalTitle, in: locale)
        case .itemsDoNotMatchSubtotal, .totalsDoNotAddUp:
            let title = String(resolving: .reviewWarnTitle, in: locale)
            guard let difference = status.differenceCents else { return title }
            return "\(title). \(String(resolving: .reviewDiff(spoken.spokenString(cents: difference)), in: locale))"
        }
    }

    /// The new bill total after the tip changed.
    static func billTotalWithTip(cents: Int, locale: Locale) -> String {
        "\(String(resolving: .totalsBillTotal, in: locale)): \(MoneyFormatter(locale: locale).spokenString(cents: cents))"
    }

    /// The rounding card appeared: say what it is, because it is further down the page.
    static func strayCentsShared(locale: Locale) -> String {
        String(resolving: .totalsRoundTitle, in: locale)
    }

    /// The reading screen's status line; it cycles through three messages.
    static func readingProgress(messageIndex: Int, locale: Locale) -> String {
        switch messageIndex % ScanFlow.messageCount {
        case 0: String(resolving: .processingMessage1, in: locale)
        case 1: String(resolving: .processingMessage2, in: locale)
        default: String(resolving: .processingMessage3, in: locale)
        }
    }

    static func scanFailed(_ failure: ScanFailure, locale: Locale) -> String {
        "\(String(resolving: failure.title, in: locale)). \(String(resolving: failure.body, in: locale))"
    }

    static func cameraBlocked(_ block: CaptureBlock, locale: Locale) -> String {
        "\(String(resolving: block.title, in: locale)). \(String(resolving: block.body, in: locale))"
    }

    static func post(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        AccessibilityNotification.Announcement(text).post()
    }
}

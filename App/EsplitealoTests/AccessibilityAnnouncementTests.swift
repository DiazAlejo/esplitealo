import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// What VoiceOver is told when something changes and nothing on screen moves: the reconciliation result after an
/// edit, the new total after a tip change, the reading progress, and why a scan or the camera failed. Amounts are
/// spoken ("9 dollars"), not written ("$9.00"), and everything follows the language of the screen.
struct AccessibilityAnnouncementTests {
    nonisolated static let locales = [Locale(identifier: "es"), Locale(identifier: "en")]

    // MARK: Review

    @Test(arguments: locales)
    func aBalancedReceiptIsAnnouncedWithoutNumbers(locale: Locale) {
        #expect(AccessibilityAnnouncements.reviewResult(.balanced, locale: locale) == String(resolving: .reviewOkTitle, in: locale))
    }

    @Test func aReceiptThatDoesNotAddUpSaysHowFarOffItIsInWords() {
        let english = Locale(identifier: "en")
        let spanish = Locale(identifier: "es")
        let items = ReceiptReviewModel.Status.itemsDoNotMatchSubtotal(itemsCents: 10_100, subtotalCents: 11_000)
        #expect(AccessibilityAnnouncements.reviewResult(items, locale: english) == "Numbers don’t add up yet. Off by 9 dollars.")
        #expect(AccessibilityAnnouncements.reviewResult(items, locale: spanish) == "Los números como quiera no cuadran. Diferencia: 9 dólares.")

        let totals = ReceiptReviewModel.Status.totalsDoNotAddUp(expectedCents: 13_282, printedCents: 13_250, includesService: false)
        #expect(AccessibilityAnnouncements.reviewResult(totals, locale: english) == "Numbers don’t add up yet. Off by 32 cents.")
    }

    @Test(arguments: locales)
    func aMissingTotalIsAnnouncedAndNoItemsIsSilent(locale: Locale) {
        #expect(AccessibilityAnnouncements.reviewResult(.missingTotal, locale: locale) == String(resolving: .reviewMissingTotalTitle, in: locale))
        #expect(AccessibilityAnnouncements.reviewResult(.noItems, locale: locale) == nil)
    }

    // MARK: Totals

    @Test func aTipChangeAnnouncesTheNewBillTotalInWords() {
        #expect(AccessibilityAnnouncements.billTotalWithTip(cents: 13_282, locale: Locale(identifier: "en")) == "Bill total with tip: 132 dollars and 82 cents")
        #expect(AccessibilityAnnouncements.billTotalWithTip(cents: 13_282, locale: Locale(identifier: "es")) == "Total de la cuenta con propina: 132 dólares con 82 centavos")
    }

    @Test func strayCentsAreAnnouncedWithTheTitleOfTheRoundingCard() {
        #expect(AccessibilityAnnouncements.strayCentsShared(locale: Locale(identifier: "en")) == "Where the stray cents went")
        #expect(AccessibilityAnnouncements.strayCentsShared(locale: Locale(identifier: "es")) == "Dónde cayeron los chavitos sueltos")
    }

    // MARK: Capture

    @Test func readingProgressCyclesThroughTheThreeMessages() {
        let english = Locale(identifier: "en")
        #expect(AccessibilityAnnouncements.readingProgress(messageIndex: 0, locale: english) == "Reading receipt")
        #expect(AccessibilityAnnouncements.readingProgress(messageIndex: 1, locale: english) == "Finding prices")
        #expect(AccessibilityAnnouncements.readingProgress(messageIndex: 2, locale: english) == "Checking the total")
        #expect(AccessibilityAnnouncements.readingProgress(messageIndex: 4, locale: english) == "Finding prices")
        #expect(AccessibilityAnnouncements.readingProgress(messageIndex: 0, locale: Locale(identifier: "es")) == "Leyendo el recibo")
    }

    @Test(arguments: locales, ScanFailure.allCases)
    func aFailedScanReadsItsTitleThenWhatToDo(locale: Locale, failure: ScanFailure) {
        let title = String(resolving: failure.title, in: locale)
        let body = String(resolving: failure.body, in: locale)
        #expect(AccessibilityAnnouncements.scanFailed(failure, locale: locale) == "\(title). \(body)")
    }

    @Test(arguments: locales, [CaptureBlock.denied, .unavailable])
    func aBlockedCameraReadsItsTitleThenWhatToDo(locale: Locale, block: CaptureBlock) {
        let title = String(resolving: block.title, in: locale)
        let body = String(resolving: block.body, in: locale)
        #expect(AccessibilityAnnouncements.cameraBlocked(block, locale: locale) == "\(title). \(body)")
    }
}

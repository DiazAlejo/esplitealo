import XCTest
@testable import EsplitealoCore
import EsplitealoTestSupport

/// What the parser can safely recover when Vision misreads or drops part of a row: only readings that the receipt's own
/// arithmetic confirms, and everything else stays flagged. Patterns taken from the receipt stress test
/// (docs/OCR_BENCHMARK.md).
final class ReceiptParserOcrRecoveryTests: XCTestCase {
    private let parser = ReceiptParser()

    private func parse(_ rows: [String]) -> ReceiptDraft {
        parser.parse(RecognizedTextTestBuilder.fromRowTexts(rows))
    }

    func testAtSignReadAsEuroGivesTheQuantityBecauseUnitTimesQuantityIsTheTotal() {
        let draft = parse(["Mozzarella Sticks 2 € 6.40 12.80", "Total 12.80"])
        XCTAssertEqual(draft.items.map(\.quantity), [2])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1280])
        XCTAssertEqual(draft.items.first?.unitPrice?.minorUnits, 640)
        XCTAssertEqual(draft.items.first?.name, "Mozzarella Sticks")
        XCTAssertTrue(draft.items.first?.flags.isEmpty ?? false)
    }

    func testAtSignReadAsDigitGivesTheQuantity() {
        let draft = parse(["Margarita 4 8 9.19 36.76", "Total 36.76"])
        XCTAssertEqual(draft.items.map(\.quantity), [4])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [3676])
    }

    func testUnitPriceAndLineTotalThatDivideEvenlyGiveTheQuantity() {
        let draft = parse(["Pan sobao 3.76 11.28", "Total 11.28"])
        XCTAssertEqual(draft.items.map(\.quantity), [3])
    }

    func testTwoPricesThatDoNotDivideStayOneItemAndAreFlagged() {
        let draft = parse(["Pan sobao 3.76 10.00", "Total 10.00"])
        XCTAssertEqual(draft.items.map(\.quantity), [1])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1000])
        XCTAssertTrue(draft.items[0].flags.contains(.needsReview))
    }

    func testQuantityRowWithAMisreadParenthesisUsesTheQuantityTheTotalConfirms() {
        let draft = parse(["Pitcher $32.16", "13 x $10.72)", "Total $32.16"])
        XCTAssertEqual(draft.items.map(\.quantity), [3])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [3216])
        XCTAssertTrue(draft.items[0].flags.contains(.needsReview))
    }

    func testPriceRowsWhoseNamesWereDroppedStayAsFlaggedItems() {
        let draft = parse(["Nuggets 10.35", "$2.95", "$4.01", "Empanada 9.55", "Subtotal 26.86", "Total 26.86"])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1035, 295, 401, 955])
        XCTAssertEqual(draft.items.map(\.name), ["Nuggets", "", "", "Empanada"])
        XCTAssertEqual(draft.items.map { $0.flags.contains(.needsReview) }, [false, true, true, false])
        XCTAssertTrue(draft.reconciles)
    }

    func testPriceRowThatIsTheSumOfTheItemsIsASubtotalWhoseLabelWasDropped() {
        let draft = parse(["Pan 5.00", "Leche 2.00", "7.00", "IVU 11.5% 0.81", "Total 7.81"])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [500, 200])
        XCTAssertEqual(draft.subtotal?.minorUnits, 700)
        XCTAssertTrue(draft.subtotal?.needsAttention ?? false)
        XCTAssertEqual(draft.total?.minorUnits, 781)
        XCTAssertTrue(draft.reconciles)
    }

    func testTotalWhoseLabelWasDroppedIsRecoveredOnlyWhenItAddsUp() {
        let recovered = parse(["Pan 5.00", "Subtotal 5.00", "IVU 11.5% 0.58", "5.58"])
        XCTAssertEqual(recovered.total?.minorUnits, 558)
        XCTAssertTrue(recovered.total?.needsAttention ?? false)

        let unrelated = parse(["Pan 5.00", "Subtotal 5.00", "IVU 11.5% 0.58", "9.99"])
        XCTAssertNil(unrelated.total)
        XCTAssertTrue(unrelated.issues.contains(.noTotalFound))
    }

    func testGarbledZipCodeWithSeveralNumbersIsNotAnItem() {
        let draft = parse(["Ponce, PR 2 0071 00717", "Pan 5.00", "Total 5.00"])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [500])
        XCTAssertEqual(draft.issues, [])
    }

    func testChargeAloneIsATip() {
        let draft = parse(["Pan 10.00", "Subtotal 10.00", "Charge 15% 1.50", "Total 11.50"])
        XCTAssertEqual(draft.tip?.minorUnits, 150)
        XCTAssertTrue(draft.reconciles)
    }
}

import XCTest
@testable import EsplitealoCore
import EsplitealoTestSupport

/// The parser says what it was unsure about, in a form the Review screen can show: a warning per unreadable price
/// row, with the row's name and the printed text. The parser's decisions (items, amounts, `issues`) do not change.
final class ReceiptWarningTests: XCTestCase {
    private let parser = ReceiptParser()
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Receipts", isDirectory: true)

    private func parseFixture(_ name: String) throws -> ReceiptDraft {
        let data = try Data(contentsOf: fixturesURL.appendingPathComponent("\(name).recognized.json"))
        return parser.parse(try JSONDecoder().decode(RecognizedText.self, from: data))
    }

    func testAnUnreadablePriceBecomesAWarningWithItsRowAndText() throws {
        let draft = try parseFixture("unparsed-price-row")
        XCTAssertEqual(draft.warnings.count, 1)
        let warning = try XCTUnwrap(draft.warnings.first)
        XCTAssertEqual(warning.issue, .unparsedPriceRow("3,5"))
        XCTAssertEqual(warning.rowLabel, "Soda")
        XCTAssertNotNil(warning.sourceRect)
        XCTAssertNil(warning.itemID, "the unreadable row did not become an item")
        XCTAssertFalse(warning.isDismissed)
        XCTAssertEqual(draft.activeWarnings, [warning])
    }

    func testTheParsersDecisionsAreUnchangedByWarnings() throws {
        let draft = try parseFixture("unparsed-price-row")
        XCTAssertEqual(draft.items.map(\.name), ["Coffee", "Tostada"])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [350, 225])
        XCTAssertTrue(draft.reconciles)
        XCTAssertEqual(draft.issues, [.unparsedPriceRow("3,5")], "the issue list is what it always was")
    }

    func testTheRealReceiptsCardTerminalBlockProducesNoWarnings() throws {
        let draft = try parseFixture("pr-party-store-wrapped-names")
        XCTAssertTrue(draft.warnings.isEmpty, "\(draft.warnings)")
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
        XCTAssertEqual(draft.items.count, 2)
    }

    func testEveryUnparsedPriceIssueHasAWarningWithTheSameText() {
        let receipts: [[String]] = [
            ["(3 x $11.50)", "Tea 4.00", "Subtotal 4.00", "Total 4.00"],
            ["Tea 4.00", "Cake 3.00", "Soda 3,5", "Subtotal 7.00", "Total 7.00"],
            ["Tea 4.00", "Cake 3.00", "Subtotal 7.00", "Tax 3,5", "Total 7.00"],
        ]
        for rows in receipts {
            let draft = parser.parse(RecognizedTextTestBuilder.fromRowTexts(rows))
            let issueTexts = draft.issues.compactMap { issue -> String? in
                if case let .unparsedPriceRow(text) = issue { text } else { nil }
            }
            let warningTexts = draft.warnings.compactMap { warning -> String? in
                if case let .unparsedPriceRow(text) = warning.issue { text } else { nil }
            }
            XCTAssertFalse(issueTexts.isEmpty, "\(rows) should produce an unparsed price row")
            XCTAssertEqual(warningTexts, issueTexts, "\(rows)")
        }
    }

    func testAnUnreadableTaxLineNamesItsRow() {
        let draft = parser.parse(RecognizedTextTestBuilder.fromRowTexts([
            "Tea 4.00", "Cake 3.00", "Subtotal 7.00", "IVU 3,5", "Total 7.00",
        ]))
        XCTAssertEqual(draft.warnings.count, 1)
        XCTAssertEqual(draft.warnings.first?.rowLabel, "IVU")
        XCTAssertEqual(draft.warnings.first?.issue, .unparsedPriceRow("3,5"))
    }

    func testAGuessedNumberFormatIsAWarning() {
        let draft = parser.parse(RecognizedTextTestBuilder.fromRowTexts([
            "Soup 1.500", "Rice 2.500", "Total 4.000",
        ]))
        XCTAssertTrue(draft.numberFormat.isGuessed)
        XCTAssertEqual(draft.warnings.map(\.issue), [.numberFormatGuessed(draft.numberFormat)])
        XCTAssertNil(draft.warnings.first?.rowLabel)
    }

    func testChecksTheScreenAlreadyShowsAreNotWarnings() {
        let draft = parser.parse(RecognizedTextTestBuilder.fromRowTexts([
            "Burger 12.00", "Fries 4.00", "Subtotal 20.00", "Total 20.00",
        ]))
        XCTAssertFalse(draft.issues.isEmpty)
        XCTAssertTrue(draft.warnings.isEmpty, "a mismatch is the banner's job; \(draft.warnings)")
        let empty = parser.parse(RecognizedTextTestBuilder.fromRowTexts(["Gracias por su visita"]))
        XCTAssertTrue(empty.warnings.isEmpty, "no items and no total are the empty and missing-total states")
    }

    func testEachWarningHasItsOwnIdentity() {
        let draft = parser.parse(RecognizedTextTestBuilder.fromRowTexts([
            "Tea 4.00", "Soda 3,5", "Cake 3,5", "Subtotal 4.00", "Total 4.00",
        ]))
        XCTAssertEqual(draft.warnings.count, 2)
        XCTAssertEqual(Set(draft.warnings.map(\.id)).count, 2)
    }
}

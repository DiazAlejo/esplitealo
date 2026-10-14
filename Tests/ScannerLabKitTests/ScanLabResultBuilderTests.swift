import EsplitealoCore
import XCTest
@testable import ScannerLabKit

final class ScanLabResultBuilderTests: XCTestCase {
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Receipts", isDirectory: true)

    func testEnglishDinerDisplaySections() throws {
        let recognized = try loadRecognized(named: "english-diner")
        let parser = ReceiptParser()
        let draft = parser.parse(recognized)
        let result = ReceiptScanResult(recognizedText: recognized, draft: draft)
        let display = ScanLabResultBuilder.display(from: result, parser: parser, ocrDurationMilliseconds: 42)

        XCTAssertEqual(display.recognizedLines.count, recognized.lines.count)
        XCTAssertFalse(display.rebuiltRows.isEmpty)
        XCTAssertEqual(display.items.count, 2)
        XCTAssertEqual(display.items[0].description, "Burger")
        XCTAssertEqual(display.items[0].quantity, 2)
        XCTAssertEqual(display.items[0].priceLabel, "18.00")
        XCTAssertEqual(display.subtotal?.label, "22.50")
        XCTAssertEqual(display.tax?.label, "1.80")
        XCTAssertEqual(display.total?.label, "24.30")
        XCTAssertTrue(display.reconciles)
        XCTAssertEqual(display.ocrDurationMilliseconds, 42)
        XCTAssertTrue(display.reconciliationSummary.contains("Reconciles"))
    }

    func testMismatchFixtureFlagsReconciliation() throws {
        let recognized = try loadRecognized(named: "mismatch-adversarial")
        let parser = ReceiptParser()
        let draft = parser.parse(recognized)
        let result = ReceiptScanResult(recognizedText: recognized, draft: draft)
        let display = ScanLabResultBuilder.display(from: result, parser: parser)

        XCTAssertFalse(display.reconciles)
        XCTAssertFalse(display.issues.isEmpty)
    }

    private func loadRecognized(named name: String) throws -> RecognizedText {
        let url = fixturesURL.appendingPathComponent("\(name).recognized.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RecognizedText.self, from: data)
    }
}

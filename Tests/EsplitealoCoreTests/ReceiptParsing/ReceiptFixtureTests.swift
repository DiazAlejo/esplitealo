import XCTest
@testable import EsplitealoCore

private struct FixtureExpectation: Decodable {
    var itemTotals: [Int]
    var quantities: [Int]?
    var subtotal: Int?
    var tax: Int?
    var total: Int?
    var reconciles: Bool
}

final class ReceiptFixtureTests: XCTestCase {
    private let parser = ReceiptParser()
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Receipts", isDirectory: true)

    func testVisionRecordedFixtures() throws {
        let names = ["pr-ivu-bistro", "english-diner", "comma-decimal-cafe", "mismatch-adversarial"]
        for name in names {
            let recognizedURL = fixturesURL.appendingPathComponent("\(name).recognized.json")
            let expectedURL = fixturesURL.appendingPathComponent("\(name).expected.json")
            let recognized = try loadRecognizedText(from: recognizedURL)
            let expected = try loadExpectation(from: expectedURL)
            assertDraft(parser.parse(recognized), matches: expected, fixture: name)
        }
    }

    private func loadRecognizedText(from url: URL) throws -> RecognizedText {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RecognizedText.self, from: data)
    }

    private func loadExpectation(from url: URL) throws -> FixtureExpectation {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FixtureExpectation.self, from: data)
    }

    private func assertDraft(_ draft: ReceiptDraft, matches expected: FixtureExpectation, fixture: String) {
        XCTAssertEqual(
            draft.items.map(\.lineTotal.minorUnits),
            expected.itemTotals,
            "item totals for \(fixture)"
        )
        if let quantities = expected.quantities {
            XCTAssertEqual(draft.items.map(\.quantity), quantities, "quantities for \(fixture)")
        }
        if let subtotal = expected.subtotal {
            XCTAssertEqual(draft.subtotal?.minorUnits, subtotal, "subtotal for \(fixture)")
        }
        if let tax = expected.tax {
            XCTAssertEqual(draft.tax?.minorUnits, tax, "tax for \(fixture)")
        }
        if let total = expected.total {
            XCTAssertEqual(draft.total?.minorUnits, total, "total for \(fixture)")
        }
        XCTAssertEqual(draft.reconciles, expected.reconciles, "reconciles for \(fixture)")
    }
}

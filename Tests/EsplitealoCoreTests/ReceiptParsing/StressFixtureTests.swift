import XCTest
@testable import EsplitealoCore

/// Replays every `stress-*.recognized.json` in `Tests/Fixtures/Receipts`: text that the real Vision scanner read from a
/// generated Puerto Rico receipt (see docs/OCR_BENCHMARK.md) and that once broke the parser. The matching
/// `.expected.json` is the generator's ground truth. Fully synthetic: no real merchant, card or person.
final class StressFixtureTests: XCTestCase {
    private struct Expected: Decodable {
        var itemTotals: [Int]
        var quantities: [Int]?
        var adjustments: [Int]?
        var subtotal: Int
        var tax: Int?
        var tip: Int?
        var total: Int
    }

    private let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Receipts", isDirectory: true)

    func testStressFixturesParseToTheGeneratedBill() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("stress-") && $0.hasSuffix(".recognized.json") }
            .map { String($0.dropLast(".recognized.json".count)) }
            .sorted()
        XCTAssertFalse(names.isEmpty, "no stress fixtures found")
        for name in names {
            let recognized = try JSONDecoder().decode(
                RecognizedText.self, from: Data(contentsOf: directory.appendingPathComponent("\(name).recognized.json"))
            )
            let expected = try JSONDecoder().decode(
                Expected.self, from: Data(contentsOf: directory.appendingPathComponent("\(name).expected.json"))
            )
            let draft = ReceiptParser().parse(recognized)
            XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits).sorted(), expected.itemTotals.sorted(), "items of \(name)")
            if let quantities = expected.quantities {
                XCTAssertEqual(
                    zip(draft.items.map(\.lineTotal.minorUnits), draft.items.map(\.quantity)).sorted { $0.0 < $1.0 }.map(\.1),
                    zip(expected.itemTotals, quantities).sorted { $0.0 < $1.0 }.map(\.1),
                    "quantities of \(name)"
                )
            }
            XCTAssertEqual(draft.adjustments.map(\.amount.minorUnits).sorted(), (expected.adjustments ?? []).sorted(), "adjustments of \(name)")
            XCTAssertEqual(draft.subtotal?.minorUnits, expected.subtotal, "subtotal of \(name)")
            XCTAssertEqual(draft.tax?.minorUnits ?? 0, expected.tax ?? 0, "tax of \(name)")
            XCTAssertEqual(draft.tip?.minorUnits ?? 0, expected.tip ?? 0, "tip of \(name)")
            XCTAssertEqual(draft.total?.minorUnits, expected.total, "total of \(name)")
        }
    }
}

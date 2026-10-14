import EsplitealoCore
import XCTest
@testable import ScannerLabKit

final class ScanLabJSONExportTests: XCTestCase {
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Receipts", isDirectory: true)

    func testRecognizedTextExportRoundTrip() throws {
        let recognized = try loadRecognized(named: "english-diner")
        let data = try ScanLabJSONExport.encodeRecognizedText(recognized)
        let decoded = try JSONDecoder().decode(RecognizedText.self, from: data)
        XCTAssertEqual(decoded.lines.count, recognized.lines.count)
        XCTAssertEqual(decoded.imageSize.width, recognized.imageSize.width)
    }

    func testFullResultExportContainsDraftTotals() throws {
        let recognized = try loadRecognized(named: "english-diner")
        let draft = ReceiptParser().parse(recognized)
        let result = ReceiptScanResult(recognizedText: recognized, draft: draft)
        let data = try ScanLabJSONExport.encodeFullResult(result, ocrDurationMilliseconds: 99)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(object?["recognizedText"])
        let draftObject = object?["draft"] as? [String: Any]
        XCTAssertEqual(draftObject?["totalMinorUnits"] as? Int, 2430)
        XCTAssertEqual(object?["ocrDurationMilliseconds"] as? Int, 99)
    }

    private func loadRecognized(named name: String) throws -> RecognizedText {
        let url = fixturesURL.appendingPathComponent("\(name).recognized.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RecognizedText.self, from: data)
    }
}

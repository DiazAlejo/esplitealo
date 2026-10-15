import XCTest
@testable import EsplitealoCore
@testable import OCRBenchmarkKit

final class CordBenchmarkScopeTests: XCTestCase {
    func testIndonesianCommaThousandsOutOfScope() {
        let json = """
        {"menu": {"nm": "CINNAMON SUGAR", "price": "17,000"}, "total": {"total_price": "17,000"}}
        """
        let truth = try! CordGroundTruthParser.parse(id: "x", data: Data(json.utf8))
        XCTAssertFalse(CordBenchmarkScope.isInProductScope(groundTruthJSON: json, groundTruth: truth))
    }

    func testLargeIntegerPricesOutOfScope() {
        let json = """
        {"menu": [{"nm": "PROMO", "price": "17500"}], "total": {"total_price": "91000"}}
        """
        let truth = try! CordGroundTruthParser.parse(id: "x", data: Data(json.utf8))
        XCTAssertFalse(CordBenchmarkScope.isInProductScope(groundTruthJSON: json, groundTruth: truth))
    }

    func testSmallDecimalLikePricesInScope() {
        let json = """
        {"menu": [{"nm": "Coffee", "price": "4.50"}], "total": {"total_price": "9.99"}}
        """
        let truth = try! CordGroundTruthParser.parse(id: "x", data: Data(json.utf8))
        XCTAssertTrue(CordBenchmarkScope.isInProductScope(groundTruthJSON: json, groundTruth: truth))
    }
}

final class CordRecallDiagnosisTests: XCTestCase {
    func testEmptyGroundTruthInflatesRecall() {
        let scorer = ReceiptBenchmarkScorer()
        let draft = ReceiptDraft(
            items: [DraftItem(name: "Orphan", quantity: 1, lineTotal: DraftAmount(minorUnits: 999))],
            total: DraftAmount(minorUnits: 999)
        )
        let truth = ReceiptGroundTruth(id: "empty-gt", items: [])
        let score = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(score.itemRecall, 1.0, accuracy: 0.001)
    }
}

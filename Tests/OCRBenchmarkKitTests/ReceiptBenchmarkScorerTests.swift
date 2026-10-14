import XCTest
@testable import EsplitealoCore
@testable import OCRBenchmarkKit

final class ReceiptBenchmarkScorerTests: XCTestCase {
    private let scorer = ReceiptBenchmarkScorer()

    func testPerfectReceiptScoresOne() throws {
        let truth = ReceiptGroundTruth(
            id: "perfect",
            items: [
                GroundTruthItem(name: "Coffee", quantity: 1, lineTotalMinor: 350),
                GroundTruthItem(name: "Toast", quantity: 2, lineTotalMinor: 450),
            ],
            subtotalMinor: 800,
            taxMinor: 64,
            totalMinor: 864,
            expectsReconciles: true
        )
        let draft = ReceiptDraft(
            items: [
                DraftItem(name: "Coffee", quantity: 1, lineTotal: DraftAmount(minorUnits: 350)),
                DraftItem(name: "Toast", quantity: 2, lineTotal: DraftAmount(minorUnits: 450)),
            ],
            subtotal: DraftAmount(minorUnits: 800),
            tax: DraftAmount(minorUnits: 64),
            total: DraftAmount(minorUnits: 864),
            reconciles: true
        )
        let result = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(result.itemRecall, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.itemPrecision, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.itemDescriptionAccuracy, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.quantityAccuracy, 1.0, accuracy: 0.001)
        XCTAssertTrue(result.subtotalCorrect)
        XCTAssertTrue(result.taxCorrect)
        XCTAssertTrue(result.totalCorrect)
        XCTAssertTrue(result.reconciliationAgrees)
        XCTAssertTrue(result.failureReasons.isEmpty)
    }

    func testMissedItemLowersRecallNotPrecision() {
        let truth = ReceiptGroundTruth(
            id: "miss-one",
            items: [
                GroundTruthItem(name: "A", quantity: 1, lineTotalMinor: 100),
                GroundTruthItem(name: "B", quantity: 1, lineTotalMinor: 200),
            ],
            subtotalMinor: 300,
            totalMinor: 300,
            expectsReconciles: true
        )
        let draft = ReceiptDraft(
            items: [DraftItem(name: "A", quantity: 1, lineTotal: DraftAmount(minorUnits: 100))],
            subtotal: DraftAmount(minorUnits: 100),
            total: DraftAmount(minorUnits: 100),
            reconciles: false
        )
        let result = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(result.itemRecall, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.itemPrecision, 1.0, accuracy: 0.001)
        XCTAssertTrue(result.failureReasons.contains(.missedItems))
    }

    func testWrongPriceCountsAsMissedForRecall() {
        let truth = ReceiptGroundTruth(
            id: "wrong-price",
            items: [GroundTruthItem(name: "Burger", quantity: 1, lineTotalMinor: 1200)],
            totalMinor: 1200,
            expectsReconciles: true
        )
        let draft = ReceiptDraft(
            items: [DraftItem(name: "Burger", quantity: 1, lineTotal: DraftAmount(minorUnits: 1100))],
            total: DraftAmount(minorUnits: 1100),
            reconciles: true
        )
        let result = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(result.itemRecall, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.itemPrecision, 0.0, accuracy: 0.001)
        XCTAssertTrue(result.failureReasons.contains(.wrongItemPrices))
    }

    func testDuplicateLineTotalsMultiset() {
        let truth = ReceiptGroundTruth(
            id: "dup",
            items: [
                GroundTruthItem(name: "Taco", quantity: 1, lineTotalMinor: 400),
                GroundTruthItem(name: "Taco", quantity: 1, lineTotalMinor: 400),
            ],
            totalMinor: 800,
            expectsReconciles: true
        )
        let draft = ReceiptDraft(
            items: [
                DraftItem(name: "Taco", quantity: 1, lineTotal: DraftAmount(minorUnits: 400)),
                DraftItem(name: "Taco", quantity: 1, lineTotal: DraftAmount(minorUnits: 400)),
            ],
            total: DraftAmount(minorUnits: 800),
            reconciles: true
        )
        let result = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(result.itemRecall, 1.0, accuracy: 0.001)
    }

    func testDescriptionAccuracyNeedsSimilarity() {
        let truth = ReceiptGroundTruth(
            id: "desc",
            items: [GroundTruthItem(name: "Margherita Pizza", quantity: 1, lineTotalMinor: 2500)],
            totalMinor: 2500,
            expectsReconciles: true
        )
        let draft = ReceiptDraft(
            items: [DraftItem(name: "Margarita Pizza", quantity: 1, lineTotal: DraftAmount(minorUnits: 2500))],
            total: DraftAmount(minorUnits: 2500),
            reconciles: true
        )
        let result = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(result.itemRecall, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(result.itemDescriptionAccuracy, 0.9)
    }

    func testQuantityMismatchFlag() {
        let truth = ReceiptGroundTruth(
            id: "qty",
            items: [GroundTruthItem(name: "Beer", quantity: 2, lineTotalMinor: 1400)],
            totalMinor: 1400,
            expectsReconciles: true
        )
        let draft = ReceiptDraft(
            items: [DraftItem(name: "Beer", quantity: 1, lineTotal: DraftAmount(minorUnits: 1400))],
            total: DraftAmount(minorUnits: 1400),
            reconciles: true
        )
        let result = scorer.score(draft: draft, groundTruth: truth)
        XCTAssertEqual(result.itemRecall, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.quantityAccuracy, 0.0, accuracy: 0.001)
        XCTAssertTrue(result.failureReasons.contains(.wrongQuantities))
    }

    func testAggregateAveragesReceipts() {
        let a = ReceiptPerReceiptScore(
            receiptID: "a",
            itemRecall: 1.0,
            itemPrecision: 1.0,
            itemDescriptionAccuracy: 1.0,
            quantityAccuracy: 1.0,
            subtotalCorrect: true,
            taxCorrect: true,
            totalCorrect: true,
            reconciliationAgrees: true,
            failureReasons: []
        )
        let b = ReceiptPerReceiptScore(
            receiptID: "b",
            itemRecall: 0.5,
            itemPrecision: 0.5,
            itemDescriptionAccuracy: 0.5,
            quantityAccuracy: 0.5,
            subtotalCorrect: false,
            taxCorrect: true,
            totalCorrect: false,
            reconciliationAgrees: false,
            failureReasons: [.missedItems]
        )
        let agg = ReceiptBenchmarkScorer.aggregate([a, b])
        XCTAssertEqual(agg.itemRecall, 0.75, accuracy: 0.001)
        XCTAssertEqual(agg.subtotalIdentificationRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(agg.reconciliationAgreementRate, 0.5, accuracy: 0.001)
    }
}

final class BenchmarkReportComparisonTests: XCTestCase {
    func testCompareReportsStableDeltas() throws {
        let baseline = BenchmarkReport(
            schemaVersion: 1,
            runID: "base",
            timestamp: "2026-01-01T00:00:00Z",
            datasetName: "synthetic",
            config: BenchmarkRunConfig(scannerMode: "accurate", receiptLimit: nil),
            aggregate: BenchmarkAggregateMetrics(
                receiptCount: 2,
                itemRecall: 0.8,
                itemPrecision: 0.9,
                itemDescriptionAccuracy: 0.75,
                quantityAccuracy: 0.95,
                subtotalIdentificationRate: 1.0,
                taxIdentificationRate: 0.5,
                totalIdentificationRate: 1.0,
                reconciliationAgreementRate: 0.5
            ),
            receipts: []
        )
        let after = BenchmarkReport(
            schemaVersion: 1,
            runID: "after",
            timestamp: "2026-01-02T00:00:00Z",
            datasetName: "synthetic",
            config: baseline.config,
            aggregate: BenchmarkAggregateMetrics(
                receiptCount: 2,
                itemRecall: 0.9,
                itemPrecision: 0.9,
                itemDescriptionAccuracy: 0.8,
                quantityAccuracy: 0.95,
                subtotalIdentificationRate: 1.0,
                taxIdentificationRate: 1.0,
                totalIdentificationRate: 1.0,
                reconciliationAgreementRate: 1.0
            ),
            receipts: []
        )
        let delta = BenchmarkReportComparison.compare(baseline: baseline, candidate: after)
        XCTAssertEqual(delta.itemRecallDelta, 0.1, accuracy: 0.001)
        XCTAssertEqual(delta.taxIdentificationRateDelta, 0.5, accuracy: 0.001)
        let data = try JSONEncoder.benchmarkEncoder.encode(delta)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let recallDelta = json?["itemRecallDelta"] as? Double
        XCTAssertEqual(recallDelta ?? 0, 0.1, accuracy: 0.0001)
    }
}

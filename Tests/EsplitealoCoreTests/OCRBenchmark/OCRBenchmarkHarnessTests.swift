import XCTest
@testable import EsplitealoCore

final class OCRBenchmarkHarnessTests: XCTestCase {
    func testParserHarnessScoresFixtureReceipt() throws {
        let url = try fixtureURL(named: "pr-ivu-bistro")
        let recognized = try loadRecognized(from: url)
        let truth = ReceiptGroundTruth(
            id: "pr-ivu-bistro",
            items: [
                GroundTruthItem(name: "Mofongo", quantity: 1, lineTotalMinor: 1450),
                GroundTruthItem(name: "Arroz con gandules", quantity: 1, lineTotalMinor: 800),
            ],
            subtotalMinor: 2250,
            taxMinor: 259,
            totalMinor: 2509,
            expectsReconciles: true
        )
        let report = OCRBenchmarkHarness.evaluateParser(
            cases: [(recognized: recognized, groundTruth: truth)],
            datasetName: "fixtures"
        )
        XCTAssertEqual(report.aggregate.receiptCount, 1)
        XCTAssertEqual(report.aggregate.itemRecall, 1.0, accuracy: 0.001)
        XCTAssertTrue(report.receipts[0].failureReasons.isEmpty)
    }

    func testSyntheticGeneratorGroundTruthReconciles() throws {
        #if canImport(AppKit)
        let sample = try XCTUnwrap(SyntheticReceiptGenerator.sample(style: .restaurantPR, variant: .clean, seed: 7))
        let draft = ReceiptParser().parse(
            RecognizedTextTestBuilder.fromRowTexts(sample.renderedRowTexts)
        )
        let scorer = ReceiptBenchmarkScorer()
        let score = scorer.score(draft: draft, groundTruth: sample.groundTruth)
        XCTAssertEqual(score.itemRecall, 1.0, accuracy: 0.001)
        XCTAssertTrue(score.reconciliationAgrees)
        #else
        throw XCTSkip("Synthetic generator requires AppKit")
        #endif
    }

    private func fixtureURL(named: String) throws -> URL {
        let path = #filePath
        let root = URL(fileURLWithPath: path)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Receipts/\(named).recognized.json")
        return root
    }

    private func loadRecognized(from url: URL) throws -> RecognizedText {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RecognizedText.self, from: data)
    }
}

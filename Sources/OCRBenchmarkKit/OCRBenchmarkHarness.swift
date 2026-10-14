import CoreGraphics
import EsplitealoCore
import EsplitealoScanning
import Foundation

public enum OCRBenchmarkHarness {
    public static func evaluateParser(
        cases: [(recognized: RecognizedText, groundTruth: ReceiptGroundTruth)],
        datasetName: String,
        config: BenchmarkRunConfig = BenchmarkRunConfig(scannerMode: "parser-only"),
        parser: ReceiptParser = ReceiptParser(),
        runID: String = UUID().uuidString
    ) -> BenchmarkReport {
        let scorer = ReceiptBenchmarkScorer()
        let receipts = cases.map { entry in
            let draft = parser.parse(entry.recognized)
            return scorer.score(draft: draft, groundTruth: entry.groundTruth)
        }
        let aggregate = ReceiptBenchmarkScorer.aggregate(receipts)
        return BenchmarkReport(
            runID: runID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            datasetName: datasetName,
            config: config,
            aggregate: aggregate,
            receipts: receipts
        )
    }

    #if canImport(AppKit)
    public static func evaluateVision(
        samples: [(image: CGImage, groundTruth: ReceiptGroundTruth)],
        datasetName: String,
        config: BenchmarkRunConfig = BenchmarkRunConfig(scannerMode: "accurate"),
        pipeline: ReceiptScanPipeline = ReceiptScanPipeline(),
        runID: String = UUID().uuidString
    ) async throws -> BenchmarkReport {
        let scorer = ReceiptBenchmarkScorer()
        var receipts: [ReceiptPerReceiptScore] = []
        for sample in samples {
            let result = try await pipeline.scan(image: sample.image, orientation: .up)
            receipts.append(scorer.score(draft: result.draft, groundTruth: sample.groundTruth))
        }
        let aggregate = ReceiptBenchmarkScorer.aggregate(receipts)
        return BenchmarkReport(
            runID: runID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            datasetName: datasetName,
            config: config,
            aggregate: aggregate,
            receipts: receipts
        )
    }
    #endif
}

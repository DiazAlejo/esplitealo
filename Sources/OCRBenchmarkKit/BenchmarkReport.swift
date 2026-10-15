import EsplitealoCore
import Foundation

public struct BenchmarkRunConfig: Codable, Equatable, Sendable {
    public var scannerMode: String
    public var receiptLimit: Int?
    public var datasetPath: String?

    public init(scannerMode: String = "accurate", receiptLimit: Int? = nil, datasetPath: String? = nil) {
        self.scannerMode = scannerMode
        self.receiptLimit = receiptLimit
        self.datasetPath = datasetPath
    }
}

public struct BenchmarkScopeSplit: Codable, Equatable, Sendable {
    public var inProductScope: BenchmarkAggregateMetrics
    public var outOfProductScope: BenchmarkAggregateMetrics
}

public struct BenchmarkReport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var runID: String
    public var timestamp: String
    public var datasetName: String
    public var config: BenchmarkRunConfig
    public var aggregate: BenchmarkAggregateMetrics
    public var receipts: [ReceiptPerReceiptScore]
    public var scopeSplit: BenchmarkScopeSplit?

    public init(
        schemaVersion: Int = 1,
        runID: String,
        timestamp: String,
        datasetName: String,
        config: BenchmarkRunConfig,
        aggregate: BenchmarkAggregateMetrics,
        receipts: [ReceiptPerReceiptScore],
        scopeSplit: BenchmarkScopeSplit? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.timestamp = timestamp
        self.datasetName = datasetName
        self.config = config
        self.aggregate = aggregate
        self.receipts = receipts
        self.scopeSplit = scopeSplit
    }

    public func jsonData() throws -> Data {
        try JSONEncoder.benchmarkEncoder.encode(self)
    }
}

public struct BenchmarkReportDelta: Codable, Equatable, Sendable {
    public var baselineRunID: String
    public var candidateRunID: String
    public var itemRecallDelta: Double
    public var itemPrecisionDelta: Double
    public var itemDescriptionAccuracyDelta: Double
    public var quantityAccuracyDelta: Double
    public var subtotalIdentificationRateDelta: Double
    public var taxIdentificationRateDelta: Double
    public var totalIdentificationRateDelta: Double
    public var reconciliationAgreementRateDelta: Double
}

public enum BenchmarkReportComparison {
    public static func compare(baseline: BenchmarkReport, candidate: BenchmarkReport) -> BenchmarkReportDelta {
        func delta(_ a: Double, _ b: Double) -> Double { b - a }
        return BenchmarkReportDelta(
            baselineRunID: baseline.runID,
            candidateRunID: candidate.runID,
            itemRecallDelta: delta(baseline.aggregate.itemRecall, candidate.aggregate.itemRecall),
            itemPrecisionDelta: delta(baseline.aggregate.itemPrecision, candidate.aggregate.itemPrecision),
            itemDescriptionAccuracyDelta: delta(
                baseline.aggregate.itemDescriptionAccuracy,
                candidate.aggregate.itemDescriptionAccuracy
            ),
            quantityAccuracyDelta: delta(baseline.aggregate.quantityAccuracy, candidate.aggregate.quantityAccuracy),
            subtotalIdentificationRateDelta: delta(
                baseline.aggregate.subtotalIdentificationRate,
                candidate.aggregate.subtotalIdentificationRate
            ),
            taxIdentificationRateDelta: delta(
                baseline.aggregate.taxIdentificationRate,
                candidate.aggregate.taxIdentificationRate
            ),
            totalIdentificationRateDelta: delta(
                baseline.aggregate.totalIdentificationRate,
                candidate.aggregate.totalIdentificationRate
            ),
            reconciliationAgreementRateDelta: delta(
                baseline.aggregate.reconciliationAgreementRate,
                candidate.aggregate.reconciliationAgreementRate
            )
        )
    }
}

public extension JSONEncoder {
    static var benchmarkEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var benchmarkDecoder: JSONDecoder {
        JSONDecoder()
    }
}

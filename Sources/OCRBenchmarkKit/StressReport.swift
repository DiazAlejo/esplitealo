import EsplitealoCore
import Foundation

/// Who is to blame for a wrong bill, judged by replaying the parser on perfect OCR text.
public enum StressAttribution: String, Codable, Sendable {
    case exact
    /// The parser is wrong even when the text is read perfectly.
    case parser
    /// The parser is right on perfect text, so the image reading (OCR errors or layout) broke the bill.
    case ocr
    /// The scanner refused the image.
    case scanRejected
}

public struct StressCaseResult: Codable, Equatable, Sendable {
    public var id: String
    public var venue: String
    public var degradation: String
    public var tags: [String]
    public var exact: Bool
    public var amountsExact: Bool
    /// The draft tells the user something may be wrong (does not reconcile, has issues, or marks rows for review).
    public var flagged: Bool
    /// Wrong and not flagged: the failure the user cannot see.
    public var silentWrong: Bool
    public var attribution: StressAttribution
    public var causes: [StressFailureCause]
    public var details: [String]
    public var scanError: String?
    /// Whether the parser alone, on perfect text, gets the bill exactly right.
    public var idealParserExact: Bool?
    /// Printed prices that do not appear in the recognized text (OCR misreads).
    public var ocrAmountsMissing: [String]
    public var itemRecall: Double
    public var itemPrecision: Double
    public var itemDescriptionAccuracy: Double
    public var quantityAccuracy: Double
    public var subtotalCorrect: Bool
    public var taxCorrect: Bool
    public var totalCorrect: Bool
    public var reconciliationAgrees: Bool

    public var primaryCause: StressFailureCause? { causes.first }
}

public struct StressSlice: Codable, Equatable, Sendable {
    public var count: Int
    public var exact: Int
    public var silentWrong: Int
    public var exactRate: Double { count == 0 ? 0 : Double(exact) / Double(count) }

    init(_ results: [StressCaseResult]) {
        count = results.count
        exact = results.filter(\.exact).count
        silentWrong = results.filter(\.silentWrong).count
    }
}

public struct StressHeadline: Codable, Equatable, Sendable {
    public var receiptCount: Int
    /// Parsed bill equals the ground truth to the cent (items, quantities, adjustments, subtotal, tax, tip, total).
    public var billExactness: Double
    /// Same, ignoring item quantities.
    public var amountsExactness: Double
    /// Wrong bills that the draft did not flag, over all receipts.
    public var silentWrongRate: Double
    /// Of the wrong bills, the share the draft flagged for review.
    public var flaggedWhenWrongRate: Double
    /// Exactness of the parser alone on perfect text.
    public var idealParserExactness: Double?
    public var itemRecall: Double
    public var itemPrecision: Double
    public var itemDescriptionAccuracy: Double
    public var quantityAccuracy: Double
    public var subtotalIdentificationRate: Double
    public var taxIdentificationRate: Double
    public var totalIdentificationRate: Double
}

public struct StressReport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var runID: String
    public var timestamp: String
    /// `vision` (real scanner on rendered images) or `ideal-text` (parser on perfect OCR text).
    public var mode: String
    public var seed: UInt64
    public var headline: StressHeadline
    public var byDegradation: [String: StressSlice]
    public var byVenue: [String: StressSlice]
    public var byFeature: [String: StressSlice]
    /// Receipts that have each cause among their mismatches.
    public var byCause: [String: Int]
    /// Receipts whose first (most upstream) mismatch is each cause.
    public var byPrimaryCause: [String: Int]
    public var byAttribution: [String: Int]
    public var cases: [StressCaseResult]

    public func jsonData() throws -> Data {
        try JSONEncoder.benchmarkEncoder.encode(self)
    }
}

public enum StressBenchmark {
    /// Scores one receipt. `recognized` is nil when the scanner refused the image.
    public static func evaluate(
        receipt: StressReceipt,
        recognized: RecognizedText?,
        scanError: String? = nil,
        parser: ReceiptParser = ReceiptParser()
    ) -> (result: StressCaseResult, draft: ReceiptDraft?) {
        let ideal = parser.parse(StressRecognizedTextBuilder.build(from: receipt))
        let idealExact = BillExactness.compare(draft: ideal, truth: receipt.truth).exact

        guard let recognized else {
            let result = StressCaseResult(
                id: receipt.id,
                venue: receipt.venue.rawValue,
                degradation: receipt.degradation.rawValue,
                tags: receipt.tags,
                exact: false,
                amountsExact: false,
                flagged: true,
                silentWrong: false,
                attribution: .scanRejected,
                causes: [.scanRejected],
                details: [scanError ?? "scan failed"],
                scanError: scanError,
                idealParserExact: idealExact,
                ocrAmountsMissing: [],
                itemRecall: 0,
                itemPrecision: 0,
                itemDescriptionAccuracy: 0,
                quantityAccuracy: 0,
                subtotalCorrect: false,
                taxCorrect: false,
                totalCorrect: false,
                reconciliationAgrees: false
            )
            return (result, nil)
        }

        let draft = parser.parse(recognized)
        let comparison = BillExactness.compare(draft: draft, truth: receipt.truth)
        let flagged = BillExactness.isFlagged(draft)
        let score = ReceiptBenchmarkScorer().score(draft: draft, groundTruth: receipt.groundTruth)
        let attribution: StressAttribution = comparison.exact ? .exact : (idealExact ? .ocr : .parser)
        let result = StressCaseResult(
            id: receipt.id,
            venue: receipt.venue.rawValue,
            degradation: receipt.degradation.rawValue,
            tags: receipt.tags,
            exact: comparison.exact,
            amountsExact: comparison.amountsExact,
            flagged: flagged,
            silentWrong: !comparison.exact && !flagged,
            attribution: attribution,
            causes: comparison.causes,
            details: comparison.details,
            scanError: nil,
            idealParserExact: idealExact,
            ocrAmountsMissing: recognized.engine == "stress-ideal" ? [] : missingAmounts(receipt: receipt, recognized: recognized),
            itemRecall: score.itemRecall,
            itemPrecision: score.itemPrecision,
            itemDescriptionAccuracy: score.itemDescriptionAccuracy,
            quantityAccuracy: score.quantityAccuracy,
            subtotalCorrect: score.subtotalCorrect,
            taxCorrect: score.taxCorrect,
            totalCorrect: score.totalCorrect,
            reconciliationAgrees: score.reconciliationAgrees
        )
        return (result, draft)
    }

    /// Parser on perfect OCR text for the whole corpus: no image, no Vision, deterministic.
    public static func runIdealText(
        receipts: [StressReceipt],
        seed: UInt64,
        parser: ReceiptParser = ReceiptParser()
    ) -> StressReport {
        let results = receipts.map {
            evaluate(receipt: $0, recognized: StressRecognizedTextBuilder.build(from: $0), parser: parser).result
        }
        return report(results: results, mode: "ideal-text", seed: seed)
    }

    public static func report(results: [StressCaseResult], mode: String, seed: UInt64, runID: String = UUID().uuidString) -> StressReport {
        let count = Double(max(1, results.count))
        let wrong = results.filter { !$0.exact }
        func average(_ pick: (StressCaseResult) -> Double) -> Double {
            results.reduce(0) { $0 + pick($1) } / count
        }
        func rate(_ pick: (StressCaseResult) -> Bool) -> Double {
            Double(results.filter(pick).count) / count
        }
        let idealKnown = results.compactMap(\.idealParserExact)
        let headline = StressHeadline(
            receiptCount: results.count,
            billExactness: rate(\.exact),
            amountsExactness: rate(\.amountsExact),
            silentWrongRate: rate(\.silentWrong),
            flaggedWhenWrongRate: wrong.isEmpty ? 1 : Double(wrong.filter(\.flagged).count) / Double(wrong.count),
            idealParserExactness: idealKnown.isEmpty ? nil : Double(idealKnown.filter { $0 }.count) / Double(idealKnown.count),
            itemRecall: average(\.itemRecall),
            itemPrecision: average(\.itemPrecision),
            itemDescriptionAccuracy: average(\.itemDescriptionAccuracy),
            quantityAccuracy: average(\.quantityAccuracy),
            subtotalIdentificationRate: rate(\.subtotalCorrect),
            taxIdentificationRate: rate(\.taxCorrect),
            totalIdentificationRate: rate(\.totalCorrect)
        )

        func slices(_ keys: (StressCaseResult) -> [String]) -> [String: StressSlice] {
            var grouped: [String: [StressCaseResult]] = [:]
            for result in results {
                for key in keys(result) { grouped[key, default: []].append(result) }
            }
            return grouped.mapValues(StressSlice.init)
        }
        func prefixed(_ prefix: String) -> (StressCaseResult) -> [String] {
            { result in
                result.tags.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
            }
        }

        var byCause: [String: Int] = [:]
        var byPrimaryCause: [String: Int] = [:]
        var byAttribution: [String: Int] = [:]
        for result in results {
            byAttribution[result.attribution.rawValue, default: 0] += 1
            for cause in Set(result.causes) { byCause[cause.rawValue, default: 0] += 1 }
            if let primary = result.primaryCause { byPrimaryCause[primary.rawValue, default: 0] += 1 }
        }

        return StressReport(
            schemaVersion: 1,
            runID: runID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            mode: mode,
            seed: seed,
            headline: headline,
            byDegradation: slices(prefixed("degradation:")),
            byVenue: slices(prefixed("venue:")),
            byFeature: slices(prefixed("feature:")),
            byCause: byCause,
            byPrimaryCause: byPrimaryCause,
            byAttribution: byAttribution,
            cases: results
        )
    }

    // MARK: OCR amount check

    private static let amountPattern = try? NSRegularExpression(pattern: #"\d+[.,]\d{2}"#)

    /// Prices in `text`, normalized to `12.34`.
    static func amounts(in text: String) -> [String] {
        guard let amountPattern else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return amountPattern.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]).replacingOccurrences(of: ",", with: ".") }
        }
    }

    /// Printed item, adjustment, subtotal, tax, tip and total prices that the recognized text does not contain.
    static func missingAmounts(receipt: StressReceipt, recognized: RecognizedText) -> [String] {
        let priced: Set<StressRow.Role> = [.item, .addOn, .subtotal, .discount, .tax, .tip, .total]
        var printed = receipt.rows.filter { priced.contains($0.role) }.compactMap(\.right).flatMap(amounts(in:))
        var seen = recognized.lines.map(\.text).flatMap(amounts(in:))
        printed.sort()
        seen.sort()
        var missing: [String] = []
        for amount in printed {
            if let index = seen.firstIndex(of: amount) {
                seen.remove(at: index)
            } else {
                missing.append(amount)
            }
        }
        return missing
    }
}

/// A short Markdown summary of a report, for the CI job summary and `docs/OCR_BENCHMARK.md`.
public enum StressReportMarkdown {
    public static func render(_ report: StressReport) -> String {
        let h = report.headline
        func pct(_ value: Double) -> String { String(format: "%.1f%%", value * 100) }
        var lines: [String] = []
        lines.append("### Receipt stress test (\(report.mode), seed \(report.seed), n=\(h.receiptCount))")
        lines.append("")
        lines.append("| Metric | Value |")
        lines.append("| --- | ---: |")
        lines.append("| **Bill exactness (to the cent)** | **\(pct(h.billExactness))** |")
        lines.append("| Amounts exact (ignoring quantities) | \(pct(h.amountsExactness)) |")
        lines.append("| Silent wrong (wrong and not flagged) | \(pct(h.silentWrongRate)) |")
        lines.append("| Wrong bills that were flagged | \(pct(h.flaggedWhenWrongRate)) |")
        if let ideal = h.idealParserExactness {
            lines.append("| Parser alone on perfect text | \(pct(ideal)) |")
        }
        lines.append("| Item recall / precision | \(pct(h.itemRecall)) / \(pct(h.itemPrecision)) |")
        lines.append("| Item description / quantity accuracy | \(pct(h.itemDescriptionAccuracy)) / \(pct(h.quantityAccuracy)) |")
        lines.append("| Subtotal / tax / total identified | \(pct(h.subtotalIdentificationRate)) / \(pct(h.taxIdentificationRate)) / \(pct(h.totalIdentificationRate)) |")
        lines.append("")
        lines.append(table("By degradation", report.byDegradation))
        lines.append(table("By venue", report.byVenue))
        lines.append(table("By layout feature", report.byFeature))
        lines.append("#### Failures by cause (receipts)")
        lines.append("")
        lines.append("| Cause | Any mismatch | First mismatch |")
        lines.append("| --- | ---: | ---: |")
        for cause in report.byCause.sorted(by: { ($1.value, $0.key) < ($0.value, $1.key) }) {
            lines.append("| \(cause.key) | \(cause.value) | \(report.byPrimaryCause[cause.key] ?? 0) |")
        }
        lines.append("")
        lines.append("#### Who is to blame")
        lines.append("")
        for (key, value) in report.byAttribution.sorted(by: { $0.key < $1.key }) {
            lines.append("- \(key): \(value)")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func table(_ title: String, _ slices: [String: StressSlice]) -> String {
        var lines = ["#### \(title)", "", "| Group | n | Exact | Silent wrong |", "| --- | ---: | ---: | ---: |"]
        for (key, slice) in slices.sorted(by: { ($0.value.exactRate, $0.key) < ($1.value.exactRate, $1.key) }) {
            lines.append("| \(key) | \(slice.count) | \(String(format: "%.0f%%", slice.exactRate * 100)) | \(slice.silentWrong) |")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

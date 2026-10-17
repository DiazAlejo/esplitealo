import XCTest
@testable import EsplitealoCore
@testable import OCRBenchmarkKit

/// The parser on perfect OCR text for the generated Puerto Rico receipts. No image and no Vision, so it runs in the
/// required CI job: a parser regression on any layout feature fails here before the nightly Vision stress run sees it.
final class StressParserIdealTextTests: XCTestCase {
    private static let receipts = StressReceiptGenerator.corpus(count: 112)
    private static let report = StressBenchmark.runIdealText(receipts: receipts, seed: StressReceiptGenerator.defaultSeed)
    private var receipts: [StressReceipt] { Self.receipts }
    private var report: StressReport { Self.report }

    override func tearDown() {
        // `ESPLITEALO_STRESS_DUMP=/path/dir` writes the report and every failing receipt for inspection.
        if let directory = ProcessInfo.processInfo.environment["ESPLITEALO_STRESS_DUMP"] {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try? StressReportMarkdown.render(report).write(toFile: directory + "/ideal-text.md", atomically: true, encoding: .utf8)
            try? report.jsonData().write(to: URL(fileURLWithPath: directory + "/ideal-text.json"))
            var failures = ""
            for (receipt, result) in zip(receipts, report.cases) where !result.exact {
                failures += "=== \(receipt.id) \(receipt.features.map(\.rawValue).sorted()) causes=\(result.causes.map(\.rawValue)) flagged=\(result.flagged)\n"
                failures += receipt.plainRows.joined(separator: "\n") + "\n--- " + result.details.joined(separator: "\n--- ") + "\n\n"
            }
            try? failures.write(toFile: directory + "/ideal-text-failures.txt", atomically: true, encoding: .utf8)
        }
        super.tearDown()
    }

    func testBillsAreNeverSilentlyWrong() {
        let silent = report.cases.filter(\.silentWrong)
        XCTAssertTrue(silent.isEmpty, "\(silent.count) silent failures: \(silent.map(\.id).prefix(12))")
    }

    func testBillsAreExactOnPerfectText() {
        let failing = report.cases.filter { !$0.exact }
        XCTAssertTrue(
            failing.isEmpty,
            "\(failing.count) of \(report.cases.count) bills are not exact. By cause: \(report.byCause). First: \(failing.prefix(5).map { "\($0.id) \($0.details)" })"
        )
    }
}

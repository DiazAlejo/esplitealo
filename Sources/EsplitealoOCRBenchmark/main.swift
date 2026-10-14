import CoreGraphics
import EsplitealoCore
import Foundation
import ImageIO

@main
struct EsplitealoOCRBenchmarkCLI {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func run() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(1)
        }
        args.removeFirst()

        switch command {
        case "synthetic":
            let limit = intFlag("--limit", in: args)
            let output = stringFlag("--output", in: args) ?? defaultOutputPath(name: "synthetic")
            let report = try await runSynthetic(limit: limit, output: output)
            printSummary(report)
        case "cord":
            let cache = stringFlag("--cache", in: args)
                ?? "\(NSHomeDirectory())/Documents/firstmate/data/esplitealo-ocr-benchmark/cord-cache"
            let limit = intFlag("--limit", in: args)
            let output = stringFlag("--output", in: args) ?? defaultOutputPath(name: "cord")
            let report = try await runCord(cacheDirectory: URL(fileURLWithPath: cache), limit: limit, output: output)
            printSummary(report)
        case "compare":
            guard args.count >= 2 else {
                fputs("compare requires <baseline.json> <candidate.json>\n", stderr)
                exit(1)
            }
            let baseline = try loadReport(URL(fileURLWithPath: args[0]))
            let candidate = try loadReport(URL(fileURLWithPath: args[1]))
            let delta = BenchmarkReportComparison.compare(baseline: baseline, candidate: candidate)
            let data = try JSONEncoder.benchmarkEncoder.encode(delta)
            print(String(data: data, encoding: .utf8) ?? "")
        case "help", "--help", "-h":
            printUsage()
        default:
            fputs("unknown command: \(command)\n", stderr)
            printUsage()
            exit(1)
        }
    }

    private static func runSynthetic(limit: Int?, output: String) async throws -> BenchmarkReport {
        #if canImport(AppKit)
        var samples = SyntheticReceiptGenerator.allSamples(seed: 42)
        if let limit { samples = Array(samples.prefix(limit)) }
        let pairs = samples.map { ($0.image(), $0.groundTruth) }
        let report = try await OCRBenchmarkHarness.evaluateVision(
            samples: pairs,
            datasetName: "synthetic-pr",
            config: BenchmarkRunConfig(scannerMode: "accurate", receiptLimit: limit)
        )
        try writeReport(report, to: URL(fileURLWithPath: output))
        return report
        #else
        throw BenchmarkCLIError.appKitRequired
        #endif
    }

    private static func runCord(cacheDirectory: URL, limit: Int?, output: String) async throws -> BenchmarkReport {
        #if canImport(AppKit)
        let records = try CordDatasetLoader.load(from: cacheDirectory, limit: limit)
        if records.isEmpty {
            throw BenchmarkCLIError.cordCacheMissing(cacheDirectory.path)
        }
        let pairs = try records.map { record -> (CGImage, ReceiptGroundTruth) in
            let image = try loadCGImage(record.imageURL)
            return (image, record.groundTruth)
        }
        let report = try await OCRBenchmarkHarness.evaluateVision(
            samples: pairs,
            datasetName: "cord-v2",
            config: BenchmarkRunConfig(
                scannerMode: "accurate",
                receiptLimit: limit,
                datasetPath: cacheDirectory.path
            )
        )
        try writeReport(report, to: URL(fileURLWithPath: output))
        return report
        #else
        throw BenchmarkCLIError.appKitRequired
        #endif
    }

    private static func loadCGImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw BenchmarkCLIError.unreadableImage(url.path)
        }
        return image
    }

    private static func loadReport(_ url: URL) throws -> BenchmarkReport {
        let data = try Data(contentsOf: url)
        return try JSONDecoder.benchmarkDecoder.decode(BenchmarkReport.self, from: data)
    }

    private static func writeReport(_ report: BenchmarkReport, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try report.jsonData().write(to: url)
        fputs("wrote \(url.path)\n", stderr)
    }

    private static func defaultOutputPath(name: String) -> String {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "\(NSHomeDirectory())/Documents/firstmate/data/esplitealo-ocr-benchmark/reports/\(name)-\(stamp).json"
    }

    private static func printSummary(_ report: BenchmarkReport) {
        let agg = report.aggregate
        print(
            """
            dataset=\(report.datasetName) receipts=\(agg.receiptCount)
            itemRecall=\(format(agg.itemRecall)) itemPrecision=\(format(agg.itemPrecision)) \
            itemPriceAccuracy=\(format(agg.itemPriceAccuracy)) descAccuracy=\(format(agg.itemDescriptionAccuracy)) \
            qtyAccuracy=\(format(agg.quantityAccuracy))
            subtotalID=\(format(agg.subtotalIdentificationRate)) taxID=\(format(agg.taxIdentificationRate)) \
            totalID=\(format(agg.totalIdentificationRate)) reconciliation=\(format(agg.reconciliationAgreementRate))
            """
        )
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func intFlag(_ name: String, in args: [String]) -> Int? {
        guard let idx = args.firstIndex(of: name), idx + 1 < args.count else { return nil }
        return Int(args[idx + 1])
    }

    private static func stringFlag(_ name: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: name), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    private static func printUsage() {
        print(
            """
            Esplitealo OCR benchmark (macOS + Vision). Not run in CI.

            swift run EsplitealoOCRBenchmark synthetic [--limit N] [--output path.json]
            swift run EsplitealoOCRBenchmark cord [--cache dir] [--limit N] [--output path.json]
            swift run EsplitealoOCRBenchmark compare baseline.json candidate.json

            CORD cache: Scripts/fetch-cord-benchmark.py (CC-BY 4.0, naver-clova-ix/cord-v2)
            """
        )
    }
}

enum BenchmarkCLIError: Error, CustomStringConvertible {
    case appKitRequired
    case cordCacheMissing(String)
    case unreadableImage(String)

    var description: String {
        switch self {
        case .appKitRequired:
            return "EsplitealoOCRBenchmark requires macOS AppKit"
        case .cordCacheMissing(let path):
            return "CORD cache empty or missing at \(path). Run Scripts/fetch-cord-benchmark.py first."
        case .unreadableImage(let path):
            return "Could not decode image at \(path)"
        }
    }
}

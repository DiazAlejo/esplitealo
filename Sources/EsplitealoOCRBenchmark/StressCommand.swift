import CoreGraphics
import EsplitealoCore
import EsplitealoScanning
import Foundation
import OCRBenchmarkKit

/// `EsplitealoOCRBenchmark stress`: generated Puerto Rico receipts through the real scanner and the parser.
enum StressCommand {
    static func run(args: [String]) async throws {
        let count = intFlag("--count", in: args) ?? 112
        let seed = stringFlag("--seed", in: args).flatMap(UInt64.init) ?? StressReceiptGenerator.defaultSeed
        let mode = stringFlag("--mode", in: args) ?? "vision"
        let output = stringFlag("--output", in: args)
        let markdownPath = stringFlag("--markdown", in: args)
        let failuresDirectory = stringFlag("--failures-dir", in: args)
        let receipts = StressReceiptGenerator.corpus(count: count, seed: seed)

        let report: StressReport
        switch mode {
        case "ideal":
            report = StressBenchmark.runIdealText(receipts: receipts, seed: seed)
        case "vision":
            #if canImport(AppKit)
            report = try await runVision(receipts: receipts, seed: seed, failuresDirectory: failuresDirectory)
            #else
            throw BenchmarkCLIError.appKitRequired
            #endif
        default:
            fputs("unknown --mode \(mode) (vision or ideal)\n", stderr)
            exit(1)
        }

        let markdown = StressReportMarkdown.render(report)
        print(markdown)
        if let output {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try report.jsonData().write(to: url)
            fputs("wrote \(url.path)\n", stderr)
        }
        if let markdownPath {
            try markdown.write(toFile: markdownPath, atomically: true, encoding: .utf8)
        }
    }

    #if canImport(AppKit)
    private static func runVision(receipts: [StressReceipt], seed: UInt64, failuresDirectory: String?) async throws -> StressReport {
        let scanner = ReceiptScanner()
        let parser = ReceiptParser()
        var results: [StressCaseResult] = []
        for (position, receipt) in receipts.enumerated() {
            let image = StressReceiptRenderer.render(receipt)
            var recognized: RecognizedText?
            var scanError: String?
            do {
                recognized = try await scanner.recognize(image: image)
            } catch {
                scanError = "\(error)"
            }
            let (result, draft) = StressBenchmark.evaluate(
                receipt: receipt, recognized: recognized, scanError: scanError, parser: parser
            )
            results.append(result)
            fputs("[\(position + 1)/\(receipts.count)] \(receipt.id) \(result.exact ? "exact" : "FAIL \(result.causes.map(\.rawValue))")\n", stderr)
            if !result.exact, let failuresDirectory {
                try writeFailure(
                    directory: URL(fileURLWithPath: failuresDirectory),
                    receipt: receipt, result: result, image: image, recognized: recognized, draft: draft
                )
            }
        }
        return StressBenchmark.report(results: results, mode: "vision", seed: seed)
    }

    private static func writeFailure(
        directory: URL,
        receipt: StressReceipt,
        result: StressCaseResult,
        image: CGImage,
        recognized: RecognizedText?,
        draft: ReceiptDraft?
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = directory.appendingPathComponent(receipt.id)
        if let jpeg = StressReceiptRenderer.jpegData(image) {
            try jpeg.write(to: base.appendingPathExtension("jpg"))
        }
        let encoder = JSONEncoder.benchmarkEncoder
        try encoder.encode(receipt.truth).write(to: URL(fileURLWithPath: base.path + ".truth.json"))
        if let recognized {
            try encoder.encode(recognized).write(to: URL(fileURLWithPath: base.path + ".recognized.json"))
        }
        if let draft {
            try encoder.encode(draft).write(to: URL(fileURLWithPath: base.path + ".draft.json"))
        }
        var text = "\(receipt.id)\nfeatures: \(receipt.features.map(\.rawValue).sorted())\n"
        text += "attribution: \(result.attribution.rawValue) flagged: \(result.flagged)\n"
        text += "causes: \(result.causes.map(\.rawValue))\n"
        text += result.details.map { "- \($0)" }.joined(separator: "\n") + "\n"
        if !result.ocrAmountsMissing.isEmpty { text += "amounts not read: \(result.ocrAmountsMissing)\n" }
        text += "\n--- printed rows\n" + receipt.plainRows.joined(separator: "\n") + "\n"
        if let recognized {
            text += "\n--- rebuilt rows\n" + ReceiptParser().rebuiltRowDescriptions(from: recognized).joined(separator: "\n") + "\n"
        }
        try text.write(toFile: base.path + ".txt", atomically: true, encoding: .utf8)
    }
    #endif

    private static func intFlag(_ name: String, in args: [String]) -> Int? {
        stringFlag(name, in: args).flatMap(Int.init)
    }

    private static func stringFlag(_ name: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}

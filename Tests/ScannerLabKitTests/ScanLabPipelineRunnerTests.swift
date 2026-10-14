import CoreGraphics
import EsplitealoCore
import XCTest
@testable import ScannerLabKit

private struct FixtureRecognizer: TextRecognizing {
    var text: RecognizedText

    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) async throws -> RecognizedText {
        text
    }
}

final class ScanLabPipelineRunnerTests: XCTestCase {
    private let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Receipts", isDirectory: true)

    func testRunnerUsesInjectedRecognizer() async throws {
        let recognized = try loadRecognized(named: "english-diner")
        let scanner = ReceiptScanner(recognizer: FixtureRecognizer(text: recognized))
        let runner = ScanLabPipelineRunner(pipeline: ReceiptScanPipeline(scanner: scanner))
        let image = try makeSyntheticImage(width: 420, height: 196)
        let outcome = try await runner.run(image: image)
        XCTAssertEqual(outcome.result.draft.items.count, 2)
        XCTAssertGreaterThanOrEqual(outcome.ocrDurationMilliseconds, 0)
    }

    private func loadRecognized(named name: String) throws -> RecognizedText {
        let url = fixturesURL.appendingPathComponent("\(name).recognized.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RecognizedText.self, from: data)
    }

    private func makeSyntheticImage(width: Int, height: Int) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw XCTSkip("Could not create synthetic image")
        }
        return image
    }
}

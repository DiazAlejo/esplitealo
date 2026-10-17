#if canImport(AppKit)
import XCTest
@testable import OCRBenchmarkKit

final class StressReceiptRendererTests: XCTestCase {
    func testEveryDegradationRendersAReadableSizedImage() throws {
        let corpus = StressReceiptGenerator.corpus(count: 56)
        for degradation in StressDegradation.allCases {
            let receipt = try XCTUnwrap(corpus.first { $0.degradation == degradation }, "\(degradation)")
            let image = StressReceiptRenderer.render(receipt)
            XCTAssertGreaterThan(image.width, 1200, "\(receipt.id)")
            XCTAssertGreaterThan(image.height, 400, "\(receipt.id)")
            XCTAssertLessThan(Double(image.height) / Double(image.width), 4, "\(receipt.id) is too tall for a single photo")
            XCTAssertNotNil(StressReceiptRenderer.jpegData(image), "\(receipt.id)")
        }
    }

    func testRenderingIsDeterministic() throws {
        let receipt = StressReceiptGenerator.receipt(index: 52, seed: 2026)
        XCTAssertEqual(receipt.degradation, .photo)
        let first = StressReceiptRenderer.render(receipt)
        let second = StressReceiptRenderer.render(receipt)
        XCTAssertEqual(first.width, second.width)
        XCTAssertEqual(first.height, second.height)
    }

    /// `ESPLITEALO_STRESS_IMAGES=/path/dir` writes one sample image per degradation for a visual check.
    func testWriteSampleImagesWhenAsked() throws {
        guard let directory = ProcessInfo.processInfo.environment["ESPLITEALO_STRESS_IMAGES"] else {
            throw XCTSkip("set ESPLITEALO_STRESS_IMAGES to write sample receipt images")
        }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for receipt in StressReceiptGenerator.corpus(count: 56) where receipt.index < 56 {
            let image = StressReceiptRenderer.render(receipt)
            try XCTUnwrap(StressReceiptRenderer.jpegData(image)).write(to: URL(fileURLWithPath: "\(directory)/\(receipt.id).jpg"))
        }
    }
}
#endif

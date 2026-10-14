import Vision
import XCTest
@testable import EsplitealoCore
@testable import EsplitealoScanning

#if canImport(Vision)
final class ReceiptScannerVisionTests: XCTestCase {
    private let pipeline = ReceiptScanPipeline()

    override func setUp() {
        super.setUp()
        if ProcessInfo.processInfo.environment["ESPLITEALO_SKIP_VISION_INTEGRATION"] != nil {
            continueAfterFailure = false
        }
    }

    private func skipIfVisionIntegrationDisabled() throws {
        #if !canImport(AppKit)
        throw XCTSkip("Synthetic receipt images are rendered with AppKit, which is macOS only")
        #endif
        if ProcessInfo.processInfo.environment["ESPLITEALO_SKIP_VISION_INTEGRATION"] != nil {
            throw XCTSkip("Vision integration disabled for this run")
        }
    }

    func testAccurateModeSupportsSpanishAndEnglish() throws {
        let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision3)
        XCTAssertTrue(languages.contains("es-ES"))
        XCTAssertTrue(languages.contains("en-US"))
    }

    func testPRIvuBistroEndToEnd() async throws {
        try skipIfVisionIntegrationDisabled()
        let image = SyntheticReceiptImages.prIVUBistro()
        let result = try await pipeline.scan(image: image, orientation: .up)
        assertDraft(result.draft, itemTotals: [1450, 800], subtotal: 2250, tax: 259, total: 2509, reconciles: true)
    }

    func testEnglishDinerEndToEnd() async throws {
        try skipIfVisionIntegrationDisabled()
        let image = SyntheticReceiptImages.englishDiner()
        let result = try await pipeline.scan(image: image, orientation: .up)
        assertDraft(
            result.draft,
            itemTotals: [1800, 450],
            quantities: [2, 1],
            subtotal: 2250,
            tax: 180,
            total: 2430,
            reconciles: true
        )
    }

    func testCommaDecimalCafeEndToEnd() async throws {
        try skipIfVisionIntegrationDisabled()
        let image = SyntheticReceiptImages.commaDecimalCafe()
        let result = try await pipeline.scan(image: image, orientation: .up)
        assertDraft(result.draft, itemTotals: [350, 225], subtotal: 575, total: 575, reconciles: true)
    }

    func testSkewedPRIvuBistroStillParses() async throws {
        try skipIfVisionIntegrationDisabled()
        let image = SyntheticReceiptImages.prIVUBistro(skewRadians: -0.12)
        let result = try await pipeline.scan(image: image, orientation: .up)
        XCTAssertTrue(result.draft.reconciles, "skewed receipt should reconcile")
        XCTAssertGreaterThanOrEqual(result.draft.items.count, 2)
    }

    private func assertDraft(
        _ draft: ReceiptDraft,
        itemTotals: [Int],
        quantities: [Int]? = nil,
        subtotal: Int? = nil,
        tax: Int? = nil,
        total: Int? = nil,
        reconciles: Bool
    ) {
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), itemTotals)
        if let quantities {
            XCTAssertEqual(draft.items.map(\.quantity), quantities)
        }
        if let subtotal {
            XCTAssertEqual(draft.subtotal?.minorUnits, subtotal)
        }
        if let tax {
            XCTAssertEqual(draft.tax?.minorUnits, tax)
        }
        if let total {
            XCTAssertEqual(draft.total?.minorUnits, total)
        }
        XCTAssertEqual(draft.reconciles, reconciles)
    }
}
#endif

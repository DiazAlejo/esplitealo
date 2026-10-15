import CoreGraphics
import EsplitealoCore
import EsplitealoScanning
import Foundation
import ImageIO

public struct ScanLabPipelineRunOutcome: Equatable, Sendable {
    public var result: ReceiptScanResult
    public var ocrDurationMilliseconds: Int

    public init(result: ReceiptScanResult, ocrDurationMilliseconds: Int) {
        self.result = result
        self.ocrDurationMilliseconds = ocrDurationMilliseconds
    }
}

public struct ScanLabPipelineRunner: Sendable {
    public var pipeline: ReceiptScanPipeline

    public init(pipeline: ReceiptScanPipeline = ReceiptScanPipeline()) {
        self.pipeline = pipeline
    }

    public func run(
        image: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> ScanLabPipelineRunOutcome {
        let started = ContinuousClock.now
        let result = try await pipeline.scan(image: image, orientation: orientation)
        let elapsed = started.duration(to: .now)
        let ms = Int(elapsed / .milliseconds(1))
        return ScanLabPipelineRunOutcome(result: result, ocrDurationMilliseconds: max(ms, 0))
    }
}

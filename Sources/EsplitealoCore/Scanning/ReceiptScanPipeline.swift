import CoreGraphics
import Foundation
import ImageIO

public struct ReceiptScanResult: Equatable, Sendable {
    public var recognizedText: RecognizedText
    public var draft: ReceiptDraft

    public init(recognizedText: RecognizedText, draft: ReceiptDraft) {
        self.recognizedText = recognizedText
        self.draft = draft
    }
}

/// Image → Vision OCR → `ReceiptParser` → reconciliation-bearing draft.
public struct ReceiptScanPipeline: Sendable {
    public var scanner: ReceiptScanner
    public var parser: ReceiptParser

    public init(scanner: ReceiptScanner = ReceiptScanner(), parser: ReceiptParser = ReceiptParser()) {
        self.scanner = scanner
        self.parser = parser
    }

    public func scan(
        image: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> ReceiptScanResult {
        let recognized = try await scanner.recognize(image: image, orientation: orientation)
        let draft = parser.parse(recognized)
        return ReceiptScanResult(recognizedText: recognized, draft: draft)
    }
}

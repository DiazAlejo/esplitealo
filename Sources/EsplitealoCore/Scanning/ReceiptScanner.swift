import CoreGraphics
import Foundation
import ImageIO

public struct ReceiptScanner: Sendable {
    /// Spanish (Puerto Rico receipts) first, English second. Vision supports `es-ES` (not `es-MX`) on the iOS 17 floor.
    public static let defaultRecognitionLanguages = ["es-ES", "en-US"]

    public var recognizer: any TextRecognizing
    public var maximumSinglePhotoAspectRatio: Double

    public init(
        recognizer: any TextRecognizing = VisionTextRecognizer(),
        maximumSinglePhotoAspectRatio: Double = 4
    ) {
        self.recognizer = recognizer
        self.maximumSinglePhotoAspectRatio = maximumSinglePhotoAspectRatio
    }

    public func recognize(
        image: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> RecognizedText {
        try ReceiptImageValidator.validateDimensions(
            width: image.width,
            height: image.height,
            maximumSinglePhotoAspectRatio: maximumSinglePhotoAspectRatio
        )
        let recognized = try await recognizer.recognize(image: image, orientation: orientation)
        try ReceiptImageValidator.validateRecognizedText(recognized)
        return recognized
    }
}

#if !canImport(Vision)
public struct VisionTextRecognizer: TextRecognizing, Sendable {
    public init() {}
    public func recognize(image: CGImage, orientation: CGImagePropertyOrientation) async throws -> RecognizedText {
        throw ReceiptScanError.noTextFound
    }
}
#endif

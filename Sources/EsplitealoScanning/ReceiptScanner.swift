import CoreGraphics
import EsplitealoCore
import Foundation
import ImageIO

extension CGImagePropertyOrientation {
    func orientedSize(width: Int, height: Int) -> (width: Int, height: Int) {
        switch self {
        case .left, .leftMirrored, .right, .rightMirrored: return (height, width)
        default: return (width, height)
        }
    }
}

public struct ReceiptScanner: Sendable {
    /// Spanish (Puerto Rico receipts) first, English second. Vision supports `es-ES` (not `es-MX`).
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
        let size = orientation.orientedSize(width: image.width, height: image.height)
        try ReceiptImageValidator.validateDimensions(
            width: size.width,
            height: size.height,
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
        throw ReceiptScanError.recognitionUnavailable
    }
}
#endif

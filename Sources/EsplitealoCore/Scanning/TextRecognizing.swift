import CoreGraphics
import Foundation
import ImageIO

public protocol TextRecognizing: Sendable {
    func recognize(
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> RecognizedText
}

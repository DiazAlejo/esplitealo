import CoreGraphics
import EsplitealoCore
import Foundation
import ImageIO

#if canImport(Vision)
import Vision

public struct VisionTextRecognizer: TextRecognizing, Sendable {
    public init() {}

    public func recognize(
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> EsplitealoCore.RecognizedText {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ReceiptScanner.defaultRecognitionLanguages
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        let size = orientation.orientedSize(width: image.width, height: image.height)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    continuation.resume(returning: Self.makeRecognizedText(observations: observations, size: size))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func makeRecognizedText(
        observations: [VNRecognizedTextObservation],
        size: (width: Int, height: Int)
    ) -> EsplitealoCore.RecognizedText {
        let width = CGFloat(size.width)
        let height = CGFloat(size.height)
        func pixelRect(_ box: CGRect) -> PixelRect {
            PixelRect(
                x: Double(box.minX * width),
                y: Double((1 - box.maxY) * height),
                width: Double(box.width * width),
                height: Double(box.height * height)
            )
        }

        var lines: [RecognizedLine] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let string = candidate.string
            var words: [RecognizedWord] = []
            var index = string.startIndex
            while index < string.endIndex {
                while index < string.endIndex, string[index].isWhitespace {
                    index = string.index(after: index)
                }
                let wordStart = index
                while index < string.endIndex, !string[index].isWhitespace {
                    index = string.index(after: index)
                }
                guard wordStart < index else { continue }
                let range = wordStart..<index
                if let box = try? candidate.boundingBox(for: range) {
                    words.append(
                        RecognizedWord(
                            text: String(string[range]),
                            rect: pixelRect(box.boundingBox)
                        )
                    )
                }
            }
            let lineRect = pixelRect(observation.boundingBox)
            let dx = (observation.bottomRight.x - observation.bottomLeft.x) * width
            let dy = (observation.bottomLeft.y - observation.bottomRight.y) * height
            let angle = atan2(Double(dy), Double(dx))
            lines.append(
                RecognizedLine(
                    text: string,
                    confidence: candidate.confidence,
                    rect: lineRect,
                    baselineAngle: angle,
                    words: words
                )
            )
        }

        return EsplitealoCore.RecognizedText(
            imageSize: ImageSize(width: Double(size.width), height: Double(size.height)),
            lines: lines,
            engine: engineLabel
        )
    }

    private static let engineLabel = "VNRecognizeTextRequest accurate"
}
#endif

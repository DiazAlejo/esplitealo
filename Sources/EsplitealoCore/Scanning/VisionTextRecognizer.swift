import CoreGraphics
import Foundation
import ImageIO

#if canImport(Vision)
import Vision

public struct VisionTextRecognizer: TextRecognizing, Sendable {
    public init() {}

    public func recognize(
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> RecognizedText {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(
                        returning: RecognizedText(
                            imageSize: ImageSize(width: Double(image.width), height: Double(image.height)),
                            lines: [],
                            engine: Self.engineLabel
                        )
                    )
                    return
                }
                let width = CGFloat(image.width)
                let height = CGFloat(image.height)
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

                continuation.resume(
                    returning: RecognizedText(
                        imageSize: ImageSize(width: Double(image.width), height: Double(image.height)),
                        lines: lines,
                        engine: Self.engineLabel
                    )
                )
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ReceiptScanner.defaultRecognitionLanguages

            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static let engineLabel = "VNRecognizeTextRequest accurate"
}
#endif

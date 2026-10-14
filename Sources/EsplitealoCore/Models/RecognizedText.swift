import Foundation

/// Pixel-space rectangle with a top-left origin (matches Vision output after conversion).
public struct PixelRect: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }

    public func union(_ other: PixelRect) -> PixelRect {
        let minX = min(x, other.x)
        let minY = min(y, other.y)
        let maxX = max(maxX, other.maxX)
        let maxY = max(maxY, other.maxY)
        return PixelRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

public struct ImageSize: Equatable, Sendable, Codable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct RecognizedWord: Equatable, Sendable, Codable {
    public var text: String
    public var rect: PixelRect

    public init(text: String, rect: PixelRect) {
        self.text = text
        self.rect = rect
    }
}

public struct RecognizedLine: Equatable, Sendable, Codable {
    public var text: String
    public var confidence: Float
    public var rect: PixelRect
    public var baselineAngle: Double
    public var words: [RecognizedWord]

    public init(
        text: String,
        confidence: Float = 1,
        rect: PixelRect,
        baselineAngle: Double = 0,
        words: [RecognizedWord]
    ) {
        self.text = text
        self.confidence = confidence
        self.rect = rect
        self.baselineAngle = baselineAngle
        self.words = words
    }
}

public struct RecognizedText: Equatable, Sendable, Codable {
    public var imageSize: ImageSize
    public var lines: [RecognizedLine]
    public var engine: String

    public init(imageSize: ImageSize, lines: [RecognizedLine], engine: String = "fixture") {
        self.imageSize = imageSize
        self.lines = lines
        self.engine = engine
    }
}

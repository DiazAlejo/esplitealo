import EsplitealoCore
import Foundation

/// Builds the `RecognizedText` a perfect OCR engine would give for a stress receipt: every printed character is read
/// correctly and every word box sits on the monospace grid. Parsing it isolates parser problems from OCR errors.
public enum StressRecognizedTextBuilder {
    public static let characterWidth = 12.0
    public static let lineHeight = 26.0
    public static let leftMargin = 24.0

    /// A gap this wide (in characters) splits a row into two observations, like Vision does for a price column.
    static let observationGap = 4

    public static func build(from receipt: StressReceipt) -> RecognizedText {
        var lines: [RecognizedLine] = []
        var y = 16.0
        for row in receipt.rows {
            let scale = row.style == .large ? 1.5 : 1.0
            let height = lineHeight * scale
            defer { y += height + (row.role == .blank ? 0 : 2) }
            let text = row.text(columns: receipt.columns)
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            lines += observations(of: text, y: y, scale: scale)
        }
        let width = leftMargin * 2 + Double(receipt.columns) * characterWidth
        return RecognizedText(
            imageSize: ImageSize(width: width, height: y + 16),
            lines: lines,
            engine: "stress-ideal"
        )
    }

    private static func observations(of text: String, y: Double, scale: Double) -> [RecognizedLine] {
        let characters = Array(text)
        let cell = characterWidth * scale
        var lines: [RecognizedLine] = []
        var index = 0
        while index < characters.count {
            while index < characters.count, characters[index] == " " { index += 1 }
            guard index < characters.count else { break }
            // One observation runs until a gap of `observationGap` or more spaces.
            var words: [RecognizedWord] = []
            while index < characters.count {
                let wordStart = index
                while index < characters.count, characters[index] != " " { index += 1 }
                words.append(
                    RecognizedWord(
                        text: String(characters[wordStart..<index]),
                        rect: PixelRect(
                            x: leftMargin + Double(wordStart) * cell,
                            y: y,
                            width: Double(index - wordStart) * cell,
                            height: lineHeight * scale * 0.75
                        )
                    )
                )
                var gap = 0
                while index < characters.count, characters[index] == " " {
                    gap += 1
                    index += 1
                }
                if gap >= observationGap || index >= characters.count { break }
            }
            let rect = words.dropFirst().reduce(words[0].rect) { $0.union($1.rect) }
            lines.append(
                RecognizedLine(
                    text: words.map(\.text).joined(separator: " "),
                    confidence: 1,
                    rect: rect,
                    baselineAngle: 0,
                    words: words
                )
            )
        }
        return lines
    }
}

import Foundation
import EsplitealoCore

public enum RecognizedTextTestBuilder {
    /// Lays out each row left-to-right with synthetic word boxes (one cell per row).
    public static func fromRowTexts(
        _ rows: [String],
        imageWidth: Double = 420,
        lineHeight: Double = 22,
        leftMargin: Double = 12
    ) -> RecognizedText {
        var lines: [RecognizedLine] = []
        for (index, row) in rows.enumerated() {
            let y = Double(index) * lineHeight + 8
            let words = row.split(separator: " ", omittingEmptySubsequences: true).enumerated().map { wordIndex, word in
                let x = leftMargin + Double(wordIndex) * 72
                let rect = PixelRect(x: x, y: y, width: Double(word.count) * 9, height: lineHeight - 4)
                return RecognizedWord(text: String(word), rect: rect)
            }
            let fullRect = words.map(\.rect).reduce(PixelRect(x: leftMargin, y: y, width: 200, height: lineHeight)) { $0.union($1) }
            lines.append(
                RecognizedLine(
                    text: row,
                    confidence: 1,
                    rect: fullRect,
                    baselineAngle: 0,
                    words: words
                )
            )
        }
        let height = Double(rows.count) * lineHeight + 16
        return RecognizedText(imageSize: ImageSize(width: imageWidth, height: height), lines: lines)
    }

    /// Splits name (left) and price (right) into separate Vision-style observations on the same row.
    public static func fromNamePricePairs(
        _ pairs: [(name: String, price: String)],
        imageWidth: Double = 420,
        lineHeight: Double = 22
    ) -> RecognizedText {
        var lines: [RecognizedLine] = []
        for (index, pair) in pairs.enumerated() {
            let y = Double(index) * lineHeight + 8
            let nameWords: [RecognizedWord] = pair.name.split(separator: " ").enumerated().map { i, w in
                let text = String(w)
                return RecognizedWord(
                    text: text,
                    rect: PixelRect(x: 12 + Double(i) * 60, y: y, width: Double(text.count) * 9, height: 18)
                )
            }
            let priceRect = PixelRect(x: imageWidth - 80, y: y, width: 64, height: 18)
            let priceWord = RecognizedWord(text: pair.price, rect: priceRect)
            let nameRect = nameWords.dropFirst().reduce(nameWords[0].rect) { $0.union($1.rect) }
            lines.append(
                RecognizedLine(
                    text: pair.name,
                    confidence: 1,
                    rect: nameRect,
                    words: nameWords
                )
            )
            lines.append(
                RecognizedLine(
                    text: pair.price,
                    confidence: 1,
                    rect: priceRect,
                    words: [priceWord]
                )
            )
        }
        let height = Double(pairs.count) * lineHeight + 16
        return RecognizedText(imageSize: ImageSize(width: imageWidth, height: height), lines: lines)
    }
}

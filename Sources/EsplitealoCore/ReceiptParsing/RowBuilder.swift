import Foundation

struct ReceiptRow: Equatable {
    struct Cell: Equatable {
        var text: String
        var rect: PixelRect
    }

    var words: [RecognizedWord]
    var cells: [Cell]
    var centerY: Double
}

enum RowBuilder {
    static func rows(from lines: [RecognizedLine], cellGapFactor: Double = 1.6) -> [ReceiptRow] {
        let skew = medianBaselineAngle(lines: lines)
        let centroid = linesCentroid(lines: lines)
        let cosA = cos(-skew)
        let sinA = sin(-skew)

        func derot(_ rect: PixelRect) -> PixelRect {
            let dx = rect.midX - centroid.x
            let dy = rect.midY - centroid.y
            let nx = centroid.x + dx * cosA - dy * sinA
            let ny = centroid.y + dx * sinA + dy * cosA
            return PixelRect(x: nx - rect.width / 2, y: ny - rect.height / 2, width: rect.width, height: rect.height)
        }

        var words = lines.flatMap(\.words).map { RecognizedWord(text: $0.text, rect: derot($0.rect)) }
        guard !words.isEmpty else { return [] }

        words.sort { $0.rect.midY < $1.rect.midY }
        let heights = words.map(\.rect.height).sorted()
        let medH = heights[heights.count / 2]

        var rowWords: [[RecognizedWord]] = []
        var meanY: [Double] = []

        for word in words {
            if let last = rowWords.indices.last,
               abs(word.rect.midY - meanY[last]) < 0.55 * medH {
                rowWords[last].append(word)
                meanY[last] = rowWords[last].map(\.rect.midY).reduce(0, +) / Double(rowWords[last].count)
            } else {
                rowWords.append([word])
                meanY.append(word.rect.midY)
            }
        }

        return rowWords.enumerated().map { index, ws in
            let sorted = ws.sorted { $0.rect.minX < $1.rect.minX }
            var cells: [ReceiptRow.Cell] = []
            for word in sorted {
                if var last = cells.last,
                   word.rect.minX - last.rect.maxX < cellGapFactor * medH {
                    last.text += " " + word.text
                    last.rect = last.rect.union(word.rect)
                    cells[cells.count - 1] = last
                } else {
                    cells.append(ReceiptRow.Cell(text: word.text, rect: word.rect))
                }
            }
            return ReceiptRow(words: sorted, cells: cells, centerY: meanY[index])
        }
    }

    private static func medianBaselineAngle(lines: [RecognizedLine]) -> Double {
        let angles = lines.filter { line in
            line.rect.width > line.rect.height * 3
        }.map(\.baselineAngle)
        guard !angles.isEmpty else { return 0 }
        let sorted = angles.sorted()
        return sorted[sorted.count / 2]
    }

    private static func linesCentroid(lines: [RecognizedLine]) -> (x: Double, y: Double) {
        let rects = lines.map(\.rect)
        guard !rects.isEmpty else { return (0, 0) }
        let x = rects.map(\.midX).reduce(0, +) / Double(rects.count)
        let y = rects.map(\.midY).reduce(0, +) / Double(rects.count)
        return (x, y)
    }
}

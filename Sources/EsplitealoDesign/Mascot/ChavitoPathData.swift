public enum ChavitoPathCommand: Equatable, Sendable {
    case move(ChavitoPoint)
    case line(ChavitoPoint)
    case quad(control: ChavitoPoint, to: ChavitoPoint)
    case cubic(c1: ChavitoPoint, c2: ChavitoPoint, to: ChavitoPoint)
    case close
}

/// Parser for the absolute `M L Q C Z` subset of SVG path data, which is all the mockup mascot uses.
/// Keeping the original strings as the source of truth lets the SwiftUI view and the SVG export share one geometry.
public enum ChavitoPathData {
    public static func parse(_ d: String) -> [ChavitoPathCommand]? {
        var scanner = Scanner(Array(d))
        var commands: [ChavitoPathCommand] = []
        var letter: Character?

        while true {
            scanner.skipSeparators()
            guard let next = scanner.peek else { break }
            if next.isLetter {
                letter = next
                scanner.advance()
                if next == "Z" {
                    guard !commands.isEmpty else { return nil }
                    commands.append(.close)
                    letter = nil
                    continue
                }
            } else if letter == nil {
                return nil
            }
            guard let current = letter else { return nil }
            if commands.isEmpty, current != "M" { return nil }

            let arity: Int
            switch current {
            case "M", "L": arity = 2
            case "Q": arity = 4
            case "C": arity = 6
            default: return nil
            }
            var values: [Double] = []
            for _ in 0..<arity {
                guard let v = scanner.number() else { return nil }
                values.append(v)
            }
            func pt(_ i: Int) -> ChavitoPoint { ChavitoPoint(x: values[i], y: values[i + 1]) }
            switch current {
            case "M":
                commands.append(.move(pt(0)))
                letter = "L" // further pairs after a move are implicit lines
            case "L": commands.append(.line(pt(0)))
            case "Q": commands.append(.quad(control: pt(0), to: pt(2)))
            default: commands.append(.cubic(c1: pt(0), c2: pt(2), to: pt(4)))
            }
        }
        return commands.isEmpty ? nil : commands
    }

    /// Box around every anchor and control point; a safe over-estimate of the curve's extent.
    public static func controlBounds(of commands: [ChavitoPathCommand]) -> ChavitoRect {
        var points: [ChavitoPoint] = []
        for command in commands {
            switch command {
            case let .move(p), let .line(p): points.append(p)
            case let .quad(c, to): points += [c, to]
            case let .cubic(c1, c2, to): points += [c1, c2, to]
            case .close: break
            }
        }
        guard let first = points.first else { return ChavitoRect(x: 0, y: 0, width: 0, height: 0) }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return ChavitoRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private struct Scanner {
        private let chars: [Character]
        private var index = 0

        init(_ chars: [Character]) { self.chars = chars }

        var peek: Character? { index < chars.count ? chars[index] : nil }

        mutating func advance() { index += 1 }

        mutating func skipSeparators() {
            while let c = peek, c == " " || c == "," || c == "\n" || c == "\t" { index += 1 }
        }

        mutating func number() -> Double? {
            skipSeparators()
            let start = index
            if let c = peek, c == "-" || c == "+" { index += 1 }
            var sawDigit = false
            var sawDot = false
            while let c = peek {
                if c.isNumber, c.isASCII { sawDigit = true; index += 1 }
                else if c == ".", !sawDot { sawDot = true; index += 1 }
                else { break }
            }
            guard sawDigit else { index = start; return nil }
            return Double(String(chars[start..<index]))
        }
    }
}

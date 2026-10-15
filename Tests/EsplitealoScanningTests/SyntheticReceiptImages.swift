import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#endif

enum SyntheticReceiptImages {
    private static let referenceWidth: CGFloat = 420
    private static let defaultScale: CGFloat = 3

    /// Puerto Rico style receipt matching `pr-ivu-bistro` fixture expectations.
    static func prIVUBistro(width: Int = Int(referenceWidth * defaultScale), skewRadians: Double = 0) -> CGImage {
        let lines: [(String, CGFloat?)] = [
            ("RESTAURANTE EL JIBARITO", nil),
            ("San Juan, PR", nil),
            ("Mofongo", 14.50),
            ("Arroz con gandules", 8.00),
            ("Subtotal", 22.50),
            ("IVU 11.5%", 2.59),
            ("Total", 25.09),
        ]
        return render(lines: lines, width: width, skewRadians: skewRadians)
    }

    static func englishDiner(width: Int = Int(referenceWidth * defaultScale)) -> CGImage {
        let lines: [(String, CGFloat?)] = [
            ("Corner Diner", nil),
            ("2 x Burger", 18.00),
            ("Fries", 4.50),
            ("Subtotal", 22.50),
            ("Tax", 1.80),
            ("Total", 24.30),
        ]
        return render(lines: lines, width: width)
    }

    static func commaDecimalCafe(width: Int = Int(referenceWidth * defaultScale)) -> CGImage {
        let lines: [(String, CGFloat?)] = [
            ("Café Central", nil),
            ("Café", 3.50),
            ("Tostada", 2.25),
            ("Subtotal", 5.75),
            ("Total", 5.75),
        ]
        return render(lines: lines, width: width, decimalComma: true)
    }

    private static func render(
        lines: [(String, CGFloat?)],
        width: Int,
        skewRadians: Double = 0,
        decimalComma: Bool = false
    ) -> CGImage {
        #if canImport(AppKit)
        let scale = CGFloat(width) / referenceWidth
        let lineHeight = 26 * scale
        let topPadding = 12 * scale
        let marginX = 16 * scale
        let priceColumnX = CGFloat(width) - 58 * scale
        let fontSize = 14 * scale
        let height = topPadding + CGFloat(lines.count) * lineHeight + 12 * scale
        let size = NSSize(width: CGFloat(width), height: height)

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        if skewRadians != 0 {
            NSGraphicsContext.current?.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            NSGraphicsContext.current?.cgContext.rotate(by: CGFloat(skewRadians))
            NSGraphicsContext.current?.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)
        }

        let font = NSFont(name: "Courier", size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]

        var y = topPadding
        for (label, amount) in lines {
            let drawY = size.height - y - fontSize
            if let amount {
                let formatted = format(amount, comma: decimalComma)
                if label == "Arroz con gandules" {
                    (label as NSString).draw(at: NSPoint(x: marginX, y: drawY), withAttributes: attributes)
                    (formatted as NSString).draw(at: NSPoint(x: priceColumnX, y: drawY), withAttributes: attributes)
                } else {
                    ("\(label) \(formatted)" as NSString).draw(at: NSPoint(x: marginX, y: drawY), withAttributes: attributes)
                }
            } else {
                (label as NSString).draw(at: NSPoint(x: marginX, y: drawY), withAttributes: attributes)
            }
            y += lineHeight
        }
        image.unlockFocus()

        var rect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
        #else
        fatalError("Synthetic receipt images require AppKit")
        #endif
    }

    private static func format(_ amount: CGFloat, comma: Bool) -> String {
        let raw = String(format: "%.2f", amount)
        return comma ? raw.replacingOccurrences(of: ".", with: ",") : raw
    }
}

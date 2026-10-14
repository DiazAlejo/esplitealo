import CoreGraphics
import EsplitealoCore
import Foundation

#if canImport(AppKit)
import AppKit
#endif

public enum SyntheticReceiptStyle: String, CaseIterable, Sendable {
    case restaurantPR
    case colmado
    case restaurantWithService
    case englishDiner
    case longColmado
}

public enum SyntheticReceiptVariant: String, CaseIterable, Sendable {
    case clean
    case skew
    case lowContrast
}

public struct SyntheticReceiptSample: Sendable {
    public var id: String
    public var groundTruth: ReceiptGroundTruth
    /// Single-line row texts as they would appear on a monospace receipt (parser sanity checks).
    public var renderedRowTexts: [String]
    public var style: SyntheticReceiptStyle
    public var variant: SyntheticReceiptVariant

    #if canImport(AppKit)
    public func image(width: Int = 1260) -> CGImage {
        SyntheticReceiptRenderer.render(
            rows: renderedRowTexts,
            width: width,
            skewRadians: variant == .skew ? -0.1 : 0,
            faint: variant == .lowContrast
        )
    }
    #endif
}

public enum SyntheticReceiptGenerator {
    private static let ivuRate = 0.115

    public static func allSamples(seed: UInt64 = 42) -> [SyntheticReceiptSample] {
        var samples: [SyntheticReceiptSample] = []
        for style in SyntheticReceiptStyle.allCases {
            for variant in SyntheticReceiptVariant.allCases {
                if let sample = sample(style: style, variant: variant, seed: seed) {
                    samples.append(sample)
                }
            }
        }
        return samples
    }

    public static func sample(
        style: SyntheticReceiptStyle,
        variant: SyntheticReceiptVariant,
        seed: UInt64
    ) -> SyntheticReceiptSample? {
        switch style {
        case .restaurantPR:
            return buildRestaurantPR(variant: variant, seed: seed)
        case .colmado:
            return buildColmado(variant: variant, seed: seed)
        case .restaurantWithService:
            return buildRestaurantService(variant: variant, seed: seed)
        case .englishDiner:
            return buildEnglishDiner(variant: variant, seed: seed)
        case .longColmado:
            return buildLongColmado(variant: variant, seed: seed)
        }
    }

    private static func buildRestaurantPR(variant: SyntheticReceiptVariant, seed: UInt64) -> SyntheticReceiptSample {
        let items = [
            ("Mofongo", 1450),
            ("Arroz con gandules", 800),
            ("Medalla Light", 350),
        ]
        return finalize(
            id: "restaurant-pr-\(variant.rawValue)-\(seed)",
            header: ["RESTAURANTE EL JIBARITO", "San Juan, PR"],
            items: items,
            taxRate: ivuRate,
            taxLabel: "IVU 11.5%",
            tipMinor: nil,
            variant: variant,
            style: .restaurantPR
        )
    }

    private static func buildColmado(variant: SyntheticReceiptVariant, seed: UInt64) -> SyntheticReceiptSample {
        let items = [
            ("Leche evaporada", 195),
            ("Pan sobao", 350),
            ("2 x Medalla", 700),
            ("Ice bag", 250),
        ]
        return finalize(
            id: "colmado-\(variant.rawValue)-\(seed)",
            header: ["Colmado La Esquina", "Carolina PR"],
            items: items,
            taxRate: ivuRate,
            taxLabel: "IVU 11.5%",
            tipMinor: nil,
            variant: variant,
            style: .colmado
        )
    }

    private static func buildRestaurantService(variant: SyntheticReceiptVariant, seed: UInt64) -> SyntheticReceiptSample {
        let items = [
            ("Churrasco", 2800),
            ("Mahi tacos", 2200),
        ]
        let subtotal = 5000
        let service = Int(Double(subtotal) * 0.18)
        let tax = Int(Double(subtotal) * ivuRate + 0.5)
        let total = subtotal + service + tax
        var rows = ["Bistro del Mar", "Condado"]
        rows += itemRows(items)
        rows.append("Subtotal \(money(subtotal))")
        rows.append("Servicio 18% \(money(service))")
        rows.append("IVU 11.5% \(money(tax))")
        rows.append("Total \(money(total))")
        let truth = ReceiptGroundTruth(
            id: "restaurant-service-\(variant.rawValue)-\(seed)",
            items: items.map { GroundTruthItem(name: $0.0, quantity: quantityFromName($0.0), lineTotalMinor: $0.1) },
            subtotalMinor: subtotal,
            taxMinor: tax,
            tipMinor: service,
            totalMinor: total,
            expectsReconciles: true
        )
        return SyntheticReceiptSample(
            id: truth.id,
            groundTruth: truth,
            renderedRowTexts: rows,
            style: .restaurantWithService,
            variant: variant
        )
    }

    private static func buildEnglishDiner(variant: SyntheticReceiptVariant, seed: UInt64) -> SyntheticReceiptSample {
        let items = [
            ("2 x Burger", 1800),
            ("Fries", 450),
            ("Sparkling Water", 325),
        ]
        return finalize(
            id: "english-diner-\(variant.rawValue)-\(seed)",
            header: ["Corner Diner", "San Juan PR"],
            items: items,
            taxRate: 0.08,
            taxLabel: "Sales Tax 8%",
            tipMinor: nil,
            variant: variant,
            style: .englishDiner
        )
    }

    private static func buildLongColmado(variant: SyntheticReceiptVariant, seed: UInt64) -> SyntheticReceiptSample {
        var rng = SeededRNG(seed: seed)
        var items: [(String, Int)] = []
        let names = ["Galletas", "Jugo", "Yogurt", "Queso", "Jamón", "Cereal", "Arroz", "Aceite", "Café", "Azúcar"]
        for i in 0..<24 {
            let name = names[i % names.count] + " #\(i + 1)"
            let price = rng.next(in: 150...1200)
            items.append((name, price))
        }
        return finalize(
            id: "long-colmado-\(variant.rawValue)-\(seed)",
            header: ["Supermercado Verde", "Bayamón PR"],
            items: items,
            taxRate: ivuRate,
            taxLabel: "IVU 11.5%",
            tipMinor: nil,
            variant: variant,
            style: .longColmado
        )
    }

    private static func finalize(
        id: String,
        header: [String],
        items: [(String, Int)],
        taxRate: Double,
        taxLabel: String,
        tipMinor: Int?,
        variant: SyntheticReceiptVariant,
        style: SyntheticReceiptStyle
    ) -> SyntheticReceiptSample {
        let subtotal = items.reduce(0) { $0 + $1.1 }
        let tax = Int(Double(subtotal) * taxRate + 0.5)
        let tip = tipMinor ?? 0
        let total = subtotal + tax + tip
        var rows = header
        rows += itemRows(items)
        rows.append("Subtotal \(money(subtotal))")
        if let tipMinor {
            rows.append("Propina sugerida \(money(tipMinor))")
        }
        rows.append("\(taxLabel) \(money(tax))")
        rows.append("Total \(money(total))")
        let truthItems = items.map {
            GroundTruthItem(name: stripQuantityPrefix($0.0), quantity: quantityFromName($0.0), lineTotalMinor: $0.1)
        }
        let truth = ReceiptGroundTruth(
            id: id,
            items: truthItems,
            subtotalMinor: subtotal,
            taxMinor: tax,
            tipMinor: tipMinor,
            totalMinor: total,
            expectsReconciles: true
        )
        return SyntheticReceiptSample(
            id: id,
            groundTruth: truth,
            renderedRowTexts: rows,
            style: style,
            variant: variant
        )
    }

    private static func itemRows(_ items: [(String, Int)]) -> [String] {
        items.map { "\($0.0) \(money($0.1))" }
    }

    private static func money(_ minor: Int) -> String {
        String(format: "%.2f", Double(minor) / 100.0)
    }

    private static func quantityFromName(_ name: String) -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let match = trimmed.range(of: #"^(\d+)\s*x\s*"#, options: .regularExpression) {
            let prefix = trimmed[match]
            if let q = Int(prefix.filter(\.isNumber)) { return q }
        }
        return 1
    }

    private static func stripQuantityPrefix(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let regex = try? NSRegularExpression(pattern: #"^\d+\s*x\s*(.+)$"#),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let range = Range(match.range(at: 1), in: trimmed) {
            return String(trimmed[range])
        }
        return trimmed
    }
}

#if canImport(AppKit)
private enum SyntheticReceiptRenderer {
    private static let referenceWidth: CGFloat = 420

    static func render(rows: [String], width: Int, skewRadians: Double, faint: Bool) -> CGImage {
        let scale = CGFloat(width) / referenceWidth
        let lineHeight = 26 * scale
        let topPadding = 12 * scale
        let marginX = 16 * scale
        let fontSize = 14 * scale
        let height = topPadding + CGFloat(rows.count) * lineHeight + 12 * scale
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
        let color = faint ? NSColor.darkGray : NSColor.black
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]

        var y = topPadding
        for row in rows {
            let drawY = size.height - y - fontSize
            (row as NSString).draw(at: NSPoint(x: marginX, y: drawY), withAttributes: attributes)
            y += lineHeight
        }
        image.unlockFocus()

        var rect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }
}
#endif

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next(in range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = (state >> 32) % span
        return range.lowerBound + Int(value)
    }
}

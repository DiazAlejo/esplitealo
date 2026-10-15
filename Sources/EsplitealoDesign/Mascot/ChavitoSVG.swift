import Foundation

/// One reference export: which face, with or without the disc, and for which appearance.
/// The dark variant is drawn on the app's dark ground so the cream and pink read as they do in the app.
public struct ChavitoExportVariant: Equatable, Sendable {
    public var expression: ChavitoExpression
    public var disc: Bool
    public var appearance: ChavitoAppearance

    public init(expression: ChavitoExpression, disc: Bool, appearance: ChavitoAppearance) {
        self.expression = expression
        self.disc = disc
        self.appearance = appearance
    }

    public var includesGround: Bool { appearance == .dark }

    public var stem: String {
        var stem = "chavito-\(expression.rawValue)"
        if disc { stem += "-disc" }
        if appearance == .dark { stem += "-on-dark" }
        return stem
    }

    public static let all: [ChavitoExportVariant] = ChavitoExpression.allCases.flatMap { expression in
        [
            ChavitoExportVariant(expression: expression, disc: false, appearance: .light),
            ChavitoExportVariant(expression: expression, disc: true, appearance: .light),
            ChavitoExportVariant(expression: expression, disc: true, appearance: .dark),
        ]
    }
}

public enum ChavitoSVG {
    /// Shortest decimal form: no trailing `.0`, at most three decimals, no negative zero.
    public static func number(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded == 0 { return "0" }
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }

    public static func document(for variant: ChavitoExportVariant) -> String {
        let palette = ChavitoPalette.palette(for: variant.appearance)
        let box = ChavitoMetrics.viewBox(disc: variant.disc)
        let english = ChavitoAccessibility.label(for: variant.expression, in: .english)
        let spanish = ChavitoAccessibility.label(for: variant.expression, in: .spanish)

        var lines: [String] = []
        lines.append(
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(number(box.x)) \(number(box.y)) \(number(box.width)) \(number(box.height))\" width=\"\(number(box.width))\" height=\"\(number(box.height))\" role=\"img\" aria-label=\"\(english)\">"
        )
        lines.append("  <title>\(english)</title>")
        lines.append("  <desc xml:lang=\"es\">\(spanish)</desc>")
        if variant.includesGround {
            lines.append(
                "  <rect x=\"\(number(box.x))\" y=\"\(number(box.y))\" width=\"\(number(box.width))\" height=\"\(number(box.height))\" fill=\"\(palette.ground.hexString)\"/>"
            )
        }
        if variant.disc {
            lines.append("  " + element(for: ChavitoArt.discLayer, palette: palette))
        }
        lines.append("  <g id=\"\(variant.stem)\">")
        for layer in ChavitoArt.layers(for: variant.expression) {
            lines.append("    " + element(for: layer, palette: palette))
        }
        lines.append("  </g>")
        lines.append("</svg>")
        return lines.joined(separator: "\n") + "\n"
    }

    static func element(for layer: ChavitoLayer, palette: ChavitoPalette) -> String {
        var attributes: [String]
        let tag: String
        switch layer.shape {
        case let .circle(cx, cy, r):
            tag = "circle"
            attributes = ["cx=\"\(number(cx))\"", "cy=\"\(number(cy))\"", "r=\"\(number(r))\""]
        case let .ellipse(cx, cy, rx, ry):
            tag = "ellipse"
            attributes = ["cx=\"\(number(cx))\"", "cy=\"\(number(cy))\"", "rx=\"\(number(rx))\"", "ry=\"\(number(ry))\""]
        case let .path(d):
            tag = "path"
            attributes = ["d=\"\(d)\""]
        }
        if let fill = layer.fill {
            attributes.append("fill=\"\(palette.color(for: fill).hexString)\"")
        } else {
            attributes.append("fill=\"none\"")
        }
        if layer.opacity != 1 { attributes.append("opacity=\"\(number(layer.opacity))\"") }
        if let stroke = layer.stroke {
            attributes.append("stroke=\"\(palette.color(for: stroke.role).hexString)\"")
            attributes.append("stroke-width=\"\(number(stroke.width))\"")
            if stroke.cap == .round { attributes.append("stroke-linecap=\"round\"") }
            if stroke.join == .round { attributes.append("stroke-linejoin=\"round\"") }
        }
        return "<\(tag) " + attributes.joined(separator: " ") + "/>"
    }
}

public enum ChavitoPart: Sendable, Hashable {
    case body
    case eyeWhite
    case pupil
    case shutEyes
    case brows
    case cheeks
    case nose
    case philtrum
    case mouth
    case extra
}

public enum ChavitoShape: Equatable, Sendable {
    case circle(cx: Double, cy: Double, r: Double)
    case ellipse(cx: Double, cy: Double, rx: Double, ry: Double)
    /// SVG path data (absolute `M L Q C Z`), copied from the mockup.
    case path(String)

    public var bounds: ChavitoRect {
        switch self {
        case let .circle(cx, cy, r):
            ChavitoRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
        case let .ellipse(cx, cy, rx, ry):
            ChavitoRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)
        case let .path(d):
            ChavitoPathData.controlBounds(of: ChavitoPathData.parse(d) ?? [])
        }
    }
}

public enum ChavitoLineCap: Sendable, Hashable { case butt, round }
public enum ChavitoLineJoin: Sendable, Hashable { case miter, round }

public struct ChavitoStroke: Equatable, Sendable {
    public var role: ChavitoColorRole
    public var width: Double
    public var cap: ChavitoLineCap
    public var join: ChavitoLineJoin

    public init(
        _ role: ChavitoColorRole,
        width: Double,
        cap: ChavitoLineCap = .round,
        join: ChavitoLineJoin = .round
    ) {
        self.role = role
        self.width = width
        self.cap = cap
        self.join = join
    }
}

/// One painted shape of the mascot, in the head's 200-unit art space.
public struct ChavitoLayer: Equatable, Sendable {
    public var part: ChavitoPart
    public var shape: ChavitoShape
    public var fill: ChavitoColorRole?
    public var stroke: ChavitoStroke?
    public var opacity: Double

    public init(
        _ part: ChavitoPart,
        _ shape: ChavitoShape,
        fill: ChavitoColorRole? = nil,
        stroke: ChavitoStroke? = nil,
        opacity: Double = 1
    ) {
        self.part = part
        self.shape = shape
        self.fill = fill
        self.stroke = stroke
        self.opacity = opacity
    }

    /// Shape bounds grown by half the stroke width.
    public var bounds: ChavitoRect {
        let box = shape.bounds
        let inset = (stroke?.width ?? 0) / 2
        return ChavitoRect(x: box.x - inset, y: box.y - inset, width: box.width + 2 * inset, height: box.height + 2 * inset)
    }
}

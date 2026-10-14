/// Geometry ported from `design/mockups/_src/mascot.js` (`head()`), original artwork, flat style.
public enum ChavitoArt {
    /// Eyes close (blink) around this horizontal line.
    public static let eyeCenterY = 108.0

    /// Soft pink disc behind Chavito (`sceneHome`).
    public static let discLayer = ChavitoLayer(
        .body,
        .circle(cx: ChavitoMetrics.discCenter.x, cy: ChavitoMetrics.discCenter.y, r: ChavitoMetrics.discRadius),
        fill: .disc
    )

    public static func layers(for expression: ChavitoExpression, look: ChavitoPoint? = nil) -> [ChavitoLayer] {
        let look = look ?? expression.defaultLook
        var layers = headLayers
        layers += faceLayers(for: expression, look: look)
        layers += noseLayers
        layers += mouthAndExtras(for: expression)
        return layers
    }

    // MARK: Head

    private static let headLayers: [ChavitoLayer] = [
        // ears
        ChavitoLayer(.body, .circle(cx: 52, cy: 62, r: 23), fill: .fur),
        ChavitoLayer(.body, .circle(cx: 54, cy: 65, r: 12), fill: .furShade),
        ChavitoLayer(.body, .circle(cx: 148, cy: 62, r: 23), fill: .fur),
        ChavitoLayer(.body, .circle(cx: 146, cy: 65, r: 12), fill: .furShade),
        // cheek tufts and head
        ChavitoLayer(.body, .path("M34 112 L12 130 L38 142Z"), fill: .fur),
        ChavitoLayer(.body, .path("M166 112 L188 130 L162 142Z"), fill: .fur),
        ChavitoLayer(.body, .path("M28 116 C28 72 62 48 100 48 C138 48 172 72 172 116 C172 152 142 174 100 174 C58 174 28 152 28 116Z"), fill: .fur),
        // forehead stripe
        ChavitoLayer(.body, .path("M91 50 L109 50 L106 84 L94 84Z"), fill: .furShade),
        // brow patches, muzzle, mask
        ChavitoLayer(.body, .ellipse(cx: 72, cy: 87, rx: 15, ry: 8), fill: .cream),
        ChavitoLayer(.body, .ellipse(cx: 128, cy: 87, rx: 15, ry: 8), fill: .cream),
        ChavitoLayer(.body, .ellipse(cx: 100, cy: 143, rx: 35, ry: 27), fill: .cream),
        ChavitoLayer(.body, .path("M36 106 C48 88 80 86 100 99 C120 86 152 88 164 106 C162 130 134 136 117 124 C108 119 92 119 83 124 C66 136 38 130 36 106Z"), fill: .mask),
    ]

    // MARK: Face

    private static func eye(at cx: Double, look: ChavitoPoint) -> [ChavitoLayer] {
        [
            ChavitoLayer(.eyeWhite, .circle(cx: cx, cy: eyeCenterY, r: 10.5), fill: .white),
            ChavitoLayer(.pupil, .circle(cx: cx + look.x, cy: eyeCenterY + look.y, r: 5.6), fill: .mask),
            ChavitoLayer(.pupil, .circle(cx: cx + 1.8 + look.x, cy: 105.6 + look.y, r: 1.9), fill: .white),
        ]
    }

    private static func brow(_ d: String) -> ChavitoLayer {
        ChavitoLayer(.brows, .path(d), stroke: ChavitoStroke(.mask, width: 4.5))
    }

    private static func faceLayers(for expression: ChavitoExpression, look: ChavitoPoint) -> [ChavitoLayer] {
        switch expression {
        case .happy:
            let arc = ChavitoStroke(.cream, width: 4.6)
            return [
                ChavitoLayer(.shutEyes, .path("M61 113 Q72 98 83 113"), stroke: arc),
                ChavitoLayer(.shutEyes, .path("M117 113 Q128 98 139 113"), stroke: arc),
                ChavitoLayer(.cheeks, .ellipse(cx: 55, cy: 139, rx: 15, ry: 10), fill: .cheek, opacity: 0.85),
                ChavitoLayer(.cheeks, .ellipse(cx: 145, cy: 139, rx: 15, ry: 10), fill: .cheek, opacity: 0.85),
            ]
        case .worried:
            return eye(at: 72, look: look) + eye(at: 128, look: look) + [
                brow("M59 92 L85 81"),
                brow("M115 81 L141 92"),
            ]
        case .thinking:
            return eye(at: 72, look: look) + eye(at: 128, look: look) + [
                brow("M62 87 L83 87"),
                brow("M117 82 Q130 74 143 81"),
            ]
        case .neutral:
            return eye(at: 72, look: look) + eye(at: 128, look: look) + [
                ChavitoLayer(.cheeks, .ellipse(cx: 56, cy: 140, rx: 14, ry: 9), fill: .cheek, opacity: 0.8),
                ChavitoLayer(.cheeks, .ellipse(cx: 144, cy: 140, rx: 14, ry: 9), fill: .cheek, opacity: 0.8),
            ]
        }
    }

    // MARK: Nose, mouth, extras

    private static let noseLayers: [ChavitoLayer] = [
        ChavitoLayer(
            .nose,
            .path("M88 127 C88 120 112 120 112 127 C112 134 105 139 100 140 C95 139 88 134 88 127Z"),
            fill: .nose,
            stroke: ChavitoStroke(.mask, width: 2.2, cap: .butt, join: .round)
        ),
        ChavitoLayer(.nose, .ellipse(cx: 94, cy: 125.5, rx: 3.6, ry: 1.9), fill: .white, opacity: 0.55),
        ChavitoLayer(.philtrum, .path("M100 140 L100 148"), stroke: ChavitoStroke(.mask, width: 3.2)),
    ]

    private static func smile(_ d: String) -> ChavitoLayer {
        ChavitoLayer(.mouth, .path(d), stroke: ChavitoStroke(.mask, width: 4))
    }

    private static func mouthAndExtras(for expression: ChavitoExpression) -> [ChavitoLayer] {
        switch expression {
        case .happy:
            [
                ChavitoLayer(.mouth, .path("M86 147 Q100 172 114 147 Z"), fill: .mask),
                ChavitoLayer(.mouth, .path("M93 160 Q100 152 107 160 Q100 168 93 160Z"), fill: .cheek),
            ]
        case .worried:
            [
                smile("M87 157 Q100 145 113 157"),
                ChavitoLayer(.extra, .path("M164 62 C171 73 173 80 164 85 C155 80 157 73 164 62Z"), fill: .tear),
                ChavitoLayer(.extra, .ellipse(cx: 162, cy: 78, rx: 2, ry: 3), fill: .white, opacity: 0.7),
            ]
        case .thinking:
            [
                smile("M90 153 Q103 148 113 154"),
                ChavitoLayer(.extra, .circle(cx: 162, cy: 46, r: 4), fill: .cream, stroke: ChavitoStroke(.furShade, width: 1.5)),
                ChavitoLayer(.extra, .circle(cx: 173, cy: 32, r: 6), fill: .cream, stroke: ChavitoStroke(.furShade, width: 1.5)),
            ]
        case .neutral:
            [smile("M88 150 Q100 160 112 150")]
        }
    }
}

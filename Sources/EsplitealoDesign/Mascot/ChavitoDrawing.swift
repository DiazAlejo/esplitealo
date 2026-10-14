import SwiftUI

extension ChavitoColor {
    var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: 1)
    }
}

extension ChavitoShape {
    /// SwiftUI path in art units.
    var path: Path {
        switch self {
        case let .circle(cx, cy, r):
            return Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        case let .ellipse(cx, cy, rx, ry):
            return Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
        case let .path(d):
            var path = Path()
            for command in ChavitoPathData.parse(d) ?? [] {
                switch command {
                case let .move(p): path.move(to: CGPoint(x: p.x, y: p.y))
                case let .line(p): path.addLine(to: CGPoint(x: p.x, y: p.y))
                case let .quad(c, to):
                    path.addQuadCurve(to: CGPoint(x: to.x, y: to.y), control: CGPoint(x: c.x, y: c.y))
                case let .cubic(c1, c2, to):
                    path.addCurve(
                        to: CGPoint(x: to.x, y: to.y),
                        control1: CGPoint(x: c1.x, y: c1.y),
                        control2: CGPoint(x: c2.x, y: c2.y)
                    )
                case .close: path.closeSubpath()
                }
            }
            return path
        }
    }
}

/// A layer with its SwiftUI path built once, so the per-frame canvas closure only draws.
struct ChavitoDrawing {
    struct Item {
        let layer: ChavitoLayer
        let path: Path
    }

    let items: [Item]
    let disc: Bool

    init(expression: ChavitoExpression, disc: Bool) {
        items = ChavitoArt.layers(for: expression).map { Item(layer: $0, path: $0.shape.path) }
        self.disc = disc
    }

    func draw(in canvas: GraphicsContext, size: CGSize, palette: ChavitoPalette, pose: ChavitoPose) {
        let box = ChavitoMetrics.viewBox(disc: disc)
        var art = canvas
        let scale = size.width / box.width
        art.scaleBy(x: scale, y: scale)
        art.translateBy(x: -box.x, y: -box.y)

        if disc {
            paint(Item(layer: ChavitoArt.discLayer, path: ChavitoArt.discLayer.shape.path), in: art, palette: palette)
        }

        // Pose moves the head only; the disc stays put. Tilt and pop pivot on the chin / head centre.
        var head = art
        head.translateBy(x: 0, y: pose.bobOffset)
        head.translateBy(x: 100, y: 174)
        head.rotate(by: .degrees(pose.tiltDegrees))
        head.translateBy(x: -100, y: -174)
        head.translateBy(x: ChavitoMetrics.discCenter.x, y: ChavitoMetrics.discCenter.y)
        head.scaleBy(x: pose.scale, y: pose.scale)
        head.translateBy(x: -ChavitoMetrics.discCenter.x, y: -ChavitoMetrics.discCenter.y)

        for item in items {
            var layerContext = head
            if item.layer.part == .eyeWhite || item.layer.part == .pupil {
                let open = max(pose.eyeOpenness, 0.001)
                layerContext.translateBy(x: 0, y: ChavitoArt.eyeCenterY)
                layerContext.scaleBy(x: 1, y: open)
                layerContext.translateBy(x: 0, y: -ChavitoArt.eyeCenterY)
            }
            paint(item, in: layerContext, palette: palette)
        }
    }

    private func paint(_ item: Item, in context: GraphicsContext, palette: ChavitoPalette) {
        var context = context
        context.opacity = item.layer.opacity
        if let fill = item.layer.fill {
            context.fill(item.path, with: .color(palette.color(for: fill).color))
        }
        if let stroke = item.layer.stroke {
            let style = StrokeStyle(
                lineWidth: stroke.width,
                lineCap: stroke.cap == .round ? .round : .butt,
                lineJoin: stroke.join == .round ? .round : .miter
            )
            context.stroke(item.path, with: .color(palette.color(for: stroke.role).color), style: style)
        }
    }
}

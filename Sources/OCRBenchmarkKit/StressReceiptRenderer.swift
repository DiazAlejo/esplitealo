#if canImport(AppKit)
import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Draws a stress receipt like a thermal-paper photo: a monospace print on off-white paper lying on a darker surface,
/// then degraded (rotation, skew, perspective, blur, noise, faded ink, shadow, crumpling).
public enum StressReceiptRenderer {
    /// Width of the paper in pixels. The image is wider: the paper sits on a surface with a margin of 14% per side.
    public static let defaultPaperWidth = 1200

    private static let paddingFraction = 0.14

    public static func render(_ receipt: StressReceipt, paperWidth: Int = defaultPaperWidth) -> CGImage {
        var rng = StressRNG(seed: receipt.seed &+ UInt64(receipt.index) &* 7919 &+ 17)
        let look = Look(degradation: receipt.degradation, rng: &rng)
        let paper = drawPaper(receipt, width: paperWidth, look: look, rng: &rng)
        return degrade(paper, look: look, rng: &rng)
    }

    /// JPEG bytes of a rendered receipt (what the failure artifacts store).
    public static func jpegData(_ image: CGImage, quality: Double = 0.85) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    // MARK: - Look

    /// Everything a degradation changes, picked once per receipt from the seed.
    private struct Look {
        var paperGray: CGFloat = 0.97
        var inkGray: CGFloat = 0.08
        var fontName = "Courier"
        var thermalFade = true
        var rotation = 0.0
        var shear = 0.0
        var perspective = 0.0
        var blurRadius = 0.0
        var noise = 0.0
        var shadow = 0.0
        var shadowAngle = 0.0
        var crumple = 0.0
        var jpegQuality: Double?
        var surfaceGray: CGFloat = 0.32

        init(degradation: StressDegradation, rng: inout StressRNG) {
            fontName = rng.pick(["Courier", "Courier New", "Menlo", "Monaco", "Andale Mono"])
            surfaceGray = CGFloat(rng.double(0.18...0.5))
            func sign() -> Double { rng.chance(0.5) ? 1 : -1 }
            switch degradation {
            case .none:
                break
            case .rotation:
                rotation = sign() * rng.double(0.04...0.16)
            case .skew:
                shear = sign() * rng.double(0.05...0.16)
                rotation = sign() * rng.double(0.0...0.04)
            case .perspective:
                perspective = rng.double(0.04...0.1)
            case .blur:
                blurRadius = rng.double(1.2...3.2)
            case .noise:
                noise = rng.double(0.12...0.28)
                jpegQuality = rng.double(0.35...0.6)
            case .lowContrast:
                inkGray = CGFloat(rng.double(0.5...0.68))
                paperGray = CGFloat(rng.double(0.84...0.92))
            case .shadow:
                shadow = rng.double(0.35...0.6)
                shadowAngle = rng.double(0...(2 * Double.pi))
            case .crumple:
                crumple = rng.double(0.5...1)
            case .photo:
                rotation = sign() * rng.double(0.02...0.08)
                perspective = rng.double(0.02...0.05)
                shadow = rng.double(0.2...0.4)
                shadowAngle = rng.double(0...(2 * Double.pi))
                noise = rng.double(0.05...0.12)
                blurRadius = rng.double(0.4...1.0)
                jpegQuality = rng.double(0.5...0.75)
            }
        }
    }

    // MARK: - Paper

    private static func monospaceFont(named name: String, size: CGFloat, bold: Bool) -> NSFont {
        let base = NSFont(name: name, size: size)
            ?? NSFont(name: "Courier", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        guard bold else { return base }
        let converted = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        return converted.isFixedPitch ? converted : base
    }

    private static func drawPaper(_ receipt: StressReceipt, width: Int, look: Look, rng: inout StressRNG) -> CGImage {
        let probe = monospaceFont(named: look.fontName, size: 100, bold: false)
        let advance = max(0.3, ("M" as NSString).size(withAttributes: [.font: probe]).width / 100)
        let margin = CGFloat(width) * 0.05
        let inner = CGFloat(width) - 2 * margin
        let fontSize = inner / (CGFloat(receipt.columns) * advance)
        let lineHeight = fontSize * 1.42

        func height(of row: StressRow) -> CGFloat {
            row.style == .large ? lineHeight * 1.55 : lineHeight
        }
        let contentHeight = receipt.rows.reduce(0) { $0 + height(of: $1) }
        let totalHeight = Int(ceil(contentHeight + margin * 1.6))

        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(gray: look.paperGray, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

        // Thermal printheads leave faint vertical streaks.
        for _ in 0..<rng.int(2...5) {
            let x = rng.double(0...Double(width))
            context.setFillColor(gray: 0.5, alpha: CGFloat(rng.double(0.02...0.06)))
            context.fill(CGRect(x: x, y: 0, width: rng.double(1...4), height: Double(totalHeight)))
        }

        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        var top = margin * 0.8
        for row in receipt.rows {
            let rowHeight = height(of: row)
            defer { top += rowHeight }
            let text = row.text(columns: receipt.columns)
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let large = row.style == .large
            let font = monospaceFont(named: look.fontName, size: large ? fontSize * 1.5 : fontSize, bold: row.style != .normal)
            // Faded rows: thermal paper loses ink unevenly.
            let fade = look.thermalFade ? CGFloat(rng.double(0.0...0.22)) : 0
            let ink = min(0.75, look.inkGray + fade)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(calibratedWhite: ink, alpha: 1),
            ]
            let box = font.ascender - font.descender
            let y = CGFloat(totalHeight) - top - rowHeight + (rowHeight - box) / 2
            (text as NSString).draw(at: NSPoint(x: margin, y: y), withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()

        if look.crumple > 0 {
            drawCreases(in: context, width: width, height: totalHeight, strength: look.crumple, rng: &rng)
        }
        return context.makeImage()!
    }

    /// Soft light and dark lines across the paper, like folds in a crumpled receipt.
    private static func drawCreases(in context: CGContext, width: Int, height: Int, strength: Double, rng: inout StressRNG) {
        for _ in 0..<Int(4 + 6 * strength) {
            let start = CGPoint(x: rng.double(-0.1...1.1) * Double(width), y: rng.double(0...1) * Double(height))
            let angle = rng.double(0...Double.pi)
            let length = Double(width) * rng.double(0.6...1.6)
            let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            for (offset, gray, alpha) in [(0.0, CGFloat(0.1), 0.16), (5.0, CGFloat(1), 0.28)] {
                context.setStrokeColor(gray: gray, alpha: CGFloat(alpha * strength))
                context.setLineWidth(CGFloat(rng.double(2...6)))
                context.move(to: CGPoint(x: start.x + offset, y: start.y))
                context.addLine(to: CGPoint(x: end.x + offset, y: end.y))
                context.strokePath()
            }
        }
    }

    // MARK: - Degradation

    private static func degrade(_ paper: CGImage, look: Look, rng: inout StressRNG) -> CGImage {
        let paperWidth = CGFloat(paper.width)
        let paperHeight = CGFloat(paper.height)
        let pad = (paperWidth * paddingFraction).rounded()
        let canvas = CGRect(x: 0, y: 0, width: paperWidth + 2 * pad, height: paperHeight + 2 * pad)
        let center = CGPoint(x: canvas.midX, y: canvas.midY)

        var sheet = CIImage(cgImage: paper).transformed(by: CGAffineTransform(translationX: pad, y: pad))

        if look.crumple > 0 {
            for _ in 0..<Int(2 + 3 * look.crumple) {
                let bump = CIFilter.bumpDistortion()
                bump.inputImage = sheet
                bump.center = CGPoint(
                    x: pad + rng.double(0.1...0.9) * Double(paperWidth),
                    y: pad + rng.double(0.05...0.95) * Double(paperHeight)
                )
                bump.radius = Float(rng.double(0.18...0.4) * Double(paperWidth))
                bump.scale = Float(rng.double(-0.35...0.35) * look.crumple)
                sheet = (bump.outputImage ?? sheet).cropped(to: sheet.extent)
            }
        }

        if look.perspective > 0 {
            let inset = look.perspective * Double(paperWidth)
            let sag = look.perspective * Double(paperWidth) * 0.4
            let filter = CIFilter.perspectiveTransform()
            filter.inputImage = sheet
            let left = sheet.extent.minX, right = sheet.extent.maxX, bottom = sheet.extent.minY, top = sheet.extent.maxY
            filter.topLeft = CGPoint(x: left + inset, y: top - sag)
            filter.topRight = CGPoint(x: right - inset * 0.3, y: top)
            filter.bottomLeft = CGPoint(x: left, y: bottom)
            filter.bottomRight = CGPoint(x: right, y: bottom + sag * 0.3)
            sheet = filter.outputImage ?? sheet
        }

        if look.rotation != 0 || look.shear != 0 {
            // Shear, then rotate, both about the middle of the image.
            let shear = CGAffineTransform(a: 1, b: 0, c: CGFloat(tan(look.shear)), d: 1, tx: 0, ty: 0)
            let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
                .concatenating(shear)
                .concatenating(CGAffineTransform(rotationAngle: CGFloat(look.rotation)))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            sheet = sheet.transformed(by: transform)
        }

        let surface = CIImage(color: CIColor(red: look.surfaceGray, green: look.surfaceGray * 0.92, blue: look.surfaceGray * 0.82))
            .cropped(to: canvas)
        var image = sheet.composited(over: surface).cropped(to: canvas)

        if look.shadow > 0 {
            let gradient = CIFilter.linearGradient()
            let reach = Double(canvas.width + canvas.height) * 0.5
            let from = CGPoint(
                x: center.x - cos(look.shadowAngle) * reach * 0.5,
                y: center.y - sin(look.shadowAngle) * reach * 0.5
            )
            let to = CGPoint(
                x: center.x + cos(look.shadowAngle) * reach * 0.5,
                y: center.y + sin(look.shadowAngle) * reach * 0.5
            )
            gradient.point0 = from
            gradient.point1 = to
            let dark = CGFloat(1 - look.shadow)
            gradient.color0 = CIColor(red: dark, green: dark, blue: dark)
            gradient.color1 = CIColor(red: 1, green: 1, blue: 1)
            let multiply = CIFilter.multiplyCompositing()
            multiply.inputImage = gradient.outputImage?.cropped(to: canvas)
            multiply.backgroundImage = image
            image = multiply.outputImage?.cropped(to: canvas) ?? image
        }

        if look.blurRadius > 0 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = image.clampedToExtent()
            blur.radius = Float(look.blurRadius)
            image = blur.outputImage?.cropped(to: canvas) ?? image
        }

        if look.noise > 0 {
            let random = CIFilter.randomGenerator().outputImage!
                .transformed(by: CGAffineTransform(translationX: rng.double(0...4000), y: rng.double(0...4000)))
            let matrix = CIFilter.colorMatrix()
            let k = CGFloat(look.noise)
            matrix.inputImage = random
            matrix.rVector = CIVector(x: k, y: 0, z: 0, w: 0)
            matrix.gVector = CIVector(x: k, y: 0, z: 0, w: 0)
            matrix.bVector = CIVector(x: k, y: 0, z: 0, w: 0)
            matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            matrix.biasVector = CIVector(x: -k / 2, y: -k / 2, z: -k / 2, w: 1)
            let add = CIFilter.additionCompositing()
            add.inputImage = matrix.outputImage?.cropped(to: canvas)
            add.backgroundImage = image
            image = add.outputImage?.cropped(to: canvas) ?? image
        }

        let context = CIContext(options: [.useSoftwareRenderer: true, .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        var output = context.createCGImage(image, from: canvas) ?? paper
        if let quality = look.jpegQuality, let data = jpegData(output, quality: quality),
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            output = decoded
        }
        return output
    }
}
#endif

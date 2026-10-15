#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import EsplitealoDesign

/// The drawing cannot be asserted shape by shape, so these render each view with `ImageRenderer`
/// and check that real pixels (and the right colours in the right places) come out.
@MainActor
final class ChavitoRenderTests: XCTestCase {
    private struct Bitmap {
        let width: Int
        let height: Int
        let rgba: [UInt8]

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
            let i = (y * width + x) * 4
            return (Int(rgba[i]), Int(rgba[i + 1]), Int(rgba[i + 2]), Int(rgba[i + 3]))
        }

        var opaqueFraction: Double {
            var opaque = 0
            for i in stride(from: 3, to: rgba.count, by: 4) where rgba[i] > 8 { opaque += 1 }
            return Double(opaque) / Double(width * height)
        }
    }

    private func render(_ view: some View, scale: CGFloat = 1) throws -> Bitmap {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        let image = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image")
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let drewOK: Bool = data.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drewOK)
        return Bitmap(width: width, height: height, rgba: data)
    }

    private func chavito(
        _ expression: ChavitoExpression,
        size: CGFloat = 200,
        disc: Bool = false,
        dark: Bool = false
    ) -> some View {
        ChavitoView(expression: expression, size: size, disc: disc, decorative: true, animated: false)
            .environment(\.colorScheme, dark ? .dark : .light)
    }

    func testEveryExpressionRendersNonEmptyImageAtMockupAspect() throws {
        for expression in ChavitoExpression.allCases {
            let bitmap = try render(chavito(expression), scale: 2)
            XCTAssertEqual(bitmap.width, 400, "\(expression)")
            XCTAssertEqual(bitmap.height, 380, "\(expression)")
            XCTAssertGreaterThan(bitmap.opaqueFraction, 0.4, "\(expression) head should fill much of the box")
        }
    }

    func testDiscVariantIsSquareAndFillsACircle() throws {
        for expression in ChavitoExpression.allCases {
            for dark in [false, true] {
                let bitmap = try render(chavito(expression, size: 120, disc: true, dark: dark))
                XCTAssertEqual(bitmap.width, 120)
                XCTAssertEqual(bitmap.height, 120)
                // a circle inscribed in the square covers pi/4 = 78.5%
                XCTAssertEqual(bitmap.opaqueFraction, .pi / 4, accuracy: 0.05, "\(expression) dark=\(dark)")
                XCTAssertEqual(bitmap.pixel(1, 1).a, 0, "corners stay transparent")
            }
        }
    }

    func testExpressionsLookDifferent() throws {
        let images = try ChavitoExpression.allCases.map { try render(chavito($0)).rgba }
        for i in images.indices {
            for j in images.indices where j > i {
                XCTAssertNotEqual(images[i], images[j], "\(ChavitoExpression.allCases[i]) vs \(ChavitoExpression.allCases[j])")
            }
        }
    }

    func testNoseIsPinkInLightAndDark() throws {
        // Nose centre is art (104, 131); head box origin is art (0, 6) at 1 pt per unit.
        for dark in [false, true] {
            let p = try render(chavito(.neutral, dark: dark)).pixel(104, 125)
            XCTAssertEqual(p.r, 0xEA, accuracy: 4, "dark=\(dark)")
            XCTAssertEqual(p.g, 0x5A, accuracy: 4, "dark=\(dark)")
            XCTAssertEqual(p.b, 0x78, accuracy: 4, "dark=\(dark)")
        }
    }

    func testDiscColourDoesNotShiftInDark() throws {
        // 208 pt wide disc: 1 pt per art unit. Pixel (20, 104) is far left of centre, clear of the head.
        let light = try render(chavito(.neutral, size: 208, disc: true, dark: false)).pixel(20, 104)
        XCTAssertEqual(light.r, 0xFC, accuracy: 4)
        XCTAssertEqual(light.g, 0xE8, accuracy: 4)
        XCTAssertEqual(light.b, 0xEC, accuracy: 4)
        let dark = try render(chavito(.neutral, size: 208, disc: true, dark: true)).pixel(20, 104)
        XCTAssertEqual(dark.r, 0xFC, accuracy: 4)
        XCTAssertEqual(dark.g, 0xE8, accuracy: 4)
        XCTAssertEqual(dark.b, 0xEC, accuracy: 4)
    }

    func testBareHeadIsIdenticalInLightAndDark() throws {
        XCTAssertEqual(
            try render(chavito(.worried, dark: false)).rgba,
            try render(chavito(.worried, dark: true)).rgba
        )
    }

    func testSmallSizesStillRender() throws {
        for size: CGFloat in [24, 32, 64] {
            let bitmap = try render(chavito(.happy, size: size))
            XCTAssertEqual(bitmap.width, Int(size))
            XCTAssertGreaterThan(bitmap.opaqueFraction, 0.3)
        }
    }

    func testAnimatedViewRendersAFrameToo() throws {
        let animated = ChavitoView(expression: .thinking, size: 160, decorative: true)
        XCTAssertGreaterThan(try render(animated).opaqueFraction, 0.4)
    }
}

@MainActor
final class ChavitoExportTests: XCTestCase {
    func testPDFDataIsAPDFPageAtLayoutSize() throws {
        let data = try XCTUnwrap(ChavitoPDF.data(for: .init(expression: .happy, disc: true, appearance: .dark)))
        XCTAssertEqual(String(decoding: data.prefix(5), as: UTF8.self), "%PDF-")
        XCTAssertGreaterThan(data.count, 500)
        let box = try XCTUnwrap(ChavitoPDF.mediaBox(of: data))
        XCTAssertEqual(box.width, 208, accuracy: 0.5)
        XCTAssertEqual(box.height, 208, accuracy: 0.5)
    }

    func testHeadPDFHasMockupAspect() throws {
        let data = try XCTUnwrap(ChavitoPDF.data(for: .init(expression: .neutral, disc: false, appearance: .light)))
        let box = try XCTUnwrap(ChavitoPDF.mediaBox(of: data))
        XCTAssertEqual(box.width, 200, accuracy: 0.5)
        XCTAssertEqual(box.height, 190, accuracy: 0.5)
    }

    /// `ESPLITEALO_EXPORT_CHAVITO=1 swift test --filter ChavitoExportTests` rewrites the files in
    /// `design/brand/chavito/`. Without the variable this test only checks that the folder exists.
    func testWriteReferenceFilesWhenRequested() throws {
        let fm = FileManager.default
        guard ProcessInfo.processInfo.environment["ESPLITEALO_EXPORT_CHAVITO"] == "1" else {
            XCTAssertTrue(fm.fileExists(atPath: ChavitoExportPaths.svgDirectory.path))
            XCTAssertTrue(fm.fileExists(atPath: ChavitoExportPaths.pdfDirectory.path))
            for variant in ChavitoExportVariant.all {
                let pdf = ChavitoExportPaths.pdfDirectory.appendingPathComponent("\(variant.stem).pdf")
                XCTAssertTrue(fm.fileExists(atPath: pdf.path), "\(variant.stem).pdf missing")
            }
            return
        }
        try fm.createDirectory(at: ChavitoExportPaths.svgDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: ChavitoExportPaths.pdfDirectory, withIntermediateDirectories: true)
        for variant in ChavitoExportVariant.all {
            try ChavitoSVG.document(for: variant)
                .write(to: ChavitoExportPaths.svgDirectory.appendingPathComponent("\(variant.stem).svg"), atomically: true, encoding: .utf8)
            let pdf = try XCTUnwrap(ChavitoPDF.data(for: variant))
            try pdf.write(to: ChavitoExportPaths.pdfDirectory.appendingPathComponent("\(variant.stem).pdf"))
        }
    }
}

private func XCTAssertEqual(_ a: Int, _ b: Int, accuracy: Int, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(a - b), accuracy, "\(a) vs \(b) \(message)", file: file, line: line)
}
#endif

import XCTest
@testable import EsplitealoDesign

final class ChavitoSVGTests: XCTestCase {
    func testNumberFormatting() {
        XCTAssertEqual(ChavitoSVG.number(75), "75")
        XCTAssertEqual(ChavitoSVG.number(105.6), "105.6")
        XCTAssertEqual(ChavitoSVG.number(72 + 1.8), "73.8")
        XCTAssertEqual(ChavitoSVG.number(-4), "-4")
        XCTAssertEqual(ChavitoSVG.number(0.85), "0.85")
        XCTAssertEqual(ChavitoSVG.number(-0.0), "0")
    }

    func testExportVariantsCoverEveryExpressionThreeWays() {
        let variants = ChavitoExportVariant.all
        XCTAssertEqual(variants.count, 12)
        XCTAssertEqual(Set(variants.map(\.stem)).count, 12)
        XCTAssertEqual(
            ChavitoExportVariant(expression: .happy, disc: false, appearance: .light).stem,
            "chavito-happy"
        )
        XCTAssertEqual(
            ChavitoExportVariant(expression: .thinking, disc: true, appearance: .light).stem,
            "chavito-thinking-disc"
        )
        XCTAssertEqual(
            ChavitoExportVariant(expression: .worried, disc: true, appearance: .dark).stem,
            "chavito-worried-disc-on-dark"
        )
    }

    func testHeadDocumentIsWellFormedAndLabelled() throws {
        for variant in ChavitoExportVariant.all {
            let svg = ChavitoSVG.document(for: variant)
            let parser = XMLParser(data: Data(svg.utf8))
            XCTAssertTrue(parser.parse(), "\(variant.stem): \(String(describing: parser.parserError))")
            XCTAssertTrue(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
            XCTAssertTrue(svg.contains("role=\"img\""))
            XCTAssertTrue(svg.contains(ChavitoAccessibility.label(for: variant.expression, in: .english)))
            XCTAssertTrue(svg.contains(ChavitoAccessibility.label(for: variant.expression, in: .spanish)))
        }
    }

    func testViewBoxes() {
        XCTAssertTrue(
            ChavitoSVG.document(for: .init(expression: .neutral, disc: false, appearance: .light))
                .contains("viewBox=\"0 6 200 190\"")
        )
        XCTAssertTrue(
            ChavitoSVG.document(for: .init(expression: .neutral, disc: true, appearance: .light))
                .contains("viewBox=\"-4 10 208 208\"")
        )
    }

    func testLightDiscIsPinkSoftWithoutGround() {
        let svg = ChavitoSVG.document(for: .init(expression: .happy, disc: true, appearance: .light))
        XCTAssertTrue(svg.contains("<circle cx=\"100\" cy=\"114\" r=\"104\" fill=\"#FCE8EC\"/>"))
        XCTAssertFalse(svg.contains("#0F2A21"))
        XCTAssertFalse(svg.contains("#FBF7EF"))
    }

    func testDarkDiscSitsOnDarkGroundWithTheSamePinkDiscAndCream() {
        let svg = ChavitoSVG.document(for: .init(expression: .happy, disc: true, appearance: .dark))
        XCTAssertTrue(svg.contains("<rect x=\"-4\" y=\"10\" width=\"208\" height=\"208\" fill=\"#0F2A21\"/>"))
        XCTAssertTrue(svg.contains("<circle cx=\"100\" cy=\"114\" r=\"104\" fill=\"#FCE8EC\"/>"))
        XCTAssertFalse(svg.contains("#4D2630"))
        XCTAssertTrue(svg.contains("#EA5A78"))
        XCTAssertTrue(svg.contains("#F5EEDF"))
    }

    func testBareHeadHasNoDiscOrGround() {
        let svg = ChavitoSVG.document(for: .init(expression: .worried, disc: false, appearance: .light))
        XCTAssertFalse(svg.contains("#FCE8EC"))
        XCTAssertFalse(svg.contains("<rect"))
    }

    func testPathDataIsCopiedVerbatimFromTheMockup() {
        let svg = ChavitoSVG.document(for: .init(expression: .neutral, disc: false, appearance: .light))
        XCTAssertTrue(svg.contains("d=\"M28 116 C28 72 62 48 100 48 C138 48 172 72 172 116 C172 152 142 174 100 174 C58 174 28 152 28 116Z\""))
    }

    func testDocumentIsDeterministic() {
        let v = ChavitoExportVariant(expression: .thinking, disc: true, appearance: .dark)
        XCTAssertEqual(ChavitoSVG.document(for: v), ChavitoSVG.document(for: v))
    }

    /// Guards `design/brand/chavito/svg/` against drifting from the Swift artwork.
    /// Regenerate with `ESPLITEALO_EXPORT_CHAVITO=1 swift test --filter ChavitoExportTests`.
    func testCommittedSVGFilesMatchTheGenerator() throws {
        let dir = ChavitoExportPaths.svgDirectory
        for variant in ChavitoExportVariant.all {
            let url = dir.appendingPathComponent("\(variant.stem).svg")
            let committed = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(committed, ChavitoSVG.document(for: variant), "\(variant.stem).svg is stale")
        }
    }
}

enum ChavitoExportPaths {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/brand/chavito", isDirectory: true)
    static let svgDirectory = root.appendingPathComponent("svg", isDirectory: true)
    static let pdfDirectory = root.appendingPathComponent("pdf", isDirectory: true)
}

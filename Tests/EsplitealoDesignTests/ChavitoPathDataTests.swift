import XCTest
@testable import EsplitealoDesign

final class ChavitoPathDataTests: XCTestCase {
    private func p(_ x: Double, _ y: Double) -> ChavitoPoint { ChavitoPoint(x: x, y: y) }

    func testParsesMoveAndQuad() {
        XCTAssertEqual(
            ChavitoPathData.parse("M61 113 Q72 98 83 113"),
            [.move(p(61, 113)), .quad(control: p(72, 98), to: p(83, 113))]
        )
    }

    func testParsesLinesAndCloseAttachedToNumbers() {
        XCTAssertEqual(
            ChavitoPathData.parse("M91 50 L109 50 L106 84 L94 84Z"),
            [.move(p(91, 50)), .line(p(109, 50)), .line(p(106, 84)), .line(p(94, 84)), .close]
        )
    }

    func testParsesCubicWithDecimalsAndNegatives() {
        XCTAssertEqual(
            ChavitoPathData.parse("M-4 10.5 C88 120 112 120.25 112 127"),
            [.move(p(-4, 10.5)), .cubic(c1: p(88, 120), c2: p(112, 120.25), to: p(112, 127))]
        )
    }

    func testRejectsMalformedData() {
        XCTAssertNil(ChavitoPathData.parse(""))
        XCTAssertNil(ChavitoPathData.parse("M1"))
        XCTAssertNil(ChavitoPathData.parse("M1 2 Q3 4"))
        XCTAssertNil(ChavitoPathData.parse("X1 2"))
        XCTAssertNil(ChavitoPathData.parse("L1 2"), "a path must start with a move")
    }

    func testControlPointBounds() {
        let commands = ChavitoPathData.parse("M10 20 Q50 5 30 40 Z")!
        let box = ChavitoPathData.controlBounds(of: commands)
        XCTAssertEqual(box, ChavitoRect(x: 10, y: 5, width: 40, height: 35))
    }
}

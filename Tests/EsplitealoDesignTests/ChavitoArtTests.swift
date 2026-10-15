import XCTest
@testable import EsplitealoDesign

final class ChavitoArtTests: XCTestCase {
    private func count(_ part: ChavitoPart, in layers: [ChavitoLayer]) -> Int {
        layers.filter { $0.part == part }.count
    }

    func testEveryExpressionDrawsAHeadFirst() {
        for expression in ChavitoExpression.allCases {
            let layers = ChavitoArt.layers(for: expression)
            XCTAssertEqual(layers.first?.shape, .circle(cx: 52, cy: 62, r: 23), "ear first for \(expression)")
            XCTAssertTrue(layers.contains { $0.part == .body && $0.shape == .path("M28 116 C28 72 62 48 100 48 C138 48 172 72 172 116 C172 152 142 174 100 174 C58 174 28 152 28 116Z") })
            XCTAssertEqual(count(.nose, in: layers), 2, "nose plus its highlight")
        }
    }

    func testNeutralParts() {
        let l = ChavitoArt.layers(for: .neutral)
        XCTAssertEqual(count(.eyeWhite, in: l), 2)
        XCTAssertEqual(count(.pupil, in: l), 4)
        XCTAssertEqual(count(.brows, in: l), 0)
        XCTAssertEqual(count(.cheeks, in: l), 2)
        XCTAssertEqual(count(.extra, in: l), 0)
    }

    func testHappyHasShutEyesAndOpenMouth() {
        let l = ChavitoArt.layers(for: .happy)
        XCTAssertEqual(count(.eyeWhite, in: l), 0)
        XCTAssertEqual(count(.pupil, in: l), 0)
        XCTAssertEqual(count(.shutEyes, in: l), 2)
        XCTAssertEqual(count(.mouth, in: l), 2, "open mouth plus tongue")
        XCTAssertEqual(count(.cheeks, in: l), 2)
    }

    func testThinkingHasBrowsAndThoughtBubbles() {
        let l = ChavitoArt.layers(for: .thinking)
        XCTAssertEqual(count(.eyeWhite, in: l), 2)
        XCTAssertEqual(count(.brows, in: l), 2)
        XCTAssertEqual(count(.extra, in: l), 2)
        XCTAssertEqual(count(.cheeks, in: l), 0)
    }

    func testWorriedHasBrowsAndTear() {
        let l = ChavitoArt.layers(for: .worried)
        XCTAssertEqual(count(.brows, in: l), 2)
        XCTAssertEqual(count(.extra, in: l), 2, "tear plus its glint")
        XCTAssertEqual(count(.cheeks, in: l), 0)
        XCTAssertEqual(l.first { $0.part == .extra }?.fill, .tear)
    }

    func testLookIsBakedIntoPupils() {
        let thinking = ChavitoArt.layers(for: .thinking).filter { $0.part == .pupil }
        XCTAssertEqual(thinking[0].shape, .circle(cx: 75, cy: 104, r: 5.6))
        XCTAssertEqual(thinking[1].shape, .circle(cx: 76.8, cy: 101.6, r: 1.9))

        let custom = ChavitoArt.layers(for: .neutral, look: ChavitoPoint(x: -4, y: 1)).filter { $0.part == .pupil }
        XCTAssertEqual(custom[0].shape, .circle(cx: 68, cy: 109, r: 5.6))
        XCTAssertEqual(custom[2].shape, .circle(cx: 124, cy: 109, r: 5.6))
    }

    func testEveryLayerIsPaintedAndEveryPathParses() {
        for expression in ChavitoExpression.allCases {
            for layer in ChavitoArt.layers(for: expression) {
                XCTAssertTrue(layer.fill != nil || layer.stroke != nil, "\(expression) \(layer.part)")
                if case let .path(d) = layer.shape {
                    XCTAssertNotNil(ChavitoPathData.parse(d), d)
                }
            }
        }
    }

    func testAllArtworkFitsTheHeadViewBox() {
        for expression in ChavitoExpression.allCases {
            for layer in ChavitoArt.layers(for: expression) {
                XCTAssertTrue(
                    ChavitoMetrics.headViewBox.contains(layer.bounds),
                    "\(expression) \(layer.part) \(layer.bounds)"
                )
            }
        }
    }

    func testDiscLayerFillsTheDiscViewBox() {
        let disc = ChavitoArt.discLayer
        XCTAssertEqual(disc.shape, .circle(cx: 100, cy: 114, r: 104))
        XCTAssertEqual(disc.fill, .disc)
        XCTAssertEqual(disc.bounds, ChavitoMetrics.discViewBox)
        for expression in ChavitoExpression.allCases {
            for layer in ChavitoArt.layers(for: expression) {
                XCTAssertTrue(ChavitoMetrics.discViewBox.contains(layer.bounds), "\(expression) \(layer.part)")
            }
        }
    }

    func testEyeAnchorForBlink() {
        XCTAssertEqual(ChavitoArt.eyeCenterY, 108)
    }
}

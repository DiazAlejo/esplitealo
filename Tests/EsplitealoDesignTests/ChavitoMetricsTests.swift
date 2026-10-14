import XCTest
@testable import EsplitealoDesign

final class ChavitoMetricsTests: XCTestCase {
    func testHeadViewBoxIsTheMockupBox() {
        XCTAssertEqual(ChavitoMetrics.headViewBox, ChavitoRect(x: 0, y: 6, width: 200, height: 190))
    }

    func testHeadSizeKeepsMockupAspect() {
        let size = ChavitoMetrics.layoutSize(forWidth: 100, disc: false)
        XCTAssertEqual(size.width, 100, accuracy: 1e-9)
        XCTAssertEqual(size.height, 95, accuracy: 1e-9)
    }

    func testDiscSizeIsSquare() {
        let size = ChavitoMetrics.layoutSize(forWidth: 120, disc: true)
        XCTAssertEqual(size.width, 120, accuracy: 1e-9)
        XCTAssertEqual(size.height, 120, accuracy: 1e-9)
    }

    func testScaleIsPointsPerArtUnit() {
        XCTAssertEqual(ChavitoMetrics.scale(forWidth: 100, disc: false), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ChavitoMetrics.scale(forWidth: 208, disc: true), 1, accuracy: 1e-9)
    }

    func testNegativeAndNonFiniteWidthsCollapseToZero() {
        XCTAssertEqual(ChavitoMetrics.layoutSize(forWidth: -10, disc: false).width, 0)
        XCTAssertEqual(ChavitoMetrics.layoutSize(forWidth: .nan, disc: true).height, 0)
        XCTAssertEqual(ChavitoMetrics.scale(forWidth: .infinity, disc: false), 0)
    }

    func testDiscMatchesHomeScene() {
        // sceneHome: disc r=104 centred on head art point (100, 114); view box is the disc's bounding square.
        XCTAssertEqual(ChavitoMetrics.discCenter, ChavitoPoint(x: 100, y: 114))
        XCTAssertEqual(ChavitoMetrics.discRadius, 104)
        XCTAssertEqual(ChavitoMetrics.discViewBox, ChavitoRect(x: -4, y: 10, width: 208, height: 208))
    }
}

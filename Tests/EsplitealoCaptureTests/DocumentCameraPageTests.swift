import XCTest
@testable import EsplitealoCapture

final class DocumentCameraPageTests: XCTestCase {
    func testZeroPagesIsNoImage() {
        XCTAssertEqual(DocumentCameraError.validatePageCount(0), .noImage)
    }

    func testSinglePageIsAccepted() {
        XCTAssertNil(DocumentCameraError.validatePageCount(1))
    }

    func testMultiplePagesIsTooManyPages() {
        XCTAssertEqual(DocumentCameraError.validatePageCount(2), .tooManyPages)
        XCTAssertEqual(DocumentCameraError.validatePageCount(5), .tooManyPages)
    }
}

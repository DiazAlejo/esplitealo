import XCTest
@testable import EsplitealoCapture

final class CaptureErrorMessageTests: XCTestCase {
    func testDocumentCameraMessages() {
        XCTAssertEqual(DocumentCameraError.cancelled.labMessage, "Document scan cancelled.")
        XCTAssertTrue(DocumentCameraError.tooManyPages.labMessage.contains("one receipt"))
    }

    func testPhotoImportMessages() {
        XCTAssertEqual(PhotoImportError.loadFailed.labMessage, "Could not load the selected photo.")
    }
}

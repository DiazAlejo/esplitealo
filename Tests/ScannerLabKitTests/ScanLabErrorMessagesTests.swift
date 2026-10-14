import EsplitealoCore
import XCTest
@testable import ScannerLabKit

final class ScanLabErrorMessagesTests: XCTestCase {
    func testNoTextFoundMessage() {
        XCTAssertEqual(
            ScanLabErrorMessages.receiptScanMessage(.noTextFound),
            "No text was recognized on this image."
        )
    }

    func testImageTooSmallWithoutHeight() {
        XCTAssertTrue(
            ScanLabErrorMessages.receiptScanMessage(.imageTooSmallOrUnreadable(minWordHeight: nil))
                .contains("too small")
        )
    }

    func testReceiptTooLongMessageIncludesAspectRatio() {
        let message = ScanLabErrorMessages.receiptScanMessage(
            .receiptTooLongForSinglePhoto(aspectRatio: 5.2, maximumAspectRatio: 4)
        )
        XCTAssertTrue(message.contains("5.20"))
        XCTAssertTrue(message.contains("4.00"))
    }
}

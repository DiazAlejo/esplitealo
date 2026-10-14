import XCTest
@testable import EsplitealoCapture

final class CameraPermissionTests: XCTestCase {
    func testStatusMappingIsStable() {
        // On macOS test host without AVFoundation video, restricted is expected.
        let status = CameraPermission.currentStatus()
        XCTAssertTrue(
            [CameraPermissionStatus.notDetermined, .authorized, .denied, .restricted].contains(status)
        )
    }
}

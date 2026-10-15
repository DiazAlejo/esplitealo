#if DEBUG
import EsplitealoCapture
import EsplitealoCore
import Foundation

extension ScanFlow {
    /// A flow for previews and snapshot tests: an in-memory bill, its own router, a camera that is `camera`, and
    /// a scanner that returns the sample receipt.
    static func preview(camera: CameraPermissionStatus = .authorized, router: AppRouter = AppRouter()) -> ScanFlow {
        let draft = SampleBill.scannedDraft()
        let services = Services(
            cameraStatus: { camera },
            requestCameraAccess: { camera },
            isCameraSupported: { true },
            scan: { _ in draft },
            fixture: nil
        )
        return ScanFlow(store: BillStore.live(arguments: ["--uitesting"]), router: router, services: services)
    }
}
#endif

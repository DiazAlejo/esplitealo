import Foundation

#if os(iOS)
import AVFoundation
#endif

public enum CameraPermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public enum CameraPermission {
    /// Reads `AVCaptureDevice` authorization without prompting.
    public static func currentStatus() -> CameraPermissionStatus {
        #if os(iOS)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
        #else
        return .restricted
        #endif
    }

    /// Requests access when `.notDetermined`; does nothing when already decided.
    public static func requestAccessIfNeeded() async -> CameraPermissionStatus {
        #if os(iOS)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
        #else
        return .restricted
        #endif
    }
}

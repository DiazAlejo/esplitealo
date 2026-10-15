import EsplitealoCapture
import EsplitealoScanning
import Foundation

/// Where the receipt image comes from.
enum ScanSource: Equatable {
    case camera
    case photoLibrary
}

/// Why the camera cannot be used, and what the screen says about it.
enum CaptureBlock: Equatable {
    /// The user said no: Settings can change that.
    case denied
    /// Parental controls or a device without a usable camera: Settings cannot help, photos still can.
    case unavailable

    var title: LocalizedStringResource {
        switch self {
        case .denied: .captureDeniedTitle
        case .unavailable: .captureUnavailableTitle
        }
    }

    var body: LocalizedStringResource {
        switch self {
        case .denied: .captureDeniedBody
        case .unavailable: .captureUnavailableBody
        }
    }

    var offersSettings: Bool { self == .denied }
}

/// What went wrong with a scan, in the user's terms. Every case has its own words; none blames the user.
enum ScanFailure: Equatable, CaseIterable {
    /// Nothing usable was read: blurry, cut off, too small, or not a receipt.
    case unreadable
    /// The document camera returned more than one page.
    case tooManyPages
    /// The receipt is too tall for the one-photo scan.
    case tooLong
    /// The picked photo could not be opened.
    case photoNotLoaded
    /// The system camera itself failed.
    case cameraFailed

    var title: LocalizedStringResource {
        switch self {
        case .unreadable: .processingFailTitle
        case .tooManyPages: .processingTooManyPagesTitle
        case .tooLong: .processingTooLongTitle
        case .photoNotLoaded: .processingPhotoFailedTitle
        case .cameraFailed: .processingCameraFailedTitle
        }
    }

    var body: LocalizedStringResource {
        switch self {
        case .unreadable: .processingFailBody
        case .tooManyPages: .processingTooManyPagesBody
        case .tooLong: .processingTooLongBody
        case .photoNotLoaded: .processingPhotoFailedBody
        case .cameraFailed: .processingCameraFailedBody
        }
    }

    /// "Elegir otra foto" is the way out of a camera failure; after a photo failure it would repeat "Tratar otra vez".
    func offersAnotherPhoto(from source: ScanSource) -> Bool {
        source == .camera
    }

    init(_ error: ReceiptScanError) {
        switch error {
        case .receiptTooLongForSinglePhoto: self = .tooLong
        case .noTextFound, .imageTooSmallOrUnreadable, .recognitionUnavailable: self = .unreadable
        }
    }

    init(_ error: DocumentCameraError) {
        switch error {
        case .tooManyPages: self = .tooManyPages
        case .noImage, .cancelled: self = .unreadable
        case .failed: self = .cameraFailed
        }
    }

    init(_ error: PhotoImportError) {
        self = .photoNotLoaded
    }

    /// Whatever else the pipeline throws is, for the user, a receipt that could not be read.
    init(_ error: any Error) {
        if let error = error as? ReceiptScanError {
            self.init(error)
        } else {
            self = .unreadable
        }
    }
}

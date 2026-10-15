import EsplitealoCore
import Foundation

public enum ReceiptScanError: Error, Equatable, Sendable {
    /// Vision returned no text observations.
    case noTextFound
    /// Image dimensions are too small, or recognized word boxes are with a median height under 12 px (OCR degrades below ~20 px).
    case imageTooSmallOrUnreadable(minWordHeight: Double?)
    /// One-photo MVP: aspect ratio (height ÷ width) exceeds the supported limit for a single capture.
    case receiptTooLongForSinglePhoto(aspectRatio: Double, maximumAspectRatio: Double)
    /// Text recognition is not available on this platform.
    case recognitionUnavailable
}

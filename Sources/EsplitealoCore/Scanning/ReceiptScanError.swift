import Foundation

public enum ReceiptScanError: Error, Equatable, Sendable {
    /// Vision returned no text observations.
    case noTextFound
    /// Image dimensions are too small, or recognized word boxes are shorter than about 20 px (OCR degrades below that).
    case imageTooSmallOrUnreadable(minWordHeight: Double?)
    /// One-photo MVP: aspect ratio (height ÷ width) exceeds the supported limit for a single capture.
    case receiptTooLongForSinglePhoto(aspectRatio: Double, maximumAspectRatio: Double)
}

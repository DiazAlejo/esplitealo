import EsplitealoCore
import Foundation

public enum ScanLabErrorMessages {
    public static func message(for error: Error) -> String {
        if let scan = error as? ReceiptScanError {
            return receiptScanMessage(scan)
        }
        return String(describing: error)
    }

    public static func receiptScanMessage(_ error: ReceiptScanError) -> String {
        switch error {
        case .noTextFound:
            return "No text was recognized on this image."
        case .imageTooSmallOrUnreadable(let minWordHeight):
            if let minWordHeight {
                return "Image is too small or unreadable (smallest word height \(formatPixels(minWordHeight)) px)."
            }
            return "Image is too small or unreadable."
        case .receiptTooLongForSinglePhoto(let aspectRatio, let maximumAspectRatio):
            return String(
                format: "Receipt is too tall for a single photo (aspect %.2f, limit %.2f).",
                aspectRatio,
                maximumAspectRatio
            )
        case .recognitionUnavailable:
            return "On-device text recognition is not available on this platform."
        }
    }

    private static func formatPixels(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

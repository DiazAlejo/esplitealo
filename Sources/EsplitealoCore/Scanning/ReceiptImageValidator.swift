import CoreGraphics
import Foundation

enum ReceiptImageValidator {
    /// Reject when median word height falls below this (research §6.5: accuracy breaks near 13 px; quality degrades below ~20 px).
    static let minimumMedianWordHeight: Double = 12

    static func validateDimensions(
        width: Int,
        height: Int,
        maximumSinglePhotoAspectRatio: Double
    ) throws {
        guard width >= 64, height >= 64 else {
            throw ReceiptScanError.imageTooSmallOrUnreadable(minWordHeight: nil)
        }
        let aspect = Double(height) / Double(width)
        if aspect > maximumSinglePhotoAspectRatio {
            throw ReceiptScanError.receiptTooLongForSinglePhoto(
                aspectRatio: aspect,
                maximumAspectRatio: maximumSinglePhotoAspectRatio
            )
        }
    }

    static func validateRecognizedText(_ text: RecognizedText) throws {
        guard !text.lines.isEmpty else {
            throw ReceiptScanError.noTextFound
        }
        let heights = text.lines.flatMap(\.words).map(\.rect.height)
        guard let median = median(heights), median >= minimumMedianWordHeight else {
            let minHeight = heights.min()
            throw ReceiptScanError.imageTooSmallOrUnreadable(minWordHeight: minHeight)
        }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}

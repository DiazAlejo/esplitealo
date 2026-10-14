import EsplitealoCore
import Foundation

/// Marks CORD receipts outside Esplitealo product scope (Spanish/English, Puerto Rico, USD).
public enum CordBenchmarkScope {
    /// Receipts with Indonesian rupiah-style amounts or IDR labels are excluded from headline PR metrics.
    public static func isInProductScope(groundTruthJSON: String, groundTruth: ReceiptGroundTruth) -> Bool {
        let lower = groundTruthJSON.lowercased()
        if lower.contains("idr") || lower.contains("rupiah") { return false }
        if lower.contains("cash idr") { return false }
        if hasThousandsSeparatorPrice(in: groundTruthJSON) { return false }
        if groundTruth.items.contains(where: { $0.lineTotalMinor > 9_999 }) { return false }
        if let total = groundTruth.totalMinor, total > 99_999 { return false }
        return true
    }

    private static func hasThousandsSeparatorPrice(in json: String) -> Bool {
        let pattern = #""\d{1,3}[.,]\d{3}""#
        return json.range(of: pattern, options: .regularExpression) != nil
    }
}

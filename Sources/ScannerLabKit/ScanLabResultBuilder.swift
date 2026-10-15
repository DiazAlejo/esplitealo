import EsplitealoCore
import EsplitealoScanning
import Foundation

public enum ScanLabResultBuilder {
    public static func display(
        from result: ReceiptScanResult,
        parser: ReceiptParser = ReceiptParser(),
        ocrDurationMilliseconds: Int? = nil
    ) -> ScanLabDisplayResult {
        let recognized = result.recognizedText
        let draft = result.draft

        let lines = recognized.lines.map { line in
            ScanLabRecognizedLineDisplay(
                text: line.text,
                confidenceLabel: String(format: "%.0f%%", line.confidence * 100)
            )
        }

        let rebuiltRows = parser.rebuiltRowDescriptions(from: recognized)

        let items = draft.items.map { item in
            ScanLabItemDisplay(
                description: item.name,
                quantity: item.quantity,
                priceLabel: ScanLabMoneyFormat.dollars(fromMinorUnits: item.lineTotal.minorUnits),
                flags: item.flags.map(\.rawValue).sorted()
            )
        }

        let flagged = draft.items.compactMap { item -> String? in
            guard !item.flags.isEmpty || item.lineTotal.needsAttention else { return nil }
            let flagText = item.flags.map(\.rawValue).sorted().joined(separator: ", ")
            let attention = item.lineTotal.needsAttention ? "needsAttention" : ""
            let suffix = [flagText, attention].filter { !$0.isEmpty }.joined(separator: "; ")
            return suffix.isEmpty ? item.name : "\(item.name) (\(suffix))"
        }

        let reconciliationSummary = draft.reconciles
            ? "Reconciles with printed totals."
            : "Does not reconcile with printed totals."

        return ScanLabDisplayResult(
            recognizedLines: lines,
            rebuiltRows: rebuiltRows,
            items: items,
            subtotal: amountDisplay(draft.subtotal),
            tax: amountDisplay(draft.tax),
            tip: amountDisplay(draft.tip),
            total: amountDisplay(draft.total),
            reconciles: draft.reconciles,
            reconciliationSummary: reconciliationSummary,
            issues: draft.issues.map(ScanLabIssueMessages.describe),
            flaggedRows: flagged,
            ocrDurationMilliseconds: ocrDurationMilliseconds
        )
    }

    private static func amountDisplay(_ amount: DraftAmount?) -> ScanLabAmountDisplay? {
        guard let amount else { return nil }
        return ScanLabAmountDisplay(
            label: ScanLabMoneyFormat.dollars(fromMinorUnits: amount.minorUnits),
            needsAttention: amount.needsAttention
        )
    }
}

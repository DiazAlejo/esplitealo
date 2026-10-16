import Foundation

/// Something the parser was unsure about, kept with the bill so the Review screen can say so. It is a record of what
/// the scan did, not a verdict: the user retires it by fixing the row or accepting it (`isDismissed`), and a dismissed
/// warning stays in the draft rather than disappearing.
///
/// Only what is a fact about the scan is stored: a price that could not be read (`unparsedPriceRow`) and a number
/// format that was guessed (`numberFormatGuessed`). The other `ReceiptIssue`s are recomputed from the receipt after
/// every edit (`ReceiptDraft.reconciliation`, no items, no printed total), so a stored copy would go stale.
public struct ReceiptWarning: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var issue: ReceiptIssue
    /// The label printed on the row, when the parser knew it ("Soda", "IVU").
    public var rowLabel: String?
    /// Where the row sits on the scanned image, when known.
    public var sourceRect: PixelRect?
    /// The item the warning is about, when the unreadable price still produced a row.
    public var itemID: UUID?
    public var isDismissed: Bool

    public init(
        id: UUID = UUID(),
        issue: ReceiptIssue,
        rowLabel: String? = nil,
        sourceRect: PixelRect? = nil,
        itemID: UUID? = nil,
        isDismissed: Bool = false
    ) {
        self.id = id
        self.issue = issue
        self.rowLabel = rowLabel
        self.sourceRect = sourceRect
        self.itemID = itemID
        self.isDismissed = isDismissed
    }
}

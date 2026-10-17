import EsplitealoCore
import Foundation
import Observation

/// Why the parser wants a second look at a row. The row says it in words; colour alone never carries it.
enum ItemFlagReason: Equatable, Sendable {
    case priceOnAnotherLine
    case quantityMismatch
    case missingPrice
    case formatGuessed
    case needsLook

    /// The most specific reason wins when the parser raised several flags.
    init?(flags: Set<ItemFlag>, priceNeedsAttention: Bool) {
        if flags.contains(.quantityMismatch) {
            self = .quantityMismatch
        } else if flags.contains(.zeroPrice) {
            self = .missingPrice
        } else if flags.contains(.priceOnNextRow) || flags.contains(.priceOnPreviousRow) {
            self = .priceOnAnotherLine
        } else if flags.contains(.formatGuessed) {
            self = .formatGuessed
        } else if flags.contains(.needsReview) || priceNeedsAttention {
            self = .needsLook
        } else {
            return nil
        }
    }
}

/// The amounts printed at the bottom of the receipt that the user can edit. `service` is the gratuity or service
/// charge line (`ReceiptDraft.tip`).
enum ReceiptField: String, CaseIterable, Sendable, Identifiable {
    case subtotal, tax, service, total

    var id: String { rawValue }
    /// Subtotal, tax and service may be absent from a receipt; the printed total may not.
    var isOptional: Bool { self != .total }
}

/// The logic of the Review receipt screen: what is flagged, what the reconciliation says after every edit, and when
/// the user may continue. It reads the bill from the `BillStore` and changes it only through `store.update`, so every
/// edit is autosaved. It never changes the printed total to match the items, and it never drops a row.
@MainActor @Observable
final class ReceiptReviewModel {
    static let quantityRange = 1 ... 99

    @ObservationIgnored private let store: BillStore

    init(store: BillStore) {
        self.store = store
    }

    /// Reaching the screen without a bill (typing the receipt in by hand) starts an empty one.
    func startBillIfNeeded() {
        if store.session == nil { store.startNewBill() }
    }

    // MARK: Reading

    private var draft: ReceiptDraft { store.session?.draft ?? ReceiptDraft() }

    struct ItemRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        let quantity: Int
        let unitPriceCents: Int
        let lineTotalCents: Int
        let flag: ItemFlagReason?
    }

    struct AdjustmentRow: Identifiable, Equatable {
        let id: Int
        let label: String
        let cents: Int
    }

    /// Every row of the receipt, in the order printed.
    var items: [ItemRow] {
        draft.items.map { item in
            ItemRow(
                id: item.id,
                name: item.name,
                quantity: item.quantity,
                unitPriceCents: item.unitPrice?.minorUnits ?? item.lineTotal.minorUnits / item.quantity,
                lineTotalCents: item.lineTotal.minorUnits,
                flag: ItemFlagReason(
                    flags: item.flags,
                    priceNeedsAttention: item.lineTotal.needsAttention || (item.unitPrice?.needsAttention ?? false)
                )
            )
        }
    }

    /// Something the scan was unsure about that is not a row to fix: a price it could not read, or a guessed number
    /// format. Shown until the user accepts it, and kept in the bill after that.
    struct WarningRow: Identifiable, Equatable {
        enum Kind: Equatable {
            case unreadablePrice(text: String)
            case formatGuessed
        }

        let id: UUID
        let kind: Kind
        /// The label printed on the unreadable row, when the parser knew it.
        let rowLabel: String?
    }

    /// The warnings the user has not yet accepted, in the order the scan found them. Unreadable prices and a guessed
    /// format only: a mismatch, no items and no printed total are already the banner's and the empty state's job.
    var warnings: [WarningRow] {
        draft.activeWarnings.compactMap { warning in
            switch warning.issue {
            case let .unparsedPriceRow(text):
                WarningRow(id: warning.id, kind: .unreadablePrice(text: text), rowLabel: warning.rowLabel)
            case .numberFormatGuessed:
                WarningRow(id: warning.id, kind: .formatGuessed, rowLabel: nil)
            case .itemsDoNotMatchSubtotal, .totalsDoNotAddUp, .noTotalFound, .noItemsFound:
                nil
            }
        }
    }

    var flaggedItems: [ItemRow] { items.filter { $0.flag != nil } }
    var plainItems: [ItemRow] { items.filter { $0.flag == nil } }

    /// Parser rows that are not items (discounts). The bill cannot be shared while any remain.
    var adjustments: [AdjustmentRow] {
        draft.adjustments.enumerated().map { AdjustmentRow(id: $0.offset, label: $0.element.label, cents: $0.element.amount.minorUnits) }
    }

    /// The sum the reconciliation compares with the printed subtotal: items plus adjustments.
    var itemsSumCents: Int { store.session?.netItemsSubtotalCents ?? 0 }

    /// Subtotal + tax + service as printed, for the note under a total that does not add up.
    var subtotalPlusExtrasCents: Int {
        (draft.subtotal?.minorUnits ?? 0) + (draft.tax?.minorUnits ?? 0) + (draft.tip?.minorUnits ?? 0)
    }

    var showsServiceRow: Bool { draft.tip != nil }

    func amountCents(_ field: ReceiptField) -> Int? {
        switch field {
        case .subtotal: draft.subtotal?.minorUnits
        case .tax: draft.tax?.minorUnits
        case .service: draft.tip?.minorUnits
        case .total: draft.total?.minorUnits
        }
    }

    // MARK: Reconciliation

    enum Status: Equatable {
        case noItems
        case balanced
        case itemsDoNotMatchSubtotal(itemsCents: Int, subtotalCents: Int)
        case totalsDoNotAddUp(expectedCents: Int, printedCents: Int, includesService: Bool)
        case missingTotal

        var differenceCents: Int? {
            switch self {
            case let .itemsDoNotMatchSubtotal(items, subtotal): abs(items - subtotal)
            case let .totalsDoNotAddUp(expected, printed, _): abs(expected - printed)
            case .noItems, .balanced, .missingTotal: nil
            }
        }

        var isBalanced: Bool { self == .balanced }
    }

    /// The first thing that does not add up, recomputed from the receipt after every edit.
    var status: Status {
        let draft = draft
        guard !draft.items.isEmpty else { return .noItems }
        switch draft.reconciliation.primaryIssue {
        case let .itemsDoNotMatchSubtotal(items, printed):
            return .itemsDoNotMatchSubtotal(itemsCents: items, subtotalCents: printed)
        case let .totalsDoNotAddUp(expected, printed):
            return .totalsDoNotAddUp(expectedCents: expected, printedCents: printed, includesService: draft.tip != nil)
        case nil:
            return draft.total == nil ? .missingTotal : .balanced
        }
    }

    /// Whether the row of an amount is marked as the one to check.
    func needsAttention(_ field: ReceiptField) -> Bool {
        let draft = draft
        guard !draft.items.isEmpty else { return false }
        let issues = draft.reconciliation.issues
        let itemsMismatch = issues.contains { if case .itemsDoNotMatchSubtotal = $0 { true } else { false } }
        let totalsMismatch = issues.contains { if case .totalsDoNotAddUp = $0 { true } else { false } }
        switch field {
        case .subtotal: return itemsMismatch && draft.subtotal != nil
        case .total: return draft.total == nil || totalsMismatch || (itemsMismatch && draft.subtotal == nil)
        case .tax, .service: return false
        }
    }

    // MARK: Editing items

    enum ItemInputError: Error, Equatable {
        case missingName
        case invalidPrice
    }

    private func validated(name: String, priceText: String) -> Result<(name: String, cents: Int), ItemInputError> {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .failure(.missingName) }
        guard let cents = MoneyInput.cents(from: priceText) else { return .failure(.invalidPrice) }
        return .success((name, cents))
    }

    private func clamped(_ quantity: Int) -> Int {
        min(max(quantity, Self.quantityRange.lowerBound), Self.quantityRange.upperBound)
    }

    /// `priceText` is the price of one unit; the line total is that times `quantity`.
    @discardableResult
    func addItem(name: String, priceText: String, quantity: Int) -> ItemInputError? {
        switch validated(name: name, priceText: priceText) {
        case let .failure(error):
            return error
        case let .success((name, cents)):
            edit { session in
                session.applyDraft(ReceiptDraftEditing.addItem(to: session.draft, name: name, unitPriceCents: cents, quantity: clamped(quantity)))
            }
            return nil
        }
    }

    /// Saving a row is the user's confirmation, so the parser's flags on it are cleared.
    @discardableResult
    func updateItem(id: UUID, name: String, priceText: String, quantity: Int) -> ItemInputError? {
        switch validated(name: name, priceText: priceText) {
        case let .failure(error):
            return error
        case let .success((name, cents)):
            edit { session in
                var updated = ReceiptDraftEditing.updateItem(in: session.draft, itemID: id, name: name, unitPriceCents: cents, quantity: clamped(quantity))
                if let index = updated.items.firstIndex(where: { $0.id == id }) {
                    updated.items[index].flags = []
                    updated.items[index].lineTotal.needsAttention = false
                    updated.items[index].unitPrice?.needsAttention = false
                }
                session.applyDraft(ReceiptDraftEditing.dismissWarnings(in: updated, forItem: id))
            }
            return nil
        }
    }

    func deleteItem(id: UUID) {
        edit { session in
            session.applyDraft(ReceiptDraftEditing.deleteItem(in: session.draft, itemID: id))
        }
    }

    func removeAdjustment(at index: Int) {
        edit { session in
            var updated = session.draft
            guard updated.adjustments.indices.contains(index) else { return }
            updated.adjustments.remove(at: index)
            session.applyDraft(updated)
        }
    }

    /// The user read the warning and accepts it. It stays in the bill, retired. This is not an edit of the receipt, so
    /// it does not withdraw a "continue anyway".
    func dismissWarning(id: UUID) {
        store.update { session in
            session.applyDraft(ReceiptDraftEditing.dismissWarning(in: session.draft, id: id))
        }
    }

    // MARK: Editing amounts

    enum AmountInputError: Equatable {
        case invalidAmount
    }

    /// An empty field clears an optional amount (the receipt does not have it); the printed total cannot be cleared.
    @discardableResult
    func setAmount(_ field: ReceiptField, text: String) -> AmountInputError? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cents: Int?
        if trimmed.isEmpty {
            guard field.isOptional else { return .invalidAmount }
            cents = nil
        } else {
            guard let parsed = MoneyInput.cents(from: trimmed) else { return .invalidAmount }
            cents = parsed
        }
        edit { session in
            let draft = session.draft
            let updated: ReceiptDraft = switch field {
            case .subtotal: ReceiptDraftEditing.setSubtotal(draft, cents: cents)
            case .tax: ReceiptDraftEditing.setTax(draft, cents: cents)
            case .service: ReceiptDraftEditing.setReceiptTip(draft, cents: cents)
            case .total: ReceiptDraftEditing.setTotal(draft, cents: cents)
            }
            session.applyDraft(updated)
        }
        return nil
    }

    // MARK: Continuing

    var canContinue: Bool { !draft.items.isEmpty }

    enum ContinueDecision: Equatable {
        case noItems
        case proceed
        /// The receipt does not add up (or has no printed total): ask first. `nil` when there is no total to compare.
        case confirmMismatch(differenceCents: Int?)
    }

    func requestContinue() -> ContinueDecision {
        switch status {
        case .noItems: .noItems
        case .balanced: .proceed
        case .missingTotal, .itemsDoNotMatchSubtotal, .totalsDoNotAddUp:
            store.session?.mismatchAcknowledged == true ? .proceed : .confirmMismatch(differenceCents: status.differenceCents)
        }
    }

    /// The user chose to continue although the receipt does not add up. Sharing stays blocked until it does.
    func confirmMismatch() {
        store.update { $0.acknowledgeMismatch() }
    }

    // MARK: Store

    /// Any change to the receipt withdraws an earlier "continue anyway": the numbers it agreed to are gone.
    private func edit(_ change: (inout BillSession) -> Void) {
        store.update { session in
            let before = session.draft
            change(&session)
            if session.draft != before { session.mismatchAcknowledged = false }
        }
    }
}

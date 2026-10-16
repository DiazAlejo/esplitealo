import EsplitealoCore
import Foundation
import Observation

/// The logic of the Totals screen (step 5): the tip settings, who owes what (from the calculator, never recomputed
/// here), the stray cents and who got them, when sharing is allowed, and the share text. It reads the bill from the
/// `BillStore` and changes only the tip, through `store.update`, so every change is autosaved.
///
/// Money is integer cents everywhere. Nothing here changes how a bill is calculated: the numbers come from
/// `BillSession` and `BillCalculator`, and this type only arranges them for the screen.
@MainActor @Observable
final class TotalsViewModel {
    /// The percentage buttons, as a share of the pre-tax subtotal (or the total with tax, see `usesPostTaxTip`).
    static let tipPresets = [15, 18, 20]
    /// What the custom tip's − and + move it by.
    static let tipStep = 50

    @ObservationIgnored private let store: BillStore
    /// The basis a percentage gets after the tip was a custom amount, which has no basis of its own.
    @ObservationIgnored private var rememberedBasis: TipBasis = .preTaxSubtotal

    init(store: BillStore) {
        self.store = store
    }

    private var session: BillSession { store.session ?? BillSession(draft: ReceiptDraft()) }

    // MARK: Tip

    enum TipSelection: Equatable {
        case preset(Int)
        /// Also what a percentage that is not one of the buttons looks like (0% on a receipt with service charge).
        case custom
    }

    /// What the receipt's service charge says about the tip.
    enum TipHint: Equatable {
        case none
        /// The tip is $0.00 because the receipt already has a service charge.
        case serviceIncluded(serviceCents: Int)
        /// There is a service charge and a tip: check it is not tipping twice.
        case serviceDouble(serviceCents: Int)
    }

    var tipSelection: TipSelection {
        switch session.tip {
        case let .percentage(percent, _): Self.tipPresets.contains(percent) ? .preset(percent) : .custom
        case .custom: .custom
        }
    }

    var usesPostTaxTip: Bool {
        get {
            if case .percentage(_, .postTaxTotal) = session.tip { return true }
            return rememberedBasis == .postTaxTotal && tipSelection == .custom
        }
        set {
            let basis: TipBasis = newValue ? .postTaxTotal : .preTaxSubtotal
            rememberedBasis = basis
            guard case let .percentage(percent, _) = session.tip else { return }
            store.update { $0.tip = .percentage(percent: percent, basis: basis) }
        }
    }

    /// The amount the tip percentage applies to: the subtotal before tax, or the total with tax.
    var tipBaseCents: Int {
        let session = session
        return session.netItemsSubtotalCents + (usesPostTaxTip ? (session.draft.tax?.minorUnits ?? 0) : 0)
    }

    var tipCents: Int { session.sessionTipCents }

    func selectPreset(_ percent: Int) {
        typedCustomTip = nil
        customTipIsInvalid = false
        let basis = currentBasis
        store.update { $0.tip = .percentage(percent: percent, basis: basis) }
    }

    /// "Otra": the custom amount starts at what the tip was, so nothing jumps.
    func selectCustom() {
        if case let .percentage(_, basis) = session.tip { rememberedBasis = basis }
        typedCustomTip = nil
        customTipIsInvalid = false
        if case .custom = session.tip { return }
        let cents = tipCents
        store.update { $0.tip = .custom(cents: cents) }
    }

    private var currentBasis: TipBasis {
        if case let .percentage(_, basis) = session.tip { return basis }
        return rememberedBasis
    }

    @ObservationIgnored private var typedCustomTip: String?
    private(set) var customTipIsInvalid = false

    /// What the amount field shows: what was typed, or the tip in dollars and cents.
    var customTipText: String {
        get { typedCustomTip ?? MoneyInput.editableText(cents: tipCents) }
        set {
            typedCustomTip = newValue
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                customTipIsInvalid = false
                return
            }
            guard let cents = MoneyInput.cents(from: trimmed) else {
                customTipIsInvalid = true
                return
            }
            customTipIsInvalid = false
            if case .custom(cents) = session.tip { return }
            if case let .percentage(_, basis) = session.tip { rememberedBasis = basis }
            store.update { $0.tip = .custom(cents: cents) }
        }
    }

    /// The field lost focus: a half-typed or wrong amount goes back to the tip that is in effect.
    func endCustomTipEditing() {
        typedCustomTip = nil
        customTipIsInvalid = false
    }

    var canDecreaseTip: Bool { tipCents > 0 }
    var canIncreaseTip: Bool { tipCents < MoneyInput.maximumCents }

    func stepCustomTip(by delta: Int) {
        let cents = min(max(0, tipCents + delta), MoneyInput.maximumCents)
        typedCustomTip = nil
        customTipIsInvalid = false
        if case let .percentage(_, basis) = session.tip { rememberedBasis = basis }
        store.update { $0.tip = .custom(cents: cents) }
    }

    var tipHint: TipHint {
        let service = serviceCents
        guard service > 0 else { return .none }
        return tipCents == 0 ? .serviceIncluded(serviceCents: service) : .serviceDouble(serviceCents: service)
    }

    /// The gratuity the receipt already has: a service charge, or a tip line printed on it. Either way it is shared
    /// in proportion to the items, so the screen shows both as "Servicio".
    private var serviceCents: Int { session.serviceChargeCents + session.receiptTipOnBillCents }

    // MARK: Summary

    struct Summary: Equatable {
        let subtotalCents: Int
        let taxCents: Int
        let serviceCents: Int
        let tipCents: Int
        /// What the bill comes to with the tip: the receipt's printed total plus the tip.
        let billTotalCents: Int
        var showsService: Bool { serviceCents > 0 }
    }

    var summary: Summary {
        let session = session
        let tip = session.sessionTipCents
        return Summary(
            subtotalCents: session.netItemsSubtotalCents,
            taxCents: session.draft.tax?.minorUnits ?? 0,
            serviceCents: serviceCents,
            tipCents: tip,
            billTotalCents: session.printedReceiptTotalCents.map { $0 + tip } ?? session.confirmedBillTotalCents
        )
    }

    // MARK: Who owes what

    struct ItemLine: Equatable, Identifiable {
        let id: UUID
        let name: String
        let cents: Int
        /// How many people share it (1 when it is only theirs).
        let splitWays: Int
    }

    struct PersonRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        /// The person's colour: their position at the table.
        let colorIndex: Int
        let itemsCents: Int
        let taxCents: Int
        let serviceCents: Int
        let tipCents: Int
        let totalCents: Int
        /// Stray cents that landed on this person, from the items, tax, service and tip.
        let roundingCents: Int
        let percent: Int
        let fraction: Double
        let itemLines: [ItemLine]
    }

    var rows: [PersonRow] {
        let session = session
        let breakdowns = session.personBreakdowns
        let total = breakdowns.map(\.totalOwedCents).reduce(0, +)
        return breakdowns.map { breakdown in
            let person = session.participants.first { $0.id == breakdown.participantID }
            let service = breakdown.serviceShareCents + breakdown.receiptTipShareCents
            let strays = breakdown.adjustments.map(\.cents).reduce(0, +)
            return PersonRow(
                id: breakdown.participantID,
                name: person?.name ?? "",
                colorIndex: session.participants.firstIndex { $0.id == breakdown.participantID } ?? 0,
                itemsCents: breakdown.itemSubtotalCents,
                taxCents: breakdown.taxShareCents,
                serviceCents: service,
                tipCents: breakdown.tipShareCents,
                totalCents: breakdown.totalOwedCents,
                roundingCents: strays,
                percent: total > 0 ? Int((Double(breakdown.totalOwedCents) / Double(total) * 100).rounded()) : 0,
                fraction: total > 0 ? Double(breakdown.totalOwedCents) / Double(total) : 0,
                itemLines: itemLines(for: breakdown, in: session)
            )
        }
    }

    /// The person's items with what each cost them, in receipt order. A quantity line adds up its units.
    private func itemLines(for breakdown: BillSession.PersonBreakdown, in session: BillSession) -> [ItemLine] {
        let valid = Set(session.participants.map(\.id))
        var lines: [ItemLine] = []
        for item in session.draft.items {
            var cents = 0
            var ways = 0
            for unit in 0 ..< item.quantity {
                let assignees = Set(Self.assignees(of: item.id, unit: unit, in: session).filter(valid.contains))
                guard assignees.contains(breakdown.participantID) else { continue }
                let price = Self.unitPrice(lineTotal: item.lineTotal.minorUnits, quantity: item.quantity, unit: unit)
                let stray = breakdown.adjustments.contains { $0.pool == .itemUnit(itemID: item.id, unitIndex: unit) } ? 1 : 0
                cents += price / assignees.count + stray
                ways = max(ways, assignees.count)
            }
            if ways > 0 { lines.append(ItemLine(id: item.id, name: item.name, cents: cents, splitWays: ways)) }
        }
        return lines
    }

    // MARK: Rounding

    enum RoundingNote: Equatable {
        enum Pool: Hashable { case tax, service, tip }

        /// An item that did not divide evenly: "Surtido $14.00 ÷ 3 leaves 2¢. Ana and Ben pay 1¢ more."
        case item(name: String, priceCents: Int, ways: Int, leftoverCents: Int, names: [String])
        /// Cents left over when tax, the service charge or the tip were shared.
        case pool(Pool, cents: Int, names: [String])
    }

    var hasRounding: Bool { !roundingNotes.isEmpty }

    /// Every stray cent and who got it, in the order of the receipt, then tax, service and tip. The sum of the notes
    /// is the sum of the `roundingCents` of the people.
    var roundingNotes: [RoundingNote] {
        let session = session
        let ordered = session.participants.sorted { $0.orderIndex < $1.orderIndex }
        let adjustments = session.splitResult.allAdjustments
        let valid = Set(session.participants.map(\.id))
        var notes: [RoundingNote] = []

        for item in session.draft.items {
            for unit in 0 ..< item.quantity {
                let pool = RoundingAdjustment.Pool.itemUnit(itemID: item.id, unitIndex: unit)
                let paid = adjustments.filter { $0.pool == pool }
                guard !paid.isEmpty else { continue }
                let ways = Set(Self.assignees(of: item.id, unit: unit, in: session).filter(valid.contains)).count
                let names = ordered.filter { person in paid.contains { $0.participantID == person.id } }.map(\.name)
                notes.append(.item(
                    name: item.name,
                    priceCents: Self.unitPrice(lineTotal: item.lineTotal.minorUnits, quantity: item.quantity, unit: unit),
                    ways: ways,
                    leftoverCents: paid.map(\.cents).reduce(0, +),
                    names: names
                ))
            }
        }

        // The service charge and a tip printed on the receipt are shown together as "Servicio", and a receipt has
        // one or the other.
        let poolAdjustments = session.personBreakdowns.flatMap(\.adjustments)
        let pools: [(RoundingNote.Pool, [RoundingAdjustment])] = [
            (.tax, adjustments.filter { $0.pool == .tax }),
            (.tip, adjustments.filter { $0.pool == .tip }),
            (.service, poolAdjustments.filter { $0.pool == .serviceCharge || $0.pool == .printedTip }),
        ]
        for (label, paid) in pools where !paid.isEmpty {
            let names = ordered.filter { person in paid.contains { $0.participantID == person.id } }.map(\.name)
            notes.append(.pool(label, cents: paid.map(\.cents).reduce(0, +), names: names))
        }
        return notes
    }

    // MARK: Gating

    enum Status: Equatable {
        /// Units nobody has claimed (and what they cost): the split is not settled.
        case unassigned(items: Int, cents: Int)
        /// The receipt does not add up. `itemsCents` and `subtotalCents` are set when the items disagree with the
        /// printed subtotal.
        case receiptMismatch(differenceCents: Int, itemsCents: Int?, subtotalCents: Int?)
        case missingTotal
        /// Discount rows the app cannot split yet.
        case discountsNotSplit
        /// Every item is free (or there are none) but the bill has tax, tip or a service charge: nobody has items to
        /// split them by.
        case nobodyCarriesCharges
        case reconciled(totalCents: Int)
    }

    var status: Status {
        let session = session
        switch session.shareBlockReason {
        case nil:
            return .reconciled(totalCents: session.confirmedBillTotalCents)
        case .missingPrintedTotal:
            return .missingTotal
        case .discountNeedsManualAdjustment:
            return .discountsNotSplit
        case .noItemsToCarryCharges:
            return .nobodyCarriesCharges
        case .unassignedItems:
            let itemsTotal = session.draft.items.reduce(0) { $0 + $1.lineTotal.minorUnits }
            let assigned = session.personBreakdowns.map(\.itemSubtotalCents).reduce(0, +)
            return .unassigned(items: session.unassignedUnits.count, cents: itemsTotal - assigned)
        case .receiptMismatch:
            switch session.draft.reconciliation.primaryIssue {
            case let .itemsDoNotMatchSubtotal(itemsSum, printed):
                return .receiptMismatch(differenceCents: abs(itemsSum - printed), itemsCents: itemsSum, subtotalCents: printed)
            case let .totalsDoNotAddUp(expected, printed):
                return .receiptMismatch(differenceCents: abs(expected - printed), itemsCents: nil, subtotalCents: nil)
            case nil:
                let expected = (session.printedReceiptTotalCents ?? 0) + session.sessionTipCents
                return .receiptMismatch(differenceCents: abs(session.derivedBillTotalCents - expected), itemsCents: nil, subtotalCents: nil)
            }
        }
    }

    /// Sharing needs every item marked and a receipt that adds up: a mismatch the user confirmed on the review screen
    /// lets them mark items and see totals, but never share.
    var canShare: Bool { session.canShare }

    /// The reason sharing is blocked is in the receipt, so editing the receipt is the way out.
    var blockedByReceipt: Bool {
        switch status {
        case .receiptMismatch, .missingTotal, .discountsNotSplit, .nobodyCarriesCharges: true
        case .unassigned, .reconciled: false
        }
    }

    // MARK: Sharing

    private(set) var isSharing = false
    private(set) var hasShared = false
    private(set) var sharedPeopleCount = 0
    private(set) var sharedTotalCents = 0

    func requestShare() {
        guard canShare else { return }
        isSharing = true
    }

    func dismissShare() {
        isSharing = false
    }

    /// The sheet is open but the bill changed under it (for example from another screen): nothing stale is shared.
    func closeShareIfBlocked() {
        if isSharing, !canShare { isSharing = false }
    }

    /// The person closed the system share sheet without sending: the preview stays, to try another app.
    func shareCancelled() {}

    /// The system share sheet reported that the text went somewhere.
    func shareCompleted() {
        let rows = rows
        sharedPeopleCount = rows.count
        sharedTotalCents = rows.map(\.totalCents).reduce(0, +)
        isSharing = false
        hasShared = true
    }

    func dismissSuccess() {
        hasShared = false
    }

    /// The bill is done: forget it and its saved draft.
    func startNewBill() {
        isSharing = false
        hasShared = false
        store.finishBill()
    }

    /// The summary that is sent: neutral wording, built by the shared `ShareSummaryBuilder`.
    func shareText(language: ShareLanguage, calendar: Calendar = .current) -> String {
        ShareSummaryBuilder.build(for: session, language: language, calendar: calendar)
    }

    /// The text is sent in the language of the app; anything but English is Spanish, the app's own language.
    static func shareLanguage(for locale: Locale) -> ShareLanguage {
        locale.language.languageCode?.identifier == "en" ? .en : .es
    }

    var merchantName: String { session.merchantName }
    var peopleCount: Int { session.participants.count }
    var people: [(name: String, colorIndex: Int)] {
        session.participants.enumerated().map { ($1.name, $0) }
    }

    // MARK: Helpers

    private static func assignees(of itemID: UUID, unit: Int, in session: BillSession) -> [UUID] {
        session.assignments.first { $0.itemID == itemID && $0.unitIndex == unit }?.participantIDs ?? []
    }

    /// A quantity line is split over its units like the calculator does: the first units take the extra cents.
    private static func unitPrice(lineTotal: Int, quantity: Int, unit: Int) -> Int {
        let count = max(1, quantity)
        return lineTotal / count + (unit < lineTotal % count ? 1 : 0)
    }
}

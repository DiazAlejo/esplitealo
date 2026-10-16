import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The Review receipt screen's logic: what is flagged, what the reconciliation says after every edit, and when the
/// user may continue. The receipt total is never changed to match the items.
@MainActor
struct ReceiptReviewModelTests {
    let drafts = RecordingDraftStore()

    func makeModel(_ session: BillSession? = ReviewSamples.parsedSession()) -> (model: ReceiptReviewModel, store: BillStore) {
        let store = BillStore(draftStore: drafts, clock: ManualClock())
        if let session {
            store.startNewBill(draft: session.draft)
            store.update { $0 = session }
        }
        return (ReceiptReviewModel(store: store), store)
    }

    // MARK: What the screen shows

    @Test func aReceiptThatAddsUpIsBalancedAndHasNothingFlagged() {
        let (model, _) = makeModel(SampleBill.scanned())
        #expect(model.status == .balanced)
        #expect(model.flaggedItems.isEmpty)
        #expect(model.plainItems.count == 8)
        #expect(model.canContinue)
    }

    @Test func rowsFlaggedByTheParserAreShownSeparatelyAndNeverDropped() {
        let (model, store) = makeModel()
        #expect(model.flaggedItems.map(\.id) == [ReviewSamples.flanID])
        #expect(model.plainItems.count == 7)
        #expect(model.flaggedItems.count + model.plainItems.count == store.session?.draft.items.count)
        #expect(model.items.map(\.id) == store.session?.draft.items.map(\.id), "the order of the receipt is kept")
    }

    @Test func everyParserFlagHasAReason() {
        let cases: [(Set<ItemFlag>, ItemFlagReason)] = [
            ([.priceOnNextRow], .priceOnAnotherLine),
            ([.priceOnPreviousRow], .priceOnAnotherLine),
            ([.quantityMismatch], .quantityMismatch),
            ([.zeroPrice], .missingPrice),
            ([.formatGuessed], .formatGuessed),
            ([.needsReview], .needsLook),
            ([.needsReview, .priceOnNextRow], .priceOnAnotherLine),
            ([.quantityMismatch, .formatGuessed, .zeroPrice], .quantityMismatch),
        ]
        for (flags, reason) in cases {
            var draft = SampleBill.scannedDraft()
            draft.items[2].flags = flags
            let (model, _) = makeModel(BillSession(draft: draft))
            #expect(model.flaggedItems.map(\.id) == [draft.items[2].id])
            #expect(model.flaggedItems.first?.flag == reason, "\(flags)")
        }
    }

    @Test func anAmountTheParserWasUnsureAboutIsFlaggedToo() {
        var draft = SampleBill.scannedDraft()
        draft.items[0].lineTotal.needsAttention = true
        let (model, _) = makeModel(BillSession(draft: draft))
        #expect(model.flaggedItems.map(\.id) == [draft.items[0].id])
        #expect(model.flaggedItems.first?.flag == .needsLook)
    }

    @Test func aRowShowsQuantityUnitPriceAndLineTotal() {
        var draft = SampleBill.scannedDraft()
        draft.items[1] = DraftItem(
            id: draft.items[1].id, name: "Medalla", quantity: 3,
            lineTotal: DraftAmount(minorUnits: 1500), unitPrice: DraftAmount(minorUnits: 500)
        )
        let (model, _) = makeModel(BillSession(draft: draft))
        let row = model.items[1]
        #expect(row.quantity == 3)
        #expect(row.unitPriceCents == 500)
        #expect(row.lineTotalCents == 1500)
    }

    @Test func aRowWithoutAUnitPriceDerivesItFromTheLineTotal() {
        var draft = SampleBill.scannedDraft()
        draft.items[0] = DraftItem(id: draft.items[0].id, name: "Jugo", quantity: 2, lineTotal: DraftAmount(minorUnits: 800))
        let (model, _) = makeModel(BillSession(draft: draft))
        #expect(model.items[0].unitPriceCents == 400)
    }

    // MARK: Reconciliation after every edit

    @Test func itemsThatDoNotMatchTheSubtotalReportTheDifference() {
        let (model, _) = makeModel()
        #expect(model.status == .itemsDoNotMatchSubtotal(itemsCents: 11_100, subtotalCents: 10_100))
        #expect(model.status.differenceCents == 1000)
        #expect(model.needsAttention(.subtotal))
        #expect(!model.needsAttention(.total))
        #expect(model.itemsSumCents == 11_100)
    }

    @Test func fixingTheFlaggedPriceMakesTheReceiptBalance() {
        let (model, store) = makeModel()
        #expect(model.updateItem(id: ReviewSamples.flanID, name: "Flan para compartir", priceText: "9.00", quantity: 1) == nil)
        #expect(model.status == .balanced)
        #expect(store.session?.draft.reconciles == true)
        #expect(model.flaggedItems.isEmpty, "saving a row is the user's confirmation, so its flag clears")
    }

    @Test func everyEditRecomputesTheStatus() {
        let (model, _) = makeModel(SampleBill.scanned())
        #expect(model.status == .balanced)
        #expect(model.addItem(name: "Tostones", priceText: "6.00", quantity: 1) == nil)
        #expect(model.status == .itemsDoNotMatchSubtotal(itemsCents: 10_700, subtotalCents: 10_100))
        let added = model.items.last!.id
        model.deleteItem(id: added)
        #expect(model.status == .balanced)
        #expect(model.setAmount(.subtotal, text: "99.00") == nil)
        #expect(model.status == .itemsDoNotMatchSubtotal(itemsCents: 10_100, subtotalCents: 9900))
    }

    @Test func aTotalThatDoesNotAddUpIsFlaggedOnTheTotalAndNeverChanged() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(model.setAmount(.total, text: "110.00") == nil)
        #expect(model.status == .totalsDoNotAddUp(expectedCents: 11_262, printedCents: 11_000, includesService: false))
        #expect(model.status.differenceCents == 262)
        #expect(model.needsAttention(.total))
        #expect(!model.needsAttention(.subtotal))
        #expect(store.session?.draft.total?.minorUnits == 11_000, "the printed total stays what the user typed")
    }

    @Test func aPrintedServiceChargeCountsTowardTheTotal() {
        var draft = SampleBill.scannedDraft()
        draft.tip = DraftAmount(minorUnits: 1515)
        draft.total = DraftAmount(minorUnits: 11_262 + 1515)
        let (model, _) = makeModel(BillSession(draft: draft))
        #expect(model.status == .balanced)
        #expect(model.showsServiceRow)
        #expect(model.setAmount(.total, text: "112.62") == nil)
        #expect(model.status == .totalsDoNotAddUp(expectedCents: 12_777, printedCents: 11_262, includesService: true))
    }

    @Test func aMissingTotalIsNeverTreatedAsZero() {
        var draft = SampleBill.scannedDraft()
        draft.total = nil
        let (model, _) = makeModel(BillSession(draft: draft))
        #expect(model.status == .missingTotal)
        #expect(model.status.differenceCents == nil)
        #expect(model.amountCents(.total) == nil)
        #expect(model.needsAttention(.total))
    }

    @Test func aBillWithoutItemsHasNoStatusToReport() {
        let (model, _) = makeModel(BillSession(draft: ReceiptDraft()))
        #expect(model.status == .noItems)
        #expect(!model.canContinue)
    }

    // MARK: Editing items

    @Test func addingAnItemMultipliesQuantityByTheUnitPrice() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(model.addItem(name: "  Medalla  ", priceText: "4.50", quantity: 2) == nil)
        let item = store.session?.draft.items.last
        #expect(item?.name == "Medalla")
        #expect(item?.quantity == 2)
        #expect(item?.unitPrice?.minorUnits == 450)
        #expect(item?.lineTotal.minorUnits == 900)
    }

    @Test func updatingAnItemKeepsItsPositionAndAssignments() {
        let session = SampleBill.midway()
        let (model, store) = makeModel(session)
        let id = session.draft.items[3].id
        #expect(model.updateItem(id: id, name: "Mofongo", priceText: "23.00", quantity: 1) == nil)
        #expect(store.session?.draft.items[3].name == "Mofongo")
        #expect(store.session?.draft.items[3].lineTotal.minorUnits == 2300)
        // Pruning rebuilds each participant list through a Set, so only the membership is stable.
        func normalized(_ assignments: [ItemAssignment]?) -> [[String]] {
            (assignments ?? []).map { [$0.itemID.uuidString, String($0.unitIndex)] + $0.participantIDs.map(\.uuidString).sorted() }
        }
        #expect(normalized(store.session?.assignments) == normalized(session.assignments))
        #expect(model.items[3].name == "Mofongo")
    }

    @Test func deletingAnItemRemovesItsAssignmentsWithIt() {
        let session = SampleBill.midway()
        let (model, store) = makeModel(session)
        let id = session.draft.items[1].id
        model.deleteItem(id: id)
        #expect(store.session?.draft.items.count == 7)
        #expect(store.session?.assignments.contains { $0.itemID == id } == false)
    }

    @Test func invalidInputIsRejectedAndTheReceiptStaysAsItWas() {
        let (model, store) = makeModel(SampleBill.scanned())
        let before = store.session?.draft
        #expect(model.addItem(name: "   ", priceText: "5.00", quantity: 1) == .missingName)
        #expect(model.addItem(name: "Flan", priceText: "cinco", quantity: 1) == .invalidPrice)
        #expect(model.addItem(name: "Flan", priceText: "", quantity: 1) == .invalidPrice)
        #expect(model.updateItem(id: model.items[0].id, name: "", priceText: "5.00", quantity: 1) == .missingName)
        #expect(model.updateItem(id: model.items[0].id, name: "Jugo", priceText: "-1", quantity: 1) == .invalidPrice)
        #expect(store.session?.draft == before)
    }

    @Test func aFreeItemIsAllowedButAZeroPriceIsFlaggedByTheParserNotByTheForm() {
        let (model, _) = makeModel(SampleBill.scanned())
        #expect(model.addItem(name: "Agua", priceText: "0", quantity: 1) == nil)
    }

    @Test func quantityIsAtLeastOne() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(model.addItem(name: "Medalla", priceText: "5.00", quantity: 0) == nil)
        #expect(store.session?.draft.items.last?.quantity == 1)
        #expect(ReceiptReviewModel.quantityRange == 1 ... 99)
    }

    // MARK: Editing amounts

    @Test func amountsAreReadAsCents() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(model.setAmount(.subtotal, text: "101.50") == nil)
        #expect(model.setAmount(.tax, text: "11,62") == nil)
        #expect(model.setAmount(.total, text: "$113.12") == nil)
        #expect(store.session?.draft.subtotal?.minorUnits == 10_150)
        #expect(store.session?.draft.tax?.minorUnits == 1162)
        #expect(store.session?.draft.total?.minorUnits == 11_312)
    }

    @Test func anEmptyOptionalAmountMeansItIsNotOnTheReceipt() {
        var draft = SampleBill.scannedDraft()
        draft.tip = DraftAmount(minorUnits: 500)
        let (model, store) = makeModel(BillSession(draft: draft))
        #expect(model.setAmount(.service, text: "") == nil)
        #expect(store.session?.draft.tip == nil)
        #expect(model.setAmount(.tax, text: " ") == nil)
        #expect(store.session?.draft.tax == nil)
        #expect(!model.showsServiceRow)
    }

    @Test func theTotalCannotBeLeftEmptyAndBadAmountsAreRejected() {
        let (model, store) = makeModel(SampleBill.scanned())
        let before = store.session?.draft
        #expect(model.setAmount(.total, text: "") == .invalidAmount)
        #expect(model.setAmount(.subtotal, text: "abc") == .invalidAmount)
        #expect(model.setAmount(.tax, text: "1.234") == .invalidAmount)
        #expect(store.session?.draft == before)
    }

    @Test func aServiceChargeCanBeAddedWhenTheReceiptHadNone() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(!model.showsServiceRow)
        #expect(model.setAmount(.service, text: "15.15") == nil)
        #expect(store.session?.draft.tip?.minorUnits == 1515)
        #expect(model.showsServiceRow)
    }

    @Test func parserAdjustmentsAreListedAndCanBeRemoved() {
        var draft = SampleBill.scannedDraft()
        draft.adjustments = [DraftAdjustment(label: "Descuento", amount: DraftAmount(minorUnits: -500))]
        let (model, store) = makeModel(BillSession(draft: draft))
        #expect(model.adjustments.map(\.label) == ["Descuento"])
        #expect(model.adjustments.map(\.cents) == [-500])
        #expect(model.status == .itemsDoNotMatchSubtotal(itemsCents: 9600, subtotalCents: 10_100))
        model.removeAdjustment(at: 0)
        #expect(model.adjustments.isEmpty)
        #expect(store.session?.draft.adjustments.isEmpty == true)
        #expect(model.status == .balanced)
    }

    // MARK: Continuing

    @Test func continuingWithoutItemsIsNotPossible() {
        let (model, _) = makeModel(BillSession(draft: ReceiptDraft()))
        #expect(model.requestContinue() == .noItems)
    }

    @Test func aBalancedReceiptContinuesWithoutAsking() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(model.requestContinue() == .proceed)
        #expect(store.session?.mismatchAcknowledged == false)
    }

    @Test func aMismatchAsksForConfirmationBeforeContinuing() {
        let (model, store) = makeModel()
        #expect(model.requestContinue() == .confirmMismatch(differenceCents: 1000))
        #expect(store.session?.mismatchAcknowledged == false, "asking is not agreeing")
    }

    @Test func aMissingTotalAlsoAsksForConfirmation() {
        var draft = SampleBill.scannedDraft()
        draft.total = nil
        let (model, _) = makeModel(BillSession(draft: draft))
        #expect(model.requestContinue() == .confirmMismatch(differenceCents: nil))
    }

    @Test func confirmingRecordsTheAcknowledgementAndSharingStaysBlocked() {
        var session = ReviewSamples.parsedSession()
        session.addParticipant(name: "Ana")
        session.splitRestEvenly()
        let (model, store) = makeModel(session)
        #expect(store.session?.phase == .mismatch)

        model.confirmMismatch()

        #expect(store.session?.mismatchAcknowledged == true)
        #expect(store.session?.phase == .totals)
        #expect(store.session?.canShare == false)
        #expect(store.session?.shareBlockReason == .receiptMismatch)

        // Fixing the receipt later unblocks sharing by itself.
        #expect(model.updateItem(id: ReviewSamples.flanID, name: "Flan para compartir", priceText: "9.00", quantity: 1) == nil)
        #expect(store.session?.canShare == true)
    }

    @Test func editingAfterConfirmingAsksAgain() {
        let (model, store) = makeModel()
        model.confirmMismatch()
        #expect(store.session?.mismatchAcknowledged == true)
        #expect(model.setAmount(.subtotal, text: "100.00") == nil)
        #expect(store.session?.mismatchAcknowledged == false)
        #expect(model.requestContinue() == .confirmMismatch(differenceCents: 1100))
    }

    // MARK: What the parser was unsure about

    private let unreadableFlan = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let strayPrice = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!

    @Test func warningsFromTheParserAreListedInTheOrderTheScanFoundThem() {
        let (model, _) = makeModel(ReviewSamples.unsureSession())
        #expect(model.warnings.map(\.id) == [unreadableFlan, strayPrice])
        #expect(model.warnings.map(\.kind) == [.unreadablePrice(text: "9,00"), .unreadablePrice(text: "5")])
        #expect(model.warnings.map(\.rowLabel) == ["Flan para compartir", nil])
    }

    @Test func aGuessedNumberFormatIsListedToo() {
        var draft = SampleBill.scannedDraft()
        draft.warnings = [ReceiptWarning(issue: .numberFormatGuessed(.usdCents))]
        let (model, _) = makeModel(BillSession(draft: draft))
        #expect(model.warnings.map(\.kind) == [.formatGuessed])
    }

    @Test func aCleanScanListsNoWarnings() {
        #expect(makeModel(SampleBill.scanned()).model.warnings.isEmpty)
        #expect(makeModel(ReviewSamples.parsedSession()).model.warnings.isEmpty)
    }

    @Test func warningsOnlyListWhatTheScanCouldNotReadNotWhatTheScreenAlreadyChecks() {
        var draft = SampleBill.scannedDraft()
        draft.warnings = [ReceiptWarning(issue: .noTotalFound), ReceiptWarning(issue: .itemsDoNotMatchSubtotal(itemsSum: 1, printed: 2))]
        #expect(makeModel(BillSession(draft: draft)).model.warnings.isEmpty)
    }

    @Test func dismissingAWarningRemovesItFromTheListButKeepsItInTheBill() {
        let (model, store) = makeModel(ReviewSamples.unsureSession())
        model.dismissWarning(id: unreadableFlan)
        #expect(model.warnings.map(\.id) == [strayPrice])
        #expect(store.session?.draft.warnings.map(\.isDismissed) == [true, false])
        #expect(store.pendingSave != nil, "dismissing is autosaved")
    }

    @Test func dismissingTheLastWarningLeavesNone() {
        let (model, _) = makeModel(ReviewSamples.unsureSession())
        model.dismissWarning(id: unreadableFlan)
        model.dismissWarning(id: strayPrice)
        #expect(model.warnings.isEmpty)
    }

    @Test func warningsNeverBlockAnEditableReceipt() {
        let (model, _) = makeModel(ReviewSamples.unsureSession())
        #expect(!model.warnings.isEmpty)
        #expect(model.canContinue)
        #expect(model.items.count == 7)
        #expect(model.addItem(name: "Flan para compartir", priceText: "9.00", quantity: 1) == nil)
        #expect(model.warnings.count == 2, "adding the missing row does not decide for the user")
        #expect(model.status == .balanced)
        #expect(model.requestContinue() == .proceed, "a balanced receipt continues even with a warning still open")
    }

    @Test func dismissingDoesNotWithdrawAContinueAnywayTheUserGave() {
        let (model, store) = makeModel(ReviewSamples.unsureSession())
        model.confirmMismatch()
        model.dismissWarning(id: strayPrice)
        #expect(store.session?.mismatchAcknowledged == true)
        #expect(model.requestContinue() == .proceed)
    }

    @Test func savingTheRowAWarningIsAboutRetiresIt() {
        var draft = SampleBill.scannedDraft()
        let item = draft.items[0]
        draft.warnings = [
            ReceiptWarning(issue: .unparsedPriceRow("4,00"), rowLabel: item.name, itemID: item.id),
            ReceiptWarning(issue: .unparsedPriceRow("5")),
        ]
        let (model, store) = makeModel(BillSession(draft: draft))
        #expect(model.warnings.count == 2)
        #expect(model.updateItem(id: item.id, name: item.name, priceText: "4.00", quantity: 1) == nil)
        #expect(model.warnings.count == 1)
        #expect(store.session?.draft.warnings.map(\.isDismissed) == [true, false])
    }

    @Test func deletingTheRowAWarningIsAboutRetiresIt() {
        var draft = SampleBill.scannedDraft()
        let item = draft.items[0]
        draft.warnings = [ReceiptWarning(issue: .unparsedPriceRow("4,00"), rowLabel: item.name, itemID: item.id)]
        let (model, _) = makeModel(BillSession(draft: draft))
        model.deleteItem(id: item.id)
        #expect(model.warnings.isEmpty)
    }

    @Test func editingAnotherRowKeepsEveryWarning() {
        let (model, _) = makeModel(ReviewSamples.unsureSession())
        let first = model.items[0]
        #expect(model.updateItem(id: first.id, name: first.name, priceText: "5.00", quantity: 1) == nil)
        #expect(model.setAmount(.tax, text: "10.00") == nil)
        #expect(model.warnings.count == 2)
    }

    // MARK: Store

    @Test func editsGoThroughTheStoreSoTheyAreAutosaved() {
        let (model, store) = makeModel(SampleBill.scanned())
        #expect(model.addItem(name: "Tostones", priceText: "6.00", quantity: 1) == nil)
        #expect(store.pendingSave != nil)
    }

    @Test func reachingTheScreenWithoutABillStartsAnEmptyOne() {
        let (model, store) = makeModel(nil)
        #expect(store.session == nil)
        model.startBillIfNeeded()
        #expect(store.session?.draft.items.isEmpty == true)
        #expect(model.addItem(name: "Tostones", priceText: "6.00", quantity: 1) == nil)
        #expect(store.session?.draft.items.count == 1)
    }

    @Test func startingABillKeepsAnExistingOne() {
        let (model, store) = makeModel(SampleBill.scanned())
        model.startBillIfNeeded()
        #expect(store.session?.draft.items.count == 8)
    }
}

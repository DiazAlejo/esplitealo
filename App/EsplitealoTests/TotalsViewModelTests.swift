import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The logic of the Totals screen: the tip settings, the per-person breakdown from the calculator, the rounding notes,
/// the gating of the share button, and the share text. The numbers below come from the Fonda Doña Lola bill of the
/// mockups: $101.00 of items, $11.62 tax, $112.62 on the receipt, four people.
@MainActor
struct TotalsViewModelTests {
    private func store(_ session: BillSession) -> BillStore {
        let store = BillStore(draftStore: RecordingDraftStore(), clock: ManualClock())
        store.startNewBill(draft: session.draft)
        store.update { $0 = session }
        return store
    }

    private func model(_ session: BillSession = SampleBill.complete()) -> (TotalsViewModel, BillStore) {
        let store = store(session)
        return (TotalsViewModel(store: store), store)
    }

    // MARK: Tip settings

    @Test func theTipStartsAsTwentyPercentOfThePreTaxSubtotal() {
        let (model, _) = model()
        #expect(model.tipSelection == .preset(20))
        #expect(model.usesPostTaxTip == false)
        #expect(model.tipBaseCents == 10_100)
        #expect(model.summary.tipCents == 2020)
        #expect(model.summary.billTotalCents == 11_262 + 2020)
    }

    @Test func presetsAreFifteenEighteenAndTwenty() {
        #expect(TotalsViewModel.tipPresets == [15, 18, 20])
    }

    @Test func choosingAPresetChangesTheTipAndIsSavedInTheBill() {
        let (model, store) = model()
        model.selectPreset(15)
        #expect(model.tipSelection == .preset(15))
        #expect(model.summary.tipCents == 1515)
        #expect(store.session?.tip == .percentage(percent: 15, basis: .preTaxSubtotal))
        #expect(model.summary.billTotalCents == 11_262 + 1515)
    }

    @Test func thePostTaxOptionAppliesThePercentageToSubtotalPlusTaxAndKeepsThePercentage() {
        let (model, store) = model()
        model.selectPreset(18)
        model.usesPostTaxTip = true
        #expect(store.session?.tip == .percentage(percent: 18, basis: .postTaxTotal))
        #expect(model.tipBaseCents == 11_262)
        #expect(model.summary.tipCents == 2027)
        #expect(model.tipSelection == .preset(18))

        model.selectPreset(20)
        #expect(store.session?.tip == .percentage(percent: 20, basis: .postTaxTotal), "choosing a percentage keeps the option")
        model.usesPostTaxTip = false
        #expect(store.session?.tip == .percentage(percent: 20, basis: .preTaxSubtotal))
    }

    @Test func customStartsFromTheCurrentTipAndTakesAnAmountInDollars() {
        let (model, store) = model()
        model.selectCustom()
        #expect(model.tipSelection == .custom)
        #expect(store.session?.tip == .custom(cents: 2020), "switching to custom keeps what the tip was")
        #expect(model.customTipText == "20.20")

        model.customTipText = "12.5"
        #expect(store.session?.tip == .custom(cents: 1250))
        #expect(model.summary.tipCents == 1250)
        #expect(model.customTipIsInvalid == false)
    }

    @Test func anAmountThatIsNotMoneyIsFlaggedAndLeavesTheTipAlone() {
        let (model, store) = model()
        model.selectCustom()
        model.customTipText = "12.5"
        model.customTipText = "doce"
        #expect(model.customTipIsInvalid)
        #expect(model.customTipText == "doce", "what was typed stays in the field")
        #expect(store.session?.tip == .custom(cents: 1250))

        model.customTipText = "13"
        #expect(model.customTipIsInvalid == false)
        #expect(store.session?.tip == .custom(cents: 1300))
    }

    @Test func theStepperMovesFiftyCentsAndStopsAtZero() {
        let (model, store) = model()
        model.selectCustom()
        model.stepCustomTip(by: 50)
        #expect(store.session?.tip == .custom(cents: 2070))
        #expect(model.customTipText == "20.70")
        model.customTipText = "0.20"
        model.stepCustomTip(by: -50)
        #expect(store.session?.tip == .custom(cents: 0))
        #expect(model.canDecreaseTip == false)
        model.stepCustomTip(by: -50)
        #expect(store.session?.tip == .custom(cents: 0))
    }

    @Test func aPresetChosenAfterCustomReplacesIt() {
        let (model, store) = model()
        model.selectCustom()
        model.selectPreset(18)
        #expect(store.session?.tip == .percentage(percent: 18, basis: .preTaxSubtotal))
        #expect(model.tipSelection == .preset(18))
    }

    @Test func aReceiptWithAServiceChargeStartsWithNoTipAndSaysWhy() {
        let (model, _) = model(TotalsSamples.serviceCharge())
        #expect(model.summary.tipCents == 0)
        #expect(model.tipSelection == .custom, "no preset is 0%, so the field shows $0.00")
        #expect(model.customTipText == "0.00")
        #expect(model.tipHint == .serviceIncluded(serviceCents: 1515))
        #expect(model.summary.showsService)
        #expect(model.summary.serviceCents == 1515)
        #expect(model.summary.billTotalCents == 12_777)
    }

    @Test func raisingTheTipOnAServiceReceiptWarnsAboutTippingTwice() {
        let (model, store) = model(TotalsSamples.serviceCharge())
        model.stepCustomTip(by: 50)
        #expect(store.session?.tip == .custom(cents: 50))
        #expect(model.tipHint == .serviceDouble(serviceCents: 1515))
        model.selectPreset(18)
        #expect(model.tipHint == .serviceDouble(serviceCents: 1515))
    }

    @Test func aReceiptWithoutServiceHasNoTipHint() {
        let (model, _) = model()
        #expect(model.tipHint == .none)
        #expect(model.summary.showsService == false)
    }

    // MARK: Per-person breakdown

    @Test func everyoneIsListedInOrderWithTheirColourAndAmountsThatAddUpToTheBill() throws {
        let (model, store) = model()
        let session = try #require(store.session)
        #expect(model.rows.map(\.name) == SampleBill.people)
        #expect(model.rows.map(\.colorIndex) == [0, 1, 2, 3])
        #expect(model.rows.map(\.totalCents).reduce(0, +) == session.confirmedBillTotalCents)
        for (row, breakdown) in zip(model.rows, session.personBreakdowns) {
            #expect(row.itemsCents == breakdown.itemSubtotalCents)
            #expect(row.taxCents == breakdown.taxShareCents)
            #expect(row.tipCents == breakdown.tipShareCents)
            #expect(row.totalCents == breakdown.totalOwedCents)
            #expect(row.totalCents == row.itemsCents + row.taxCents + row.serviceCents + row.tipCents)
        }
    }

    @Test func theServiceChargeIsSharedAndShownPerPerson() {
        let (model, _) = model(TotalsSamples.serviceCharge())
        #expect(model.rows.map(\.serviceCents).reduce(0, +) == 1515)
        #expect(model.rows.allSatisfy { $0.serviceCents > 0 })
        #expect(model.rows.map(\.totalCents).reduce(0, +) == 12_777)
    }

    @Test func aTipPrintedOnTheReceiptIsAddedToTheServiceColumnSoTheLinesAddUp() {
        var session = SampleBill.complete()
        var draft = session.draft
        draft.tip = DraftAmount(minorUnits: 1000)
        draft.total = DraftAmount(minorUnits: 12_262)
        session.applyDraft(draft)
        let (model, _) = model(session)
        #expect(model.summary.showsService)
        #expect(model.summary.serviceCents == 1000)
        for row in model.rows {
            #expect(row.totalCents == row.itemsCents + row.taxCents + row.serviceCents + row.tipCents)
        }
        #expect(model.rows.map(\.totalCents).reduce(0, +) == model.summary.billTotalCents)
    }

    @Test func eachPersonListsTheirItemsAndHowManyWaysTheyWereSplit() throws {
        let (model, _) = model()
        // Keishla (index 2): item 3 (surtido de frituras, with Marisol and Héctor) and item 6 (ensalada de pulpo).
        let keishla = try #require(model.rows.first { $0.name == "Keishla" })
        let surtido = try #require(keishla.itemLines.first { $0.name == "Surtido de frituras" })
        #expect(surtido.splitWays == 3)
        #expect(surtido.cents == 466, "$14.00 ÷ 3 leaves 2¢; Keishla is not one of the two who pay it")
        let ensalada = try #require(keishla.itemLines.first { $0.name == "Ensalada de pulpo" })
        #expect(ensalada.splitWays == 1)
        #expect(ensalada.cents == 1400)
        #expect(keishla.itemLines.map(\.cents).reduce(0, +) == keishla.itemsCents)
    }

    @Test func theShareBarGivesEachPersonTheirPercentOfTheBill() {
        let (model, _) = model()
        let total = model.rows.map(\.totalCents).reduce(0, +)
        for row in model.rows {
            #expect(row.percent == Int((Double(row.totalCents) / Double(total) * 100).rounded()))
        }
        #expect(model.rows.map(\.fraction).reduce(0, +) > 0.999)
        #expect(model.rows.map(\.fraction).reduce(0, +) < 1.001)
    }

    // MARK: Rounding

    @Test func everyStrayCentIsNamedSoNothingIsHidden() throws {
        let (model, store) = model()
        let session = try #require(store.session)
        let reported = session.splitResult.allAdjustments.map(\.cents).reduce(0, +)
        #expect(reported > 0, "the sample bill has stray cents to explain")
        #expect(model.rows.map(\.roundingCents).reduce(0, +) == reported)
        #expect(model.hasRounding)
        // Everything in the notes is accounted for: item notes plus pool notes carry the same cents.
        let noted = model.roundingNotes.map { note -> Int in
            switch note {
            case let .item(_, _, _, leftover, _): leftover
            case let .pool(_, cents, _): cents
            }
        }
        #expect(noted.reduce(0, +) == reported)
    }

    @Test func aSharedItemThatDoesNotDivideNamesWhoPaysTheExtraCents() {
        let (model, _) = model()
        // Surtido de frituras, $14.00 ÷ 3 leaves 2¢ and the two who were closest pay it; ties follow the list order.
        let note = model.roundingNotes.first {
            if case let .item(name, _, _, _, _) = $0 { name == "Surtido de frituras" } else { false }
        }
        #expect(note == .item(name: "Surtido de frituras", priceCents: 1400, ways: 3, leftoverCents: 2, names: ["Marisol", "Héctor"]))
    }

    @Test func taxAndTipLeftoversAreNamedPerPool() {
        let (model, _) = model()
        let pools = model.roundingNotes.compactMap { note -> TotalsViewModel.RoundingNote.Pool? in
            if case let .pool(pool, _, _) = note { pool } else { nil }
        }
        #expect(pools.filter { $0 == .tax }.count <= 1)
        #expect(pools.filter { $0 == .tip }.count <= 1)
        #expect(Set(pools).isSubset(of: [.tax, .service, .tip]))
    }

    @Test func aBillWithNothingLeftOverHasNoRoundingCard() {
        var session = SampleBill.complete()
        // Everyone shares every item four ways at prices divisible by four, no tax: nothing to round.
        let clean = DraftItem(name: "Cuatro", quantity: 1, lineTotal: DraftAmount(minorUnits: 4000))
        var draft = ReceiptDraft(items: [clean], subtotal: DraftAmount(minorUnits: 4000), tax: DraftAmount(minorUnits: 0), total: DraftAmount(minorUnits: 4000))
        draft = ReceiptDraftEditing.reconcile(draft)
        session.applyDraft(draft)
        session.tip = .percentage(percent: 0, basis: .preTaxSubtotal)
        session.assignUnit(itemID: clean.id, unitIndex: 0, participantIDs: session.participants.map(\.id))
        let (model, _) = model(session)
        #expect(model.hasRounding == false)
        #expect(model.roundingNotes.isEmpty)
        #expect(model.rows.allSatisfy { $0.roundingCents == 0 })
    }

    // MARK: Gating

    @Test func aFullyAssignedReconciledBillCanBeShared() {
        let (model, _) = model()
        #expect(model.status == .reconciled(totalCents: 13_282))
        #expect(model.canShare)
        #expect(model.blockedByReceipt == false)
    }

    @Test func unassignedItemsBlockSharingAndSayHowManyAndHowMuch() {
        let (model, _) = model(SampleBill.midway())
        // The midway bill leaves the jugo de parcha ($4.00) and the flan ($9.00) unmarked.
        #expect(model.status == .unassigned(items: 2, cents: 1300))
        #expect(model.canShare == false)
    }

    @Test func aReceiptMismatchTheUserConfirmedStillBlocksSharingAndShowsTheDifference() {
        var session = SampleBill.complete()
        session.applyDraft(ReviewSamples.parsedDraft())
        session.acknowledgeMismatch()
        let (model, _) = model(session)
        // Items add up to $111.00 but the receipt subtotal says $101.00.
        #expect(model.status == .receiptMismatch(differenceCents: 1000, itemsCents: 11_100, subtotalCents: 10_100))
        #expect(model.canShare == false)
        #expect(model.blockedByReceipt)
    }

    @Test func fixingTheReceiptClearsTheMismatchAndSharingOpensUp() {
        var session = SampleBill.complete()
        session.applyDraft(ReviewSamples.parsedDraft())
        session.acknowledgeMismatch()
        let (model, store) = model(session)
        #expect(model.canShare == false)
        store.update { $0.applyDraft(SampleBill.scannedDraft()) }
        #expect(model.canShare)
        #expect(model.status == .reconciled(totalCents: 13_282))
    }

    @Test func aMissingPrintedTotalBlocksSharing() {
        var session = SampleBill.complete()
        var draft = session.draft
        draft.total = nil
        session.applyDraft(draft)
        let (model, _) = model(session)
        #expect(model.status == .missingTotal)
        #expect(model.canShare == false)
    }

    @Test func discountRowsBlockSharingUntilTheyAreTakenOffThePrices() {
        var session = SampleBill.complete()
        var draft = session.draft
        draft.adjustments = [DraftAdjustment(label: "Descuento", amount: DraftAmount(minorUnits: -500))]
        draft.subtotal = DraftAmount(minorUnits: 9600)
        draft.total = DraftAmount(minorUnits: 10_762)
        session.applyDraft(draft)
        let (model, _) = model(session)
        #expect(model.status == .discountsNotSplit)
        #expect(model.canShare == false)
    }

    @Test func requestingShareWhileBlockedDoesNotOpenTheSheet() {
        let (model, _) = model(SampleBill.midway())
        model.requestShare()
        #expect(model.isSharing == false)
    }

    @Test func requestingShareWhenItAddsUpOpensTheSheet() {
        let (model, _) = model()
        model.requestShare()
        #expect(model.isSharing)
        model.dismissShare()
        #expect(model.isSharing == false)
        #expect(model.hasShared == false)
    }

    @Test func aBillThatBecomesBlockedWhileTheSheetIsOpenClosesIt() {
        let (model, store) = model()
        model.requestShare()
        let first = SampleBill.complete().draft.items[0].id
        store.update { $0.clearUnitAssignment(itemID: first, unitIndex: 0) }
        model.closeShareIfBlocked()
        #expect(model.isSharing == false)
    }

    // MARK: Share text

    @Test func theSummaryComesFromTheShareBuilderInTheChosenLanguage() throws {
        let (model, store) = model()
        let session = try #require(store.session)
        let calendar = Calendar(identifier: .gregorian)
        #expect(model.shareText(language: .es, calendar: calendar) == ShareSummaryBuilder.build(for: session, language: .es, calendar: calendar))
        #expect(model.shareText(language: .en, calendar: calendar) == ShareSummaryBuilder.build(for: session, language: .en, calendar: calendar))
        let spanish = model.shareText(language: .es, calendar: calendar)
        #expect(spanish.contains("Marisol debe"))
        #expect(spanish.contains("Todo cuadra en"))
        #expect(model.shareText(language: .en, calendar: calendar).contains("Marisol owes"))
    }

    @Test func theShareLanguageFollowsTheLanguageOfTheApp() {
        #expect(TotalsViewModel.shareLanguage(for: Locale(identifier: "es_PR")) == .es)
        #expect(TotalsViewModel.shareLanguage(for: Locale(identifier: "es")) == .es)
        #expect(TotalsViewModel.shareLanguage(for: Locale(identifier: "en_US")) == .en)
        #expect(TotalsViewModel.shareLanguage(for: Locale(identifier: "en")) == .en)
        #expect(TotalsViewModel.shareLanguage(for: Locale(identifier: "fr_FR")) == .es, "Spanish is the app's own language")
    }

    @Test func theShareTextCarriesTheTipTheScreenShows() {
        let (model, _) = model()
        model.selectPreset(15)
        let text = model.shareText(language: .en)
        #expect(text.contains("15% tip $15.15"), text)
    }

    // MARK: After sharing

    @Test func afterAShareThatWentThroughTheSuccessMomentShowsAndTheCountIsKept() {
        let (model, _) = model()
        model.requestShare()
        model.shareCompleted()
        #expect(model.isSharing == false)
        #expect(model.hasShared)
        #expect(model.sharedPeopleCount == 4)
        #expect(model.sharedTotalCents == 13_282)
    }

    @Test func aCancelledShareChangesNothing() {
        let (model, _) = model()
        model.requestShare()
        model.shareCancelled()
        #expect(model.hasShared == false)
        #expect(model.isSharing == true, "the preview stays so another app can be tried")
    }

    @Test func startingANewBillForgetsTheBillAndItsDraft() {
        let recording = RecordingDraftStore()
        let store = BillStore(draftStore: recording, clock: ManualClock())
        store.startNewBill(draft: SampleBill.complete().draft)
        store.update { $0 = SampleBill.complete() }
        let model = TotalsViewModel(store: store)
        model.requestShare()
        model.shareCompleted()
        model.startNewBill()
        #expect(store.session == nil)
        #expect(recording.deleteCount >= 1)
        #expect(model.hasShared == false)
    }
}

import XCTest
@testable import EsplitealoCore

/// The calculation-rule decisions of docs/CALCULATION_RULES.md that concern the session: every leftover cent is an
/// adjustment (service charge and printed tip included), a bill nobody can carry the charges of says so, and a
/// negative tip is zero.
final class BillSessionCalculationRulesTests: XCTestCase {
    private let noTip = TipConfiguration.percentage(percent: 0, basis: .preTaxSubtotal)

    /// One person per line, each paying for their own line. `service` is a service charge, `printedTip` a tip line
    /// printed on the receipt; either way the receipt's printed total includes it.
    private func table(
        prices: [Int],
        tax: Int = 0,
        printedTip: Int = 0,
        service: Int = 0,
        tip: TipConfiguration? = nil,
        printedTotal: Int? = nil
    ) -> BillSession {
        let people = prices.indices.map { Participant(name: "P\($0)", orderIndex: $0) }
        let items = prices.indices.map { DraftItem(name: "L\($0)", quantity: 1, lineTotal: DraftAmount(minorUnits: prices[$0])) }
        let gratuity = max(service, printedTip)
        let subtotal = prices.reduce(0, +)
        let draft = ReceiptDraftEditing.reconcile(ReceiptDraft(
            items: items,
            subtotal: DraftAmount(minorUnits: subtotal),
            tax: tax > 0 ? DraftAmount(minorUnits: tax) : nil,
            tip: gratuity > 0 ? DraftAmount(minorUnits: gratuity) : nil,
            total: DraftAmount(minorUnits: printedTotal ?? subtotal + tax + gratuity)
        ))
        return BillSession(
            draft: draft,
            serviceChargeCents: service,
            participants: people,
            assignments: zip(items, people).map { ItemAssignment(itemID: $0.id, unitIndex: 0, participantIDs: [$1.id]) },
            tip: tip ?? noTip
        )
    }

    private func adjustedPeople(_ session: BillSession, pool: RoundingAdjustment.Pool) -> [Int] {
        session.personBreakdowns.map { $0.adjustments.filter { $0.pool == pool }.count }
    }

    // MARK: - 1. Service charge and printed tip cents are adjustments

    func testServiceChargeLeftoverCentsAreAdjustmentsAndAmountsDoNotChange() {
        let session = table(prices: [1000, 1000, 1000], service: 100)
        XCTAssertEqual(session.personBreakdowns.map(\.serviceShareCents), [34, 33, 33])
        XCTAssertEqual(adjustedPeople(session, pool: .serviceCharge), [1, 0, 0])
        XCTAssertEqual(adjustedPeople(session, pool: .printedTip), [0, 0, 0])
        XCTAssertEqual(session.personBreakdowns.map(\.totalOwedCents), [1034, 1033, 1033])
        XCTAssertEqual(session.personBreakdowns.flatMap(\.adjustments).filter { $0.pool == .serviceCharge }.map(\.cents), [1])
        XCTAssertTrue(session.canShare)
    }

    func testPrintedTipLeftoverCentsAreAdjustmentsAndAmountsDoNotChange() {
        let session = table(prices: [1000, 1000, 1000], printedTip: 200)
        XCTAssertEqual(session.personBreakdowns.map(\.receiptTipShareCents), [67, 67, 66])
        XCTAssertEqual(adjustedPeople(session, pool: .printedTip), [1, 1, 0])
        XCTAssertEqual(adjustedPeople(session, pool: .serviceCharge), [0, 0, 0])
        XCTAssertEqual(session.personBreakdowns.map(\.totalOwedCents), [1067, 1067, 1066])
        XCTAssertTrue(session.canShare)
    }

    func testPoolsThatDivideExactlyHaveNoAdjustments() {
        let session = table(prices: [1000, 1000, 1000], service: 300)
        XCTAssertEqual(adjustedPeople(session, pool: .serviceCharge), [0, 0, 0])
    }

    func testPrintedTipUnderAServiceChargeIsNotAllocatedSoItHasNoAdjustments() {
        // The service charge wins: the printed tip line is the same money and is not split a second time.
        let session = table(prices: [1000, 1000, 1000], printedTip: 200, service: 100)
        XCTAssertEqual(session.receiptTipOnBillCents, 0)
        XCTAssertEqual(adjustedPeople(session, pool: .printedTip), [0, 0, 0])
        XCTAssertEqual(adjustedPeople(session, pool: .serviceCharge), [1, 0, 0])
    }

    func testEveryPoolAdjustmentCountEqualsItsLeftoverCents() {
        let session = table(prices: [333, 667, 1001], tax: 101, service: 97)
        let breakdowns = session.personBreakdowns
        let weights = breakdowns.map(\.itemSubtotalCents)
        let total = weights.reduce(0, +)
        let serviceFloors = weights.map { 97 * $0 / total }.reduce(0, +)
        XCTAssertEqual(adjustedPeople(session, pool: .serviceCharge).reduce(0, +), 97 - serviceFloors)
        XCTAssertEqual(breakdowns.map(\.serviceShareCents).reduce(0, +), 97)
    }

    func testPersonWithoutItemsGetsNoServiceOrPrintedTipAdjustment() {
        let alex = Participant(name: "Alex", orderIndex: 0)
        let sam = Participant(name: "Sam", orderIndex: 1)
        let chris = Participant(name: "Chris", orderIndex: 2)
        let item = DraftItem(name: "Plate", quantity: 1, lineTotal: DraftAmount(minorUnits: 1000))
        let draft = ReceiptDraftEditing.reconcile(ReceiptDraft(
            items: [item], subtotal: DraftAmount(minorUnits: 1000), tip: DraftAmount(minorUnits: 101), total: DraftAmount(minorUnits: 1101)
        ))
        let session = BillSession(
            draft: draft, serviceChargeCents: 101, participants: [alex, sam, chris],
            assignments: [ItemAssignment(itemID: item.id, unitIndex: 0, participantIDs: [alex.id, sam.id])], tip: noTip
        )
        XCTAssertEqual(session.personBreakdowns.map(\.serviceShareCents), [51, 50, 0])
        XCTAssertEqual(adjustedPeople(session, pool: .serviceCharge), [1, 0, 0])
        XCTAssertTrue(session.personBreakdowns[2].adjustments.isEmpty)
    }

    func testCalculatorAdjustmentsAreStillThereAndComeFirst() {
        let session = table(prices: [1000, 1000, 1000], tax: 100, printedTip: 100, tip: .custom(cents: 100))
        let first = session.personBreakdowns[0]
        XCTAssertEqual(first.adjustments.map(\.pool), [.tax, .tip, .printedTip])
        XCTAssertEqual(first.adjustments, session.splitResult.shares[0].adjustments + [RoundingAdjustment(participantID: first.participantID, pool: .printedTip)])
    }

    // MARK: - 2. A bill nobody can carry the charges of

    func testFreeItemsWithTaxAreBlockedAndSayNobodyHasItemsToCarryTheCharges() {
        let session = table(prices: [0, 0], tax: 100)
        XCTAssertFalse(session.canShare)
        XCTAssertEqual(session.shareBlockReason, .noItemsToCarryCharges)
        XCTAssertEqual(session.phase, .totals)
        XCTAssertNotEqual(session.shareBlockReason, .receiptMismatch)
    }

    func testFreeItemsWithAServiceChargeAreBlockedWithThatReason() {
        let session = table(prices: [0, 0], service: 50)
        XCTAssertEqual(session.shareBlockReason, .noItemsToCarryCharges)
    }

    func testFreeItemsWithAPrintedTipAreBlockedWithThatReason() {
        let session = table(prices: [0, 0], printedTip: 50)
        XCTAssertEqual(session.shareBlockReason, .noItemsToCarryCharges)
    }

    func testFreeItemsWithACustomTipAreBlockedWithThatReason() {
        let session = table(prices: [0, 0], tip: .custom(cents: 300))
        XCTAssertEqual(session.shareBlockReason, .noItemsToCarryCharges)
        XCTAssertFalse(session.canShare)
    }

    func testABillWithNoItemsAtAllAndATaxIsBlockedWithThatReason() {
        let draft = ReceiptDraftEditing.reconcile(ReceiptDraft(
            subtotal: DraftAmount(minorUnits: 0), tax: DraftAmount(minorUnits: 100), total: DraftAmount(minorUnits: 100)
        ))
        let session = BillSession(draft: draft, participants: [Participant(name: "Alex", orderIndex: 0)], tip: noTip)
        XCTAssertFalse(session.canShare)
        XCTAssertEqual(session.shareBlockReason, .noItemsToCarryCharges)
    }

    func testFreeItemsWithNothingToCarryCanBeShared() {
        let session = table(prices: [0, 0])
        XCTAssertTrue(session.canShare)
        XCTAssertNil(session.shareBlockReason)
    }

    func testSomeoneWithPricedItemsCarriesTheCharges() {
        let session = table(prices: [0, 500], tax: 100)
        XCTAssertTrue(session.canShare)
        XCTAssertNil(session.shareBlockReason)
    }

    func testAnUnclaimedFreeItemIsReportedAsUnassignedFirst() {
        var session = table(prices: [0, 0], tax: 100)
        session.clearUnitAssignment(itemID: session.draft.items[0].id, unitIndex: 0)
        XCTAssertEqual(session.shareBlockReason, .unassignedItems)
    }

    func testAMissingPrintedTotalIsReportedBeforeIt() {
        var session = table(prices: [0, 0], tax: 100)
        session.draft.total = nil
        session.draft = ReceiptDraftEditing.reconcile(session.draft)
        XCTAssertEqual(session.shareBlockReason, .missingPrintedTotal)
    }

    func testAReceiptThatDoesNotAddUpIsAMismatchFirst() {
        let session = table(prices: [0, 0], tax: 100, printedTotal: 999)
        XCTAssertEqual(session.shareBlockReason, .receiptMismatch)
    }

    // MARK: - 4. A negative tip is zero

    func testANegativeCustomTipIsZero() {
        let session = table(prices: [1000, 1000], tip: .custom(cents: -500))
        XCTAssertEqual(session.sessionTipCents, 0)
        XCTAssertEqual(session.splitResult.tipCents, 0)
        XCTAssertEqual(session.derivedBillTotalCents, 2000)
        XCTAssertEqual(session.personBreakdowns.map(\.tipShareCents), [0, 0])
        XCTAssertTrue(session.canShare)
    }

    func testANegativePercentageIsZeroOnEitherBasis() {
        for basis in [TipBasis.preTaxSubtotal, .postTaxTotal] {
            let session = table(prices: [1000, 1000], tax: 200, tip: .percentage(percent: -20, basis: basis))
            XCTAssertEqual(session.sessionTipCents, 0, "\(basis)")
            XCTAssertEqual(session.personBreakdowns.map(\.tipShareCents), [0, 0], "\(basis)")
            XCTAssertTrue(session.canShare, "\(basis)")
        }
    }
}

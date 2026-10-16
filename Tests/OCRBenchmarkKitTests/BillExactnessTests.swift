import XCTest
@testable import EsplitealoCore
@testable import OCRBenchmarkKit

final class BillExactnessTests: XCTestCase {
    private let truth = StressBillTruth(
        items: [
            GroundTruthItem(name: "Mofongo", quantity: 1, lineTotalMinor: 1450),
            GroundTruthItem(name: "Medalla", quantity: 3, lineTotalMinor: 1050),
        ],
        adjustmentsMinor: [-200],
        subtotalMinor: 2300,
        taxLinesMinor: [241, 23],
        tipMinor: 345,
        totalMinor: 2909
    )

    private func draft(
        items: [(Int, Int)] = [(1450, 1), (1050, 3)],
        adjustments: [Int] = [-200],
        subtotal: Int? = 2300,
        tax: Int? = 264,
        tip: Int? = 345,
        total: Int? = 2909,
        reconciles: Bool = true
    ) -> ReceiptDraft {
        ReceiptDraft(
            items: items.map { DraftItem(name: "x", quantity: $0.1, lineTotal: DraftAmount(minorUnits: $0.0)) },
            subtotal: subtotal.map { DraftAmount(minorUnits: $0) },
            tax: tax.map { DraftAmount(minorUnits: $0) },
            tip: tip.map { DraftAmount(minorUnits: $0) },
            total: total.map { DraftAmount(minorUnits: $0) },
            adjustments: adjustments.map { DraftAdjustment(label: "Descuento", amount: DraftAmount(minorUnits: $0)) },
            reconciles: reconciles
        )
    }

    func testIdenticalBillIsExact() {
        let result = BillExactness.compare(draft: draft(), truth: truth)
        XCTAssertTrue(result.exact)
        XCTAssertTrue(result.amountsExact)
        XCTAssertEqual(result.causes, [])
    }

    func testOneCentOffIsNotExact() {
        let result = BillExactness.compare(draft: draft(tax: 265), truth: truth)
        XCTAssertFalse(result.exact)
        XCTAssertEqual(result.causes, [.taxWrong])
    }

    func testMissingAndExtraItemsAreTold() {
        XCTAssertEqual(
            BillExactness.compare(draft: draft(items: [(1450, 1)]), truth: truth).causes,
            [.itemMissing]
        )
        XCTAssertEqual(
            BillExactness.compare(draft: draft(items: [(1450, 1), (1050, 3), (500, 1)]), truth: truth).causes,
            [.itemExtra]
        )
        XCTAssertEqual(
            BillExactness.compare(draft: draft(items: [(1450, 1), (1060, 3)]), truth: truth).causes,
            [.itemPriceWrong]
        )
        XCTAssertEqual(
            BillExactness.compare(draft: draft(items: []), truth: truth).causes.first,
            .noItemsParsed
        )
    }

    func testWrongQuantityBreaksExactnessButNotAmounts() {
        let result = BillExactness.compare(draft: draft(items: [(1450, 1), (1050, 1)]), truth: truth)
        XCTAssertFalse(result.exact)
        XCTAssertTrue(result.amountsExact)
        XCTAssertEqual(result.causes, [.itemQuantityWrong])
    }

    func testMissingFooterFieldsAndAdjustments() {
        let result = BillExactness.compare(
            draft: draft(adjustments: [], subtotal: nil, tax: nil, tip: nil, total: nil),
            truth: truth
        )
        XCTAssertEqual(
            Set(result.causes),
            [.adjustmentWrong, .subtotalMissing, .taxMissing, .tipMissing, .totalMissing]
        )
    }

    func testReceiptWithoutTaxOrTipAcceptsNoneOrZero() {
        let plain = StressBillTruth(
            items: [GroundTruthItem(name: "Pan", quantity: 1, lineTotalMinor: 350)],
            subtotalMinor: 350,
            totalMinor: 350
        )
        let base = draft(items: [(350, 1)], adjustments: [], subtotal: 350, tax: nil, tip: nil, total: 350)
        XCTAssertTrue(BillExactness.compare(draft: base, truth: plain).exact)
        var zero = base
        zero.tax = DraftAmount(minorUnits: 0)
        XCTAssertTrue(BillExactness.compare(draft: zero, truth: plain).exact)
        var invented = base
        invented.tip = DraftAmount(minorUnits: 100)
        XCTAssertEqual(BillExactness.compare(draft: invented, truth: plain).causes, [.tipWrong])
    }

    func testFlaggedDraftsAreNotSilent() {
        XCTAssertFalse(BillExactness.isFlagged(draft()))
        XCTAssertTrue(BillExactness.isFlagged(draft(reconciles: false)))
        var withIssue = draft()
        withIssue.issues = [.unparsedPriceRow("00901")]
        XCTAssertTrue(BillExactness.isFlagged(withIssue))
        var withFlag = draft()
        withFlag.items[0].flags = [.needsReview]
        XCTAssertTrue(BillExactness.isFlagged(withFlag))
        var withInfoFlag = draft()
        withInfoFlag.items[0].flags = [.priceOnNextRow]
        XCTAssertFalse(BillExactness.isFlagged(withInfoFlag))
        var attention = draft()
        attention.tax = DraftAmount(minorUnits: 264, needsAttention: true)
        XCTAssertTrue(BillExactness.isFlagged(attention))
    }
}

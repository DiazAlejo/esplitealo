import XCTest
@testable import EsplitealoCore
import EsplitealoTestSupport

/// Numbers that are printed on a receipt but are not prices: street numbers, zip codes, table and tab numbers, item
/// counts, tip suggestions. Found by the receipt stress test (docs/OCR_BENCHMARK.md).
final class ReceiptParserHeaderNoiseTests: XCTestCase {
    private let parser = ReceiptParser()

    private func parse(_ rows: [String]) -> ReceiptDraft {
        parser.parse(RecognizedTextTestBuilder.fromRowTexts(rows))
    }

    func testStreetNumberZipCodeAndTabNumberAreNotItems() {
        let draft = parse([
            "Restaurante La Ceiba",
            "Calle Luna 123",
            "Ponce, PR 00717",
            "Tel: 787-555-0100",
            "Tab #41 Bar 4",
            "Mofongo 14.50",
            "Subtotal 14.50",
            "IVU 11.5% 1.67",
            "Total 16.17"
        ])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1450])
        XCTAssertEqual(draft.subtotal?.minorUnits, 1450)
        XCTAssertEqual(draft.total?.minorUnits, 1617)
        XCTAssertTrue(draft.reconciles)
        XCTAssertEqual(draft.issues, [])
    }

    func testStreetNumberBeforeAHeaderTotalDoesNotHideTheItems() {
        let draft = parse([
            "Pastelillos Doña Lola",
            "Carr. 2 Km 14",
            "TOTAL $46.46",
            "Order #778 To go",
            "Nuggets 10 pc $6.63",
            "Milkshake $4.57",
            "Subtotal $11.20",
            "Tax 11.5% $1.29",
            "TOTAL $12.49"
        ])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [663, 457])
        XCTAssertEqual(draft.total?.minorUnits, 1249)
        XCTAssertTrue(draft.reconciles)
    }

    func testWholeNumberPricesStillWorkWhenNoPriceHasCents() {
        let draft = parse(["Café 3", "Pan 2", "Total 5"])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [300, 200])
        XCTAssertEqual(draft.total?.minorUnits, 500)
    }

    func testLocalAndUnitNumbersWithLettersAreNotPrices() {
        let draft = parse([
            "Plaza Las Flores, Local 12A",
            "Urb. Los Pinos, Calle 4 B-2",
            "Pan sobao 3.50",
            "Total 3.50"
        ])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [350])
        XCTAssertEqual(draft.issues, [])
    }

    func testItemCountLineIsNotAnItemOrATotal() {
        for countLine in ["Items: 2", "Artículos: 2", "Total de artículos: 2", "Item count: 2", "Total items: 2"] {
            let draft = parse([
                "Pan 3.50",
                "Leche 2.00",
                countLine,
                "Subtotal 5.50",
                "IVU Estatal 10.5% 0.58",
                "IVU Municipal 1% 0.06",
                "Total 6.14"
            ])
            XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [350, 200], countLine)
            XCTAssertEqual(draft.tax?.minorUnits, 64, "both tax lines count after \(countLine)")
            XCTAssertEqual(draft.total?.minorUnits, 614, countLine)
            XCTAssertTrue(draft.reconciles, countLine)
        }
    }

    func testSpanishTipSuggestionsAfterTheTotalAreNotTheTip() {
        let draft = parse([
            "Mofongo 14.50",
            "Subtotal 14.50",
            "IVU 11.5% 1.67",
            "Total 16.17",
            "Propina sugerida 15%: $2.18",
            "Propina sugerida 18%: $2.61",
            "Propina sugerida 20%: $2.90"
        ])
        XCTAssertNil(draft.tip)
        XCTAssertEqual(draft.total?.minorUnits, 1617)
        XCTAssertTrue(draft.reconciles)
    }

    func testLeadingQuantityBeforeAnItemNameIsReadAndFlagged() {
        let draft = parse(["4 Double Burger 25.00", "Fries 4.50", "Total 29.50"])
        XCTAssertEqual(draft.items.map(\.quantity), [4, 1])
        XCTAssertEqual(draft.items.map(\.name), ["Double Burger", "Fries"])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [2500, 450])
        // The number could be part of the name ("7 Up"), so the row is left for review.
        XCTAssertTrue(draft.items[0].flags.contains(.needsReview))
        XCTAssertTrue(draft.items[1].flags.isEmpty)
    }

    func testOneBeforeAnItemNameStaysAPlainQuantityOfOne() {
        let draft = parse(["1 Sparkling Water 3.25", "Total 3.25"])
        XCTAssertEqual(draft.items.map(\.quantity), [1])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [325])
    }

    func testServiceChargeIsATipNotAPaymentLine() {
        let draft = parse([
            "Rum & Coke 10.00",
            "Sub Total 10.00",
            "Service Charge 18% 1.80",
            "State Tax (10.5%) 1.05",
            "Municipal Tax (1%) 0.10",
            "Total Due 12.95"
        ])
        XCTAssertEqual(draft.tip?.minorUnits, 180)
        XCTAssertEqual(draft.tax?.minorUnits, 115)
        XCTAssertTrue(draft.reconciles)
    }

    func testQuantityPrefixOnAWrappedNameWithThePriceOnTheLastRow() {
        let draft = parse([
            "Papas fritas 10.15",
            "3 x Pastelillo de",
            "carne 21.15",
            "Hamburguesa doble 10.35",
            "Subtotal 41.65",
            "Total 41.65"
        ])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1015, 2115, 1035])
        XCTAssertEqual(draft.items.map(\.quantity), [1, 3, 1])
        XCTAssertEqual(draft.items[1].name, "Pastelillo de carne")
        XCTAssertTrue(draft.items[1].flags.contains(.needsReview))
        XCTAssertTrue(draft.reconciles)
    }

    func testHeaderTextAboveTheFirstItemIsNotMergedIntoIt() {
        let draft = parse(["Mesero: María", "Dec 21, 2026 08:15AM", "Papas fritas 10.15", "Total 10.15"])
        XCTAssertEqual(draft.items.map(\.name), ["Papas fritas"])
    }
}

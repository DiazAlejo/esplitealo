import XCTest
@testable import EsplitealoCore

final class ReceiptParserTests: XCTestCase {
    private let parser = ReceiptParser()

    func testSimpleEnglishReceipt() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "THE CORNER BISTRO",
            "Table 12 03/04/2026 19:45",
            "2 x Margherita Pizza 25.00",
            "Caesar Salad 9.50",
            "1 Sparkling Water 3.25",
            "Subtotal 37.75",
            "Sales Tax 8% 3.02",
            "TOTAL $40.77",
            "VISA ****1234 $40.77"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [2500, 950, 325])
        XCTAssertEqual(draft.items.map(\.quantity), [2, 1, 1])
        XCTAssertEqual(draft.subtotal?.minorUnits, 3775)
        XCTAssertEqual(draft.tax?.minorUnits, 302)
        XCTAssertEqual(draft.total?.minorUnits, 4077)
        XCTAssertTrue(draft.reconciles)
    }

    func testPuertoRicoSpanishIVU() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Restaurante El Jibarito",
            "San Juan PR",
            "Mofongo 14.50",
            "Arroz con gandules 8.00",
            "Subtotal 22.50",
            "IVU 11.5% 2.59",
            "Propina sugerida 4.50",
            "Total 29.59"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 2)
        XCTAssertEqual(draft.tax?.minorUnits, 259)
        XCTAssertEqual(draft.total?.minorUnits, 2959)
        XCTAssertTrue(draft.reconciles)
    }

    func testCommaDecimalReceipt() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Café Central",
            "Café con leche 3,50",
            "Tostada 2,25",
            "Subtotal 5,75",
            "IVA 10% 0,58",
            "Total 6,33"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.numberFormat.decimalSeparator, ",")
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [350, 225])
        XCTAssertEqual(draft.total?.minorUnits, 633)
        XCTAssertTrue(draft.reconciles)
    }

    func testSeparateVisionLinesForNameAndPrice() {
        let text = RecognizedTextTestBuilder.fromNamePricePairs([
            ("Jasmine Tea", "4.50"),
            ("Empanada", "3.25"),
            ("Subtotal", "7.75"),
            ("Tax", "0.62"),
            ("Total", "8.37")
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [450, 325])
        XCTAssertEqual(draft.total?.minorUnits, 837)
        XCTAssertTrue(draft.reconciles)
    }

    func testSuggestedTipAndPaymentAreNotItems() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Burger 12.00",
            "Suggested tip",
            "15% 1.80",
            "18% 2.16",
            "Subtotal 12.00",
            "Total 12.00",
            "Cash 20.00",
            "Change 8.00"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.items[0].lineTotal.minorUnits, 1200)
    }

    func testMismatchIsFlaggedNeverHidden() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Burger 12.00",
            "Fries 4.00",
            "Subtotal 20.00",
            "Total 20.00"
        ])
        let draft = parser.parse(text)
        XCTAssertFalse(draft.reconciles)
        XCTAssertEqual(draft.total?.minorUnits, 2000)
        XCTAssertTrue(draft.issues.contains {
            if case .itemsDoNotMatchSubtotal = $0 { return true }
            return false
        })
    }

    func testPhoneAndDateDoNotBecomePrices() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "555-0142",
            "03/14/2026",
            "Coffee 3.50",
            "Total 3.50"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.items[0].lineTotal.minorUnits, 350)
    }

    func testTotalBeforeItemsStillParsesFooter() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Total 15.00",
            "Burger 10.00",
            "Fries 5.00",
            "Subtotal 15.00"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.total?.minorUnits, 1500)
        XCTAssertGreaterThanOrEqual(draft.items.count, 1)
    }

    func testMissingSubtotalUsesTotalMinusTax() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Soup 6.00",
            "Salad 8.00",
            "Tax 1.12",
            "Total 15.12"
        ])
        let draft = parser.parse(text)
        XCTAssertNil(draft.subtotal)
        XCTAssertEqual(draft.tax?.minorUnits, 112)
        XCTAssertTrue(draft.reconciles)
    }

    func testDuplicateItemNames() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Taco 4.00",
            "Taco 4.00",
            "Subtotal 8.00",
            "Total 8.00"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 2)
        XCTAssertEqual(draft.items.map(\.name), ["Taco", "Taco"])
        XCTAssertTrue(draft.reconciles)
    }

    func testNegativeDiscount() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Entree 20.00",
            "Descuento -5.00",
            "Subtotal 15.00",
            "Total 15.00"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.adjustments.count, 1)
        XCTAssertEqual(draft.adjustments[0].amount.minorUnits, -500)
        XCTAssertTrue(draft.reconciles)
    }

    func testQuantityAtPrefix() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "2 @ Tacos 18.00",
            "Subtotal 18.00",
            "Total 18.00"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.first?.quantity, 2)
    }

    func testFuzzySubtotalKeyword() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Item 9.99",
            "Sub Tofal 9.99",
            "Total 9.99"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.subtotal?.minorUnits, 999)
        XCTAssertTrue(draft.reconciles)
    }

    func testCashAndChangeAfterTotalAreNotItems() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Cinnamon Latte 5.50",
            "Subtotal 5.50",
            "Grand Total 5.50",
            "CASH 20.00",
            "CHANGE DUE 14.50",
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 1)
        XCTAssertEqual(draft.total?.minorUnits, 550)
    }

    func testCardSlipLineIsNotAnItem() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Tea 4.00",
            "Subtotal 4.00",
            "Total 4.00",
            "EDC CIMB NIAGA No: xx7730 4.00",
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 1)
    }

    func testQtyFooterLineIsNotAnItem() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Soup 6.00",
            "Subtotal 6.00",
            "Total 6.00",
            "(Qty 2.00) 2.00",
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 1)
    }

    func testSharedAppetizerStyle() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Mesa 7",
            "Nachos grandes 12.00",
            "2 x Medalla 7.00",
            "Pollo a la plancha 16.50",
            "Subtotal 35.50",
            "Servicio 7.10",
            "IVU 4.08",
            "Total 46.68"
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 3)
        XCTAssertEqual(draft.tip?.minorUnits, 710)
        XCTAssertEqual(draft.tax?.minorUnits, 408)
        XCTAssertEqual(draft.total?.minorUnits, 4668)
    }
}

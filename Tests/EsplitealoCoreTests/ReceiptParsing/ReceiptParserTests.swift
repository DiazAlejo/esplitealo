import XCTest
@testable import EsplitealoCore
import EsplitealoTestSupport

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

    func testNoColonInsideWordDoesNotDropItem() {
        let text = RecognizedTextTestBuilder.fromRowTexts([
            "Casino: Platter 12.00",
            "Tea 4.00",
            "Subtotal 16.00",
            "Total 16.00",
        ])
        let draft = parser.parse(text)
        XCTAssertEqual(draft.items.count, 2)
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

    // MARK: - Multi-row names, quantity rows, multiple taxes, payment blocks

    /// Column-aligned receipt: names on the left, prices in a right-hand column on the same row.
    private func columnReceipt(_ rows: [(left: String, right: String?)]) -> RecognizedText {
        let lineHeight = 60.0
        var lines: [RecognizedLine] = []
        for (index, row) in rows.enumerated() {
            let y = Double(index) * lineHeight + 20
            func line(_ text: String, x: Double) -> RecognizedLine {
                var cursor = x
                var words: [RecognizedWord] = []
                for word in text.split(separator: " ") {
                    let width = Double(word.count) * 20
                    words.append(RecognizedWord(
                        text: String(word),
                        rect: PixelRect(x: cursor, y: y, width: width, height: 40)
                    ))
                    cursor += width + 14
                }
                let rect = words.dropFirst().reduce(words[0].rect) { $0.union($1.rect) }
                return RecognizedLine(text: text, confidence: 1, rect: rect, baselineAngle: 0, words: words)
            }
            lines.append(line(row.left, x: 40))
            if let right = row.right { lines.append(line(right, x: 1000)) }
        }
        return RecognizedText(
            imageSize: ImageSize(width: 1300, height: Double(rows.count) * lineHeight + 40),
            lines: lines
        )
    }

    func testWrappedNameWithModifierAndQuantityRowIsOneItem() {
        let draft = parser.parse(columnReceipt([
            ("Items", "Price"),
            ("Party Hat", "$34.50"),
            ("Black", nil),
            ("(3 x $11.50)", nil),
            ("Party Hat", "$11.50"),
            ("Brown", nil),
            ("Subtotal", "$46.00"),
            ("State Tax (10.5%)", "$4.83"),
            ("County Tax (1%)", "$0.47"),
            ("Total", "$51.30")
        ]))
        XCTAssertEqual(draft.items.map(\.name), ["Party Hat Black", "Party Hat Brown"])
        XCTAssertEqual(draft.items.map(\.quantity), [3, 1])
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [3450, 1150])
        XCTAssertEqual(draft.items.map { $0.unitPrice?.minorUnits }, [1150, nil], "only a printed quantity row sets a unit price")
        XCTAssertTrue(draft.items.allSatisfy { $0.flags.isEmpty })
        XCTAssertEqual(draft.tax?.minorUnits, 530)
        XCTAssertTrue(draft.reconciles)
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
    }

    func testSpanishHeadersAndQuantityRowWithoutParentheses() {
        let draft = parser.parse(columnReceipt([
            ("Artículo", "Precio"),
            ("Camisa de lino", "$30.00"),
            ("Azul", nil),
            ("2 x $15.00", nil),
            ("Subtotal", "$30.00"),
            ("IVU Estatal (10.5%)", "$3.15"),
            ("IVU Municipal (1%)", "$0.30"),
            ("Total", "$33.45")
        ]))
        XCTAssertEqual(draft.items.map(\.name), ["Camisa de lino Azul"])
        XCTAssertEqual(draft.items.map(\.quantity), [2])
        XCTAssertEqual(draft.items.first?.unitPrice?.minorUnits, 1500)
        XCTAssertEqual(draft.tax?.minorUnits, 345)
        XCTAssertEqual(draft.total?.minorUnits, 3345)
        XCTAssertTrue(draft.reconciles)
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
    }

    func testQuantityRowWithoutModifierRow() {
        let draft = parser.parse(columnReceipt([
            ("Balloon Pack", "$9.00"),
            ("(3 x $3.00)", nil),
            ("Subtotal", "$9.00"),
            ("Total", "$9.00")
        ]))
        XCTAssertEqual(draft.items.map(\.name), ["Balloon Pack"])
        XCTAssertEqual(draft.items.map(\.quantity), [3])
        XCTAssertEqual(draft.items.first?.unitPrice?.minorUnits, 300)
        XCTAssertTrue(draft.items.allSatisfy { $0.flags.isEmpty })
    }

    func testQuantityRowThatDisagreesWithLineTotalStaysFlagged() {
        let draft = parser.parse(columnReceipt([
            ("Party Hat", "$30.00"),
            ("Black", nil),
            ("(3 x $11.50)", nil),
            ("Subtotal", "$30.00"),
            ("Total", "$30.00")
        ]))
        XCTAssertEqual(draft.items.count, 1)
        let item = draft.items[0]
        XCTAssertEqual(item.lineTotal.minorUnits, 3000, "the printed line total is never rewritten")
        XCTAssertTrue(item.flags.contains(.quantityMismatch))
        XCTAssertTrue(item.flags.contains(.needsReview))
    }

    func testAllTaxLinesAreSummed() {
        let draft = parser.parse(RecognizedTextTestBuilder.fromRowTexts([
            "Gift Box 20.00",
            "Subtotal 20.00",
            "STATE TAX (10.5%) 2.10",
            "COUNTY TAX (1%) 0.20",
            "Total 22.30"
        ]))
        XCTAssertEqual(draft.tax?.minorUnits, 230)
        XCTAssertTrue(draft.reconciles)
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
    }

    func testHeaderTotalThatAgreesWithBottomTotalIsAccepted() {
        let draft = parser.parse(columnReceipt([
            ("TOTAL", "$11.50"),
            ("Items", "Price"),
            ("Party Hat", "$10.00"),
            ("Subtotal", "$10.00"),
            ("Tax (15%)", "$1.50"),
            ("Total", "$11.50")
        ]))
        XCTAssertEqual(draft.total?.minorUnits, 1150)
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1000])
        XCTAssertTrue(draft.reconciles)
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
    }

    func testHeaderTotalNeverOverridesBottomTotal() {
        let draft = parser.parse(columnReceipt([
            ("TOTAL", "$9.99"),
            ("Items", "Price"),
            ("Party Hat", "$10.00"),
            ("Subtotal", "$10.00"),
            ("Tax (15%)", "$1.50"),
            ("Total", "$11.50")
        ]))
        XCTAssertEqual(draft.total?.minorUnits, 1150)
    }

    func testPaymentBlockAfterTotalNeverCreatesIssues() {
        let draft = parser.parse(columnReceipt([
            ("Party Hat", "$11.50"),
            ("Subtotal", "$11.50"),
            ("Total", "$11.50"),
            ("Transaction Record", nil),
            ("Visa Purchase", nil),
            ("AUTHORIZED", "$11.50"),
            ("Jun 17, 2026, 02:03PM", nil),
            ("VISA DEBIT", nil),
            ("(A0000000031010)", nil),
            ("AID: A0000000031010", nil),
            ("MID: 000012345678", nil),
            ("TSI: 0000", nil),
            ("Receipt: #1-00000", nil),
            ("Verification not required", nil)
        ]))
        XCTAssertEqual(draft.items.map(\.lineTotal.minorUnits), [1150])
        XCTAssertTrue(draft.reconciles)
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
    }
}

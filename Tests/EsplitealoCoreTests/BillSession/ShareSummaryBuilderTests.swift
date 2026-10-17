import XCTest
@testable import EsplitealoCore

final class ShareSummaryBuilderTests: XCTestCase {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testSpanishShareTextGolden() {
        let session = BillSession.sampleReadyToShare()
        let text = ShareSummaryBuilder.build(for: session, language: .es, calendar: utc)
        XCTAssertEqual(text, """
            Fonda Doña Lola · 13 oct
            Cuenta $110.00 + propina 20% $20.00 = $130.00

            Alex debe $78.00
              artículos $60.00 · impuesto $6.00 · propina $12.00

            Sam debe $52.00
              artículos $40.00 · impuesto $4.00 · propina $8.00

            Todo cuadra en $130.00. Esplitéalo y listo 🦝

            """)
    }

    func testEnglishShareTextGolden() {
        let session = BillSession.sampleReadyToShare()
        let text = ShareSummaryBuilder.build(for: session, language: .en, calendar: utc)
        XCTAssertEqual(text, """
            Fonda Doña Lola · Oct 13
            Bill $110.00 + 20% tip $20.00 = $130.00

            Alex owes $78.00
              items $60.00 · tax $6.00 · tip $12.00

            Sam owes $52.00
              items $40.00 · tax $4.00 · tip $8.00

            Adds up to $130.00. Split with Esplitéalo

            """)
    }

    // MARK: Header line without a merchant name or a date

    private func shareText(merchant: String, date: Date?, language: ShareLanguage) -> String {
        var session = BillSession.sampleReadyToShare()
        session.merchantName = merchant
        session.date = date
        return ShareSummaryBuilder.build(for: session, language: language, calendar: utc)
    }

    func testHeaderIsDroppedWhenMerchantAndDateAreEmpty() {
        let es = shareText(merchant: "", date: nil, language: .es)
        let en = shareText(merchant: "", date: nil, language: .en)
        XCTAssertTrue(es.hasPrefix("Cuenta $110.00 + propina 20% $20.00 = $130.00\n"), es)
        XCTAssertTrue(en.hasPrefix("Bill $110.00 + 20% tip $20.00 = $130.00\n"), en)
        for text in [es, en] {
            XCTAssertFalse(text.contains("·\n"), text)
            XCTAssertFalse(text.hasPrefix(" "), text)
            XCTAssertFalse(text.hasPrefix("\n"), text)
        }
    }

    func testHeaderKeepsOnlyTheDateWhenThereIsNoMerchant() {
        let day = date(2025, 10, 13, in: utc)
        let es = shareText(merchant: "", date: day, language: .es)
        let en = shareText(merchant: "", date: day, language: .en)
        XCTAssertTrue(es.hasPrefix("13 oct\nCuenta $110.00"), es)
        XCTAssertTrue(en.hasPrefix("Oct 13\nBill $110.00"), en)
        XCTAssertFalse(es.contains(" · \n") || es.hasPrefix(" ·"), es)
        XCTAssertFalse(en.contains(" · \n") || en.hasPrefix(" ·"), en)
    }

    func testHeaderKeepsOnlyTheMerchantWhenThereIsNoDate() {
        let es = shareText(merchant: "Fonda Doña Lola", date: nil, language: .es)
        let en = shareText(merchant: "Fonda Doña Lola", date: nil, language: .en)
        XCTAssertTrue(es.hasPrefix("Fonda Doña Lola\nCuenta $110.00"), es)
        XCTAssertTrue(en.hasPrefix("Fonda Doña Lola\nBill $110.00"), en)
    }

    func testWhitespaceOnlyMerchantCountsAsEmpty() {
        let es = shareText(merchant: "  \n", date: nil, language: .es)
        XCTAssertTrue(es.hasPrefix("Cuenta $110.00"), es)
    }

    func testShareTextIncludesServiceWhenPresent() {
        var session = BillSession.sampleWithServiceChargeAssigned()
        let text = ShareSummaryBuilder.build(for: session, language: .en, calendar: utc)
        XCTAssertTrue(text.contains("(includes service $15.15)"))
        XCTAssertTrue(text.contains(" · service "))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("monto"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("IVU"))
    }

    /// A tip printed on the receipt (no service charge set) is shared like a service charge. Its share used to be left
    /// out of the person's lines, so "items + tax + tip" did not add up to what the person owes.
    func testPrintedReceiptTipIsInEveryPersonsLinesAndTheLinesAddUp() {
        let session = BillSession.sampleReadyToShareWithPrintedTip()
        XCTAssertEqual(session.serviceChargeCents, 0)
        XCTAssertEqual(session.receiptTipOnBillCents, 2000)
        let text = ShareSummaryBuilder.build(for: session, language: .en, calendar: utc)
        XCTAssertEqual(text, """
            Fonda Doña Lola · Oct 13
            Bill $130.00 + 0% tip $0.00 = $130.00

            Alex owes $78.00
              items $60.00 · tax $6.00 · service $12.00 · tip $0.00

            Sam owes $52.00
              items $40.00 · tax $4.00 · service $8.00 · tip $0.00

            Adds up to $130.00. Split with Esplitéalo

            """)
    }

    func testEveryPersonsLinesAddUpToTheirAmountWithAServiceChargeOrAPrintedTipAndLeftoverCents() throws {
        for base in [BillSession.sampleWithServiceChargeAssigned(), BillSession.sampleReadyToShareWithPrintedTip()] {
            var session = base
            // A third person and a shared item make the tip, tax and service shares come out in uneven cents.
            _ = session.addParticipant(name: "Chris")
            let item = session.draft.items[0]
            session.assignUnit(itemID: item.id, unitIndex: 0, participantIDs: session.participants.map(\.id))
            session.tip = .percentage(percent: 18, basis: .preTaxSubtotal)
            for language in [ShareLanguage.es, .en] {
                let text = ShareSummaryBuilder.build(for: session, language: language, calendar: utc)
                let blocks = text.components(separatedBy: "\n\n").dropFirst().dropLast()
                XCTAssertEqual(blocks.count, session.participants.count)
                var sum = 0
                for block in blocks {
                    let amounts = try block.matches(of: /\$([0-9]+)\.([0-9]{2})/).map { Int($0.1)! * 100 + Int($0.2)! }
                    let (owed, parts) = (try XCTUnwrap(amounts.first), amounts.dropFirst())
                    XCTAssertEqual(parts.reduce(0, +), owed, "\(block)")
                    sum += owed
                }
                XCTAssertEqual(sum, session.confirmedBillTotalCents)
            }
        }
    }

    func testDateHeaderIsFormattedPerLanguage() {
        var session = BillSession.sampleReadyToShare()
        session.date = date(2026, 1, 5, in: utc)
        XCTAssertTrue(ShareSummaryBuilder.build(for: session, language: .es, calendar: utc).hasPrefix("Fonda Doña Lola · 5 ene\n"))
        XCTAssertTrue(ShareSummaryBuilder.build(for: session, language: .en, calendar: utc).hasPrefix("Fonda Doña Lola · Jan 5\n"))
    }

    func testEveryMonthHasAShortNameInBothLanguages() {
        let spanish = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        let english = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var session = BillSession.sampleReadyToShare()
        for month in 1 ... 12 {
            session.date = date(2026, month, 20, in: utc)
            let es = ShareSummaryBuilder.build(for: session, language: .es, calendar: utc)
            let en = ShareSummaryBuilder.build(for: session, language: .en, calendar: utc)
            XCTAssertTrue(es.hasPrefix("Fonda Doña Lola · 20 \(spanish[month - 1])\n"), es)
            XCTAssertTrue(en.hasPrefix("Fonda Doña Lola · \(english[month - 1]) 20\n"), en)
        }
    }

    func testDateUsesTheCallersTimeZoneNotTheDeviceOne() {
        var puertoRico = Calendar(identifier: .gregorian)
        puertoRico.timeZone = TimeZone(identifier: "America/Puerto_Rico")!
        var session = BillSession.sampleReadyToShare()
        // 01:30 UTC on Oct 14 is still the evening of Oct 13 in Puerto Rico (UTC-4).
        session.date = date(2026, 10, 14, hour: 1, in: utc).addingTimeInterval(30 * 60)
        XCTAssertTrue(ShareSummaryBuilder.build(for: session, language: .en, calendar: puertoRico).hasPrefix("Fonda Doña Lola · Oct 13\n"))
        XCTAssertTrue(ShareSummaryBuilder.build(for: session, language: .en, calendar: utc).hasPrefix("Fonda Doña Lola · Oct 14\n"))
    }
}

import XCTest
@testable import EsplitealoCore

final class ShareSummaryBuilderTests: XCTestCase {
    func testSpanishShareTextGolden() {
        let session = BillSession.sampleReadyToShare()
        let text = ShareSummaryBuilder.build(for: session, language: .es)
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
        let text = ShareSummaryBuilder.build(for: session, language: .en)
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

    func testShareTextIncludesServiceWhenPresent() {
        var session = BillSession.sampleWithServiceChargeAssigned()
        let text = ShareSummaryBuilder.build(for: session, language: .en)
        XCTAssertTrue(text.contains("(includes service $15.15)"))
        XCTAssertTrue(text.contains(" · service "))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("monto"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("IVU"))
    }
}

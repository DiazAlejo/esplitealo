import XCTest

/// Whole bills, from the scan to the share and "new bill", with nothing but taps and typed names: no fixture bill, only
/// a committed real receipt read by the real parser.
///
/// The numbers are worked out by hand from the receipts:
///
/// - `bistro`: Mofongo $14.50 and Arroz con gandules $8.00, $2.59 tax, 20% tip before tax ($4.50), so $29.59 in all.
///   Ana has the mofongo: $14.50 + $1.67 tax + $2.90 tip = $19.07. Luis has the rice: $8.00 + $0.92 + $1.60 = $10.52.
/// - `partyStore`: 3 hats at $11.50 and 1 hat at $11.50, tax $4.83 + $0.47 = $5.30, tip $9.20, so $60.50.
final class JourneyHappyPathUITests: JourneyTestCase {
    // MARK: Scan to share

    @MainActor
    func testScanToShareToANewBillInSpanish() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        XCTAssertTrue(element(app, "review.banner").label.contains("Todo quedó nítido"), element(app, "review.banner").label)
        XCTAssertTrue(reviewRow("Mofongo", in: app).exists)
        XCTAssertTrue(reviewRow("Arroz con gandules", in: app).exists)

        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)

        expectScreen("mark", in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 2")
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "Chequear el espliteo")
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        XCTAssertTrue(element(app, "totals.person.0").label.contains("Ana"))
        XCTAssertTrue(element(app, "totals.person.1").label.contains("Luis"))
        share(app, previewContains: ["Ana debe $19.07", "Luis debe $10.52", "Todo cuadra en $29.59"], successTitle: "¡Wepa! Cuentas claras.")

        app.buttons["success.again"].tap()
        expectScreen("home", in: app)
        XCTAssertFalse(element(app, "home.resume").exists, "a finished bill is not offered")

        // The finished bill is gone for good: a relaunch has nothing to continue.
        backgroundAndTerminate(app)
        var again = Options(draftDirectory: directory)
        again.receipt = nil
        let relaunched = launch(again)
        expectScreen("home", in: relaunched)
        XCTAssertFalse(relaunched.alerts.firstMatch.waitForExistence(timeout: 1))
        XCTAssertFalse(element(relaunched, "home.resume").exists)
    }

    @MainActor
    func testScanToShareToANewBillInEnglish() {
        let app = launch(Options().english)
        scan(app)
        XCTAssertTrue(element(app, "review.banner").label.contains("Everything adds up"), element(app, "review.banner").label)
        XCTAssertEqual(app.buttons["screen.next"].label, "Continue to people")
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Assign items")
        tapNext(app)

        expectScreen("mark", in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Review split · 2 left")
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "Review split")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Adds up to $29.59")
        XCTAssertEqual(app.buttons["totals.share"].label, "Share breakdown")
        share(app, previewContains: ["Ana owes $19.07", "Luis owes $10.52"], successTitle: "All settled up!")
        app.buttons["success.again"].tap()
        expectScreen("home", in: app)
        XCTAssertEqual(app.buttons["home.scan"].label, "Scan receipt")
    }

    /// A shared bill is done even when the person never taps "new bill": the app is closed on the success moment.
    @MainActor
    func testClosingTheAppOnTheSuccessMomentDoesNotBringTheBillBack() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo", "Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        share(app, previewContains: ["Ana debe $29.59"], successTitle: "¡Wepa! Cuentas claras.")

        backgroundAndTerminate(app)
        var again = Options(draftDirectory: directory)
        again.receipt = nil
        let relaunched = launch(again)
        expectScreen("home", in: relaunched)
        XCTAssertFalse(relaunched.alerts.firstMatch.waitForExistence(timeout: 1))
        XCTAssertFalse(element(relaunched, "home.resume").exists)
    }

    // MARK: Quantity lines

    @MainActor
    func testALineOfSeveralUnitsIsMarkedUnitByUnitAndTheCentsStillAddUp() {
        var options = Options()
        options.receipt = .partyStore
        let app = launch(options)
        scan(app)
        XCTAssertTrue(element(app, "review.banner").label.contains("Todo quedó nítido"), element(app, "review.banner").label)
        tapNext(app)
        addPeople(["Ana", "Luis", "Keishla"], in: app)
        tapNext(app)

        expectScreen("mark", in: app)
        let hats = itemRow("Negro", in: app)
        XCTAssertTrue(hats.waitForExistence(timeout: 10))
        XCTAssertTrue(hats.label.contains("3 unidades"), hats.label)

        // One hat each for the three of them, and the brown one for Ana.
        markUnits(of: "Negro", [[0], [1], [2]], in: app)
        XCTAssertFalse(hats.label.contains("sin marcar"), hats.label)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 1")
        paint(person: 0, items: ["Marrón"], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "Chequear el espliteo")
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $60.50")
        // Ana: two hats ($23.00) + half the tax ($2.65) + 20% of her items ($4.60) = $30.25.
        share(app, previewContains: ["Ana debe $30.25", "Luis debe $15.1", "Keishla debe $15.1", "Todo cuadra en $60.50"], successTitle: "¡Wepa! Cuentas claras.")
    }

    @MainActor
    func testTwoHatsForOnePersonAndOneForAnotherSplitTheLineByUnit() {
        var options = Options()
        options.receipt = .partyStore
        let app = launch(options)
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)

        expectScreen("mark", in: app)
        markUnits(of: "Negro", [[0], [0], [1]], in: app)
        paint(person: 1, items: ["Marrón"], in: app)
        waitForLabel(element(app, "assign.chip.0"), containing: "23 dólares")
        waitForLabel(element(app, "assign.chip.1"), containing: "23 dólares")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $60.50")
        // Both pay $23.00 + $2.65 + $4.60 = $30.25.
        share(app, previewContains: ["Ana debe $30.25", "Luis debe $30.25"], successTitle: "¡Wepa! Cuentas claras.")
    }

    // MARK: Two tax lines

    @MainActor
    func testAReceiptWithTwoTaxLinesCountsBothInTheTotal() {
        var options = Options()
        options.receipt = .partyStore
        let app = launch(options)
        scan(app)
        // $46.00 + $4.83 + $0.47 = $51.30: the receipt adds up only if both tax lines were read.
        XCTAssertTrue(element(app, "review.banner").label.contains("Todo quedó nítido"), element(app, "review.banner").label)
        XCTAssertFalse(element(app, "review.warnings").exists)
        tapNext(app)
        addPeople(["Ana"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Negro", "Marrón"], in: app)
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $60.50")
        share(app, previewContains: ["Ana debe $60.50", "impuesto $5.30"], successTitle: "¡Wepa! Cuentas claras.")
    }
}

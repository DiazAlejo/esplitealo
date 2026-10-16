import XCTest

/// The Totals and Share screens, driven the way a person uses them. The app starts from a fixture bill
/// (`--fixture=<name> --start-at=totals`, honoured only with `--uitesting`):
///
/// - `complete`: four people, every item marked, a balanced receipt, the default 20% tip.
/// - `midway`: two items still unmarked.
/// - `mismatch`: everything marked, but the flan was read as $19.00 and the user went on anyway.
/// - `service`: the receipt already has a $15.15 service charge, so the tip starts at $0.00.
///
/// `--uitesting-share complete|cancel` replaces the system share sheet (which a test cannot drive on every runtime)
/// with an immediate "sent" or "cancelled".
final class TotalsFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(fixture: String = "complete", language: String = "es", region: String = "PR", share: String = "complete", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting", "--fixture=\(fixture)", "--start-at=totals", "--uitesting-share", share,
            "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)",
        ] + extra
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("expected a label containing \"\(text)\", got \"\(element.label)\"", file: file, line: line)
        }
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0 ..< 6 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    // MARK: Reconciled

    @MainActor
    func testABalancedBillShowsWhatEachPersonOwesAndCanBeShared() {
        let app = launch()
        XCTAssertTrue(element(app, "screen.totals").waitForExistence(timeout: 15))
        let banner = element(app, "totals.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("Suma $132.82"), banner.label)
        XCTAssertTrue(app.buttons["totals.share"].isEnabled)
        XCTAssertFalse(element(app, "totals.blocked").exists)

        let marisol = element(app, "totals.person.0")
        XCTAssertTrue(marisol.exists)
        XCTAssertTrue(marisol.label.contains("Marisol"), marisol.label)
        XCTAssertTrue(marisol.label.contains("artículos"), marisol.label)
        XCTAssertTrue(element(app, "totals.person.3").exists, "all four people are listed")
    }

    @MainActor
    func testChoosingATipPercentageUpdatesTheTotalsAtOnce() {
        let app = launch()
        XCTAssertTrue(app.buttons["totals.tip.preset.15"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["totals.tip.preset.20"].isSelected, "20% before tax is the default")
        app.buttons["totals.tip.preset.15"].tap()
        waitForLabel(element(app, "totals.banner"), containing: "Suma $127.77")
        XCTAssertTrue(app.buttons["totals.tip.preset.15"].isSelected)
        XCTAssertFalse(app.buttons["totals.tip.preset.20"].isSelected)
    }

    @MainActor
    func testTheTipCanBeMeasuredOnTheTotalWithTax() {
        let app = launch()
        let toggle = app.switches["totals.tip.postTax"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        app.buttons["totals.tip.preset.18"].tap()
        waitForLabel(element(app, "totals.banner"), containing: "Suma $130.80")
        toggle.tap()
        // 18% of $112.62 is $20.27.
        waitForLabel(element(app, "totals.banner"), containing: "Suma $132.89")
        XCTAssertTrue(app.buttons["totals.tip.preset.18"].isSelected, "the percentage stays")
    }

    @MainActor
    func testACustomTipTakesAnAmountAndTheStepper() {
        let app = launch()
        app.buttons["totals.tip.custom"].tap()
        let field = app.textFields["totals.tip.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "20.20", "custom starts from the tip it replaces")
        app.buttons["totals.tip.increase"].tap()
        waitForLabel(element(app, "totals.banner"), containing: "Suma $133.32")
        app.buttons["totals.tip.decrease"].tap()
        app.buttons["totals.tip.decrease"].tap()
        waitForLabel(element(app, "totals.banner"), containing: "Suma $132.32")
    }

    // MARK: Gating

    @MainActor
    func testUnassignedItemsBlockSharing() {
        let app = launch(fixture: "midway")
        let banner = element(app, "totals.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertTrue(banner.label.contains("Aún no está completo"), banner.label)
        XCTAssertTrue(banner.label.contains("2 artículos sin marcar ($13.00)"), banner.label)
        XCTAssertFalse(app.buttons["totals.share"].isEnabled)
        XCTAssertTrue(element(app, "totals.blocked").exists)

        app.buttons["totals.editAssign"].tap()
        XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 10))
    }

    @MainActor
    func testAConfirmedMismatchStillBlocksSharingUntilTheReceiptIsFixed() {
        let app = launch(fixture: "mismatch")
        let banner = element(app, "totals.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertTrue(banner.label.contains("Diferencia de $10.00"), banner.label)
        XCTAssertTrue(banner.label.contains("$111.00") && banner.label.contains("$101.00"), banner.label)
        XCTAssertFalse(app.buttons["totals.share"].isEnabled)
        XCTAssertTrue(element(app, "totals.blocked").exists)

        scrollTo(app.buttons["totals.editReceipt"], in: app)
        app.buttons["totals.editReceipt"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 10))
    }

    // MARK: Service charge

    @MainActor
    func testAReceiptWithAServiceChargeStartsWithNoTip() {
        let app = launch(fixture: "service")
        let field = app.textFields["totals.tip.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertEqual(field.value as? String, "0.00")
        XCTAssertTrue(app.buttons["totals.tip.custom"].isSelected)
        let hint = element(app, "totals.tip.hint")
        XCTAssertTrue(hint.exists)
        XCTAssertTrue(hint.label.contains("cargo por servicio ($15.15)"), hint.label)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $127.77")

        app.buttons["totals.tip.increase"].tap()
        waitForLabel(hint, containing: "propina doble")
    }

    // MARK: Share

    @MainActor
    func testSharingShowsTheSummaryThenTheSuccessMomentAndStartsANewBill() {
        let app = launch()
        app.buttons["totals.share"].tap()

        let preview = element(app, "share.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.label.contains("Marisol debe"), preview.label)
        XCTAssertTrue(preview.label.contains("Todo cuadra en $132.82"), preview.label)
        XCTAssertFalse(preview.label.contains("monto"))

        app.buttons["share.send"].tap()
        XCTAssertTrue(element(app, "success.title").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["¡Wepa! Cuentas claras."].exists)

        app.buttons["success.again"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheSuccessMomentCanGoBackToTheTotals() {
        let app = launch()
        app.buttons["totals.share"].tap()
        XCTAssertTrue(app.buttons["share.send"].waitForExistence(timeout: 10))
        app.buttons["share.send"].tap()
        XCTAssertTrue(app.buttons["success.back"].waitForExistence(timeout: 10))
        app.buttons["success.back"].tap()
        XCTAssertTrue(app.buttons["totals.share"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "success.title").exists)
    }

    @MainActor
    func testCancellingTheShareSheetChangesNothing() {
        let app = launch()
        app.buttons["totals.share"].tap()
        XCTAssertTrue(app.buttons["share.cancel"].waitForExistence(timeout: 10))
        app.buttons["share.cancel"].tap()
        XCTAssertTrue(app.buttons["totals.share"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "success.title").exists)
        XCTAssertTrue(element(app, "totals.banner").label.contains("Suma $132.82"))
    }

    // MARK: English

    @MainActor
    func testTotalsAndShareAreInEnglishToo() {
        let app = launch(language: "en", region: "US")
        let banner = element(app, "totals.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertTrue(banner.label.contains("Adds up to $132.82"), banner.label)
        XCTAssertEqual(app.buttons["totals.share"].label, "Share breakdown")
        XCTAssertEqual(app.buttons["totals.tip.custom"].label, "Custom")

        app.buttons["totals.share"].tap()
        let preview = element(app, "share.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.label.contains("Marisol owes"), preview.label)
        app.buttons["share.send"].tap()
        XCTAssertTrue(app.staticTexts["All settled up!"].waitForExistence(timeout: 10))
    }
}

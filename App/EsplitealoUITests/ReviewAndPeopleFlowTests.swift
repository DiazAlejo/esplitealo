import XCTest

/// The Review receipt and Add people screens, driven the way a person uses them. The app starts from a fixture bill
/// (`--fixture=<name> --start-at=<screen>`, honoured only with `--uitesting`) because the simulator has no camera.
///
/// Fixtures: `parsed` is a scan with one row the parser flagged and a receipt that does not add up (the flan is
/// $19.00 instead of $9.00); `scanned` is the same receipt fixed; `midway` is `scanned` with four people and items marked.
final class ReviewAndPeopleFlowTests: XCTestCase {
    private let flan = "review.item.10000000-0000-0000-0000-000000000008"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(fixture: String, at screen: String, language: String = "es", region: String = "PR") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting", "--fixture=\(fixture)", "--start-at=\(screen)",
            "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    // MARK: Review receipt

    @MainActor
    func testFlaggedRowAndTheMismatchAreShownAndNothingIsDropped() {
        let app = launch(fixture: "parsed", at: "review")
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "review.banner").label.contains("no cuadran"))
        XCTAssertTrue(element(app, "review.banner").label.contains("$111.00"))
        XCTAssertTrue(element(app, "review.banner").label.contains("$101.00"))
        let row = app.buttons[flan]
        XCTAssertTrue(row.exists)
        XCTAssertTrue(row.label.contains("Flan para compartir"))
        XCTAssertTrue(row.label.contains("Chequear"))
        XCTAssertTrue(row.label.contains("19 dólares"), row.label)
        XCTAssertTrue(app.buttons["review.item.10000000-0000-0000-0000-000000000001"].exists, "the other rows are still there")
    }

    @MainActor
    func testFixingTheFlaggedPriceMakesTheReceiptAddUpAndContinues() {
        let app = launch(fixture: "parsed", at: "review")
        XCTAssertTrue(app.buttons[flan].waitForExistence(timeout: 15))
        app.buttons[flan].tap()

        let price = app.textFields["sheet.item.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        replaceText(in: price, with: "9.00")
        app.buttons["sheet.save"].tap()

        let banner = element(app, "review.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("Todo quedó nítido"), banner.label)
        XCTAssertTrue(app.buttons[flan].label.contains("9 dólares"), app.buttons[flan].label)
        XCTAssertFalse(app.buttons[flan].label.contains("Chequear"))

        app.buttons["screen.next"].tap()
        XCTAssertTrue(element(app, "screen.people").waitForExistence(timeout: 10), "a balanced receipt continues without asking")
        XCTAssertFalse(element(app, "review.confirm.continue").exists)
    }

    @MainActor
    func testAMismatchNeedsAnExplicitConfirmationToContinue() {
        let app = launch(fixture: "parsed", at: "review")
        XCTAssertTrue(app.buttons["screen.next"].waitForExistence(timeout: 15))
        app.buttons["screen.next"].tap()

        XCTAssertTrue(app.buttons["review.confirm.fix"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Los números como quiera no cuadran"].exists)
        XCTAssertFalse(element(app, "screen.people").exists, "asking is not continuing")

        app.buttons["review.confirm.fix"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["review.confirm.continue"].waitForExistence(timeout: 1))

        app.buttons["screen.next"].tap()
        XCTAssertTrue(app.buttons["review.confirm.continue"].waitForExistence(timeout: 5))
        app.buttons["review.confirm.continue"].tap()
        XCTAssertTrue(element(app, "screen.people").waitForExistence(timeout: 10))
    }

    @MainActor
    func testEditingAReceiptAmountUpdatesTheReconciliationAtOnce() {
        let app = launch(fixture: "scanned", at: "review")
        XCTAssertTrue(element(app, "review.banner").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "review.banner").label.contains("Todo quedó nítido"))

        app.buttons["review.field.total"].tap()
        let field = app.textFields["sheet.amount.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        replaceText(in: field, with: "110.00")
        app.buttons["sheet.save"].tap()

        let banner = element(app, "review.banner")
        XCTAssertTrue(banner.label.contains("$112.62"), banner.label)
        XCTAssertTrue(banner.label.contains("$110.00"), banner.label)
    }

    @MainActor
    func testAddingAndDeletingAnItem() {
        let app = launch(fixture: "scanned", at: "review")
        XCTAssertTrue(app.buttons["review.add"].waitForExistence(timeout: 15))
        app.buttons["review.add"].tap()

        let name = app.textFields["sheet.item.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Tostones")
        let price = app.textFields["sheet.item.price"]
        price.tap()
        price.typeText("6.00")
        app.buttons["sheet.save"].tap()

        XCTAssertTrue(element(app, "review.banner").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "review.banner").label.contains("no cuadran"), "the new item no longer adds up to the printed subtotal")
        let added = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Tostones'")).firstMatch
        XCTAssertTrue(added.exists)

        added.tap()
        XCTAssertTrue(app.buttons["sheet.delete"].waitForExistence(timeout: 5))
        app.buttons["sheet.delete"].tap()
        XCTAssertTrue(element(app, "review.banner").label.contains("Todo quedó nítido"))
    }

    @MainActor
    func testReviewIsInEnglishToo() {
        let app = launch(fixture: "parsed", at: "review", language: "en", region: "US")
        XCTAssertTrue(element(app, "review.banner").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "review.banner").label.contains("Numbers don’t add up yet"), element(app, "review.banner").label)
        XCTAssertEqual(app.buttons["screen.next"].label, "Continue to people")
        app.buttons["screen.next"].tap()
        XCTAssertTrue(app.staticTexts["The numbers still don’t match"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["review.confirm.fix"].exists)
    }

    // MARK: Add people

    @MainActor
    func testTheEmptyTableAsksForSomeoneAndContinuingNeedsOnePerson() {
        let app = launch(fixture: "scanned", at: "people")
        XCTAssertTrue(element(app, "screen.people").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "people.empty").exists)
        XCTAssertFalse(app.buttons["screen.next"].isEnabled)

        let name = app.textFields["people.name"]
        name.tap()
        name.typeText("Ana")
        app.buttons["people.add"].tap()

        XCTAssertFalse(element(app, "people.empty").exists)
        XCTAssertTrue(app.buttons["screen.next"].isEnabled)
        app.buttons["screen.next"].tap()
        XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 10))
    }

    @MainActor
    func testNamesAreCheckedBeforeTheyJoinTheTable() {
        let app = launch(fixture: "midway", at: "people")
        XCTAssertTrue(app.textFields["people.name"].waitForExistence(timeout: 15))

        app.buttons["people.add"].tap()
        XCTAssertEqual(element(app, "people.message").label, "Escribe un nombre primero.")

        let name = app.textFields["people.name"]
        name.tap()
        name.typeText("hector")
        app.buttons["people.add"].tap()
        XCTAssertEqual(element(app, "people.message").label, "hector ya está en la mesa. Prueba con la inicial del apellido.")
        XCTAssertFalse(app.buttons["people.row.4"].exists)
    }

    @MainActor
    func testRenamingAPersonKeepsTheirItems() {
        let app = launch(fixture: "midway", at: "people")
        XCTAssertTrue(app.buttons["people.rename.1"].waitForExistence(timeout: 15))
        app.buttons["people.rename.1"].tap()

        let field = app.textFields["people.rename.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        replaceText(in: field, with: "Héctor R.")
        app.buttons["sheet.save"].tap()

        let row = element(app, "people.row.1")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Héctor R."), row.label)
        XCTAssertTrue(row.label.contains("3 artículos marcados"), row.label)
    }

    @MainActor
    func testRemovingSomeoneWithItemsMarkedSaysWhatHappensAndCanBeCancelled() {
        let app = launch(fixture: "midway", at: "people")
        XCTAssertTrue(app.buttons["people.remove.1"].waitForExistence(timeout: 15))
        app.buttons["people.remove.1"].tap()

        XCTAssertTrue(app.staticTexts["¿Quitar a Héctor?"].waitForExistence(timeout: 5))
        let body = element(app, "people.remove.body")
        XCTAssertTrue(body.label.contains("Héctor tiene 3 artículos marcados."), body.label)
        XCTAssertTrue(body.label.contains("Medalla y Pernil con gandules volverán a quedar sin marcar."), body.label)
        XCTAssertTrue(body.label.contains("Los artículos compartidos se quedan con las demás personas."), body.label)

        XCTAssertEqual(app.buttons["people.remove.keep"].label, "Dejar a Héctor")
        app.buttons["people.remove.keep"].tap()
        XCTAssertTrue(element(app, "people.row.3").waitForExistence(timeout: 5), "still four people")
        XCTAssertFalse(app.staticTexts["¿Quitar a Héctor?"].waitForExistence(timeout: 1))

        app.buttons["people.remove.1"].tap()
        XCTAssertTrue(app.buttons["people.remove.confirm"].waitForExistence(timeout: 5))
        app.buttons["people.remove.confirm"].tap()
        XCTAssertTrue(element(app, "people.row.2").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "people.row.3").exists, "three people are left")
        XCTAssertFalse(app.staticTexts["Héctor"].exists)
    }

    @MainActor
    func testPeopleIsInEnglishToo() {
        let app = launch(fixture: "midway", at: "people", language: "en", region: "US")
        XCTAssertTrue(app.buttons["people.remove.1"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["screen.next"].label, "Assign items")
        app.buttons["people.remove.1"].tap()
        XCTAssertTrue(app.staticTexts["Remove Héctor?"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["people.remove.keep"].label, "Keep Héctor")
    }
}

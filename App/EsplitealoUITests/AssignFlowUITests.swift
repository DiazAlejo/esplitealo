import XCTest

/// The Mark items screen, driven the way a person uses it. The app starts from a fixture bill with the people already
/// at the table (`--fixture=table`: the Fonda Doña Lola receipt, four people, nothing marked; `midway`: six of eight
/// marked; `quantities`: a ×3 line and a ×2 line, three people), honoured only with `--uitesting`.
final class AssignFlowUITests: XCTestCase {
    private let jugo = "assign.item.10000000-0000-0000-0000-000000000001"
    private let surtido = "assign.item.10000000-0000-0000-0000-000000000003"
    private let medalla = "assign.item.20000000-0000-0000-0000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(fixture: String = "table", language: String = "es", region: String = "PR") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting", "--fixture=\(fixture)", "--start-at=mark",
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
    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("expected a label containing \"\(text)\", got \"\(element.label)\"", file: file, line: line)
        }
    }

    // MARK: Marking items

    @MainActor
    func testEveryItemStartsUnassignedAndFlagged() {
        let app = launch()
        XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 15))
        waitForLabel(element(app, "assign.progress"), containing: "0 de 8")
        XCTAssertTrue(app.buttons[jugo].label.contains("sin marcar"), app.buttons[jugo].label)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 8")
        XCTAssertTrue(element(app, "assign.chip.0").label.contains("Marisol"))
    }

    @MainActor
    func testMarkingAnItemForThreePeopleSplitsItEquallyAndUpdatesTheChipsLive() {
        let app = launch()
        XCTAssertTrue(app.buttons[surtido].waitForExistence(timeout: 15))
        app.buttons[surtido].tap()

        XCTAssertTrue(element(app, "assign.sheet").waitForExistence(timeout: 5))
        app.buttons["assign.sheet.person.0"].tap()
        app.buttons["assign.sheet.person.1"].tap()
        app.buttons["assign.sheet.person.2"].tap()
        XCTAssertTrue(element(app, "assign.sheet.note").label.contains("Dividido en 3."), element(app, "assign.sheet.note").label)
        XCTAssertTrue(element(app, "assign.sheet.note").label.contains("2¢"), element(app, "assign.sheet.note").label)
        app.buttons["assign.sheet.done"].tap()

        XCTAssertFalse(element(app, "assign.sheet").waitForExistence(timeout: 1))
        let row = app.buttons[surtido]
        XCTAssertTrue(row.label.contains("marcado para Marisol, Héctor y Keishla") || row.label.contains("marcado para Marisol, Héctor, Keishla"), row.label)
        waitForLabel(element(app, "assign.chip.0"), containing: "4 dólares con 67 centavos")
        XCTAssertTrue(element(app, "assign.chip.2").label.contains("4 dólares con 66 centavos"), element(app, "assign.chip.2").label)
        waitForLabel(element(app, "assign.progress"), containing: "1 de 8")
    }

    @MainActor
    func testTakingSomeoneOffInTheSheetPutsTheItemBackInTheUnassignedBlock() {
        let app = launch()
        XCTAssertTrue(app.buttons[jugo].waitForExistence(timeout: 15))
        app.buttons[jugo].tap()
        app.buttons["assign.sheet.person.3"].tap()
        XCTAssertTrue(app.buttons["assign.sheet.person.3"].isSelected)
        app.buttons["assign.sheet.person.3"].tap()
        XCTAssertFalse(app.buttons["assign.sheet.person.3"].isSelected)
        app.buttons["assign.sheet.done"].tap()
        XCTAssertTrue(app.buttons[jugo].label.contains("sin marcar"), app.buttons[jugo].label)
    }

    // MARK: Review split with items left

    @MainActor
    func testReviewSplitWithItemsLeftWarnsAndSplittingTheRestEvenlyMovesOn() {
        let app = launch(fixture: "midway")
        XCTAssertTrue(app.buttons["screen.next"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 2")

        app.buttons["screen.next"].tap()
        let banner = element(app, "assign.warning")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("Faltan 2 artículos por marcar"), banner.label)
        XCTAssertFalse(element(app, "screen.totals").exists, "asking is not continuing")

        app.buttons["assign.restEven"].tap()
        XCTAssertFalse(element(app, "assign.warning").waitForExistence(timeout: 2))
        waitForLabel(element(app, "assign.progress"), containing: "8 de 8")
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")

        app.buttons["screen.next"].tap()
        XCTAssertTrue(element(app, "screen.totals").waitForExistence(timeout: 10))
    }

    // MARK: Paint mode

    @MainActor
    func testPaintModeMarksItemsForOnePersonWithSingleTaps() {
        let app = launch()
        XCTAssertTrue(element(app, "assign.chip.1").waitForExistence(timeout: 15))
        element(app, "assign.chip.1").tap()
        XCTAssertTrue(element(app, "assign.paintbar").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "assign.paintbar").label.contains("Héctor"), element(app, "assign.paintbar").label)

        app.buttons[jugo].tap()
        app.buttons[surtido].tap()
        XCTAssertFalse(element(app, "assign.sheet").exists, "painting does not open the sheet")
        XCTAssertTrue(app.buttons[jugo].label.contains("marcado para Héctor"), app.buttons[jugo].label)
        waitForLabel(element(app, "assign.chip.1"), containing: "18 dólares")

        app.buttons["assign.paintbar.done"].tap()
        XCTAssertFalse(element(app, "assign.paintbar").waitForExistence(timeout: 1))
    }

    // MARK: Quantity lines

    @MainActor
    func testAQuantityLineIsMarkedUnitByUnit() {
        let app = launch(fixture: "quantities")
        XCTAssertTrue(app.buttons[medalla].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons[medalla].label.contains("3 unidades"), app.buttons[medalla].label)
        app.buttons[medalla].tap()

        XCTAssertTrue(element(app, "assign.sheet").waitForExistence(timeout: 5))
        app.buttons["assign.sheet.unit.1"].tap()
        app.buttons["assign.sheet.person.0"].tap()
        app.buttons["assign.sheet.unit.2"].tap()
        app.buttons["assign.sheet.person.1"].tap()
        app.buttons["assign.sheet.done"].tap()

        let row = app.buttons[medalla]
        XCTAssertTrue(row.label.contains("2 de 3"), row.label)
        waitForLabel(element(app, "assign.chip.0"), containing: "5 dólares")
        waitForLabel(element(app, "assign.progress"), containing: "2 de 7")
    }

    // MARK: English

    @MainActor
    func testMarkItemsIsInEnglishToo() {
        let app = launch(fixture: "midway", language: "en", region: "US")
        XCTAssertTrue(app.buttons["screen.next"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["screen.next"].label, "Review split · 2 left")
        app.buttons["screen.next"].tap()
        XCTAssertTrue(element(app, "assign.warning").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "assign.warning").label.contains("2 items still need someone"), element(app, "assign.warning").label)
        XCTAssertTrue(app.buttons["assign.restEven"].exists)
        XCTAssertEqual(app.buttons["assign.restEven"].label, "Split the rest evenly")
    }
}

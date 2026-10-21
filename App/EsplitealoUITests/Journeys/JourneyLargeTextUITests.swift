import XCTest

/// The main path at the largest accessibility text size (AX5), in Spanish and in English: every control the path needs
/// is still there and can be reached, the amounts are not cut short, and the bill still ends in a shared total. Large
/// text puts controls below the fold, so these tests scroll to them the way a person would.
final class JourneyLargeTextUITests: JourneyTestCase {
    static let largest = "UICTContentSizeCategoryAccessibilityXXXL"

    @MainActor
    private func large(_ options: Options = Options()) -> Options {
        var copy = options
        copy.textSize = Self.largest
        return copy
    }

    @MainActor
    private func tapReaching(_ target: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(target) never appeared", file: file, line: line)
        scrollTo(target, in: app, file: file, line: line)
        target.tap()
    }

    @MainActor
    private func addPeopleLarge(_ names: [String], in app: XCUIApplication) {
        expectScreen("people", in: app)
        for (index, name) in names.enumerated() {
            let field = app.textFields["people.name"]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()
            field.typeText(name + "\n")
            waitFor(element(app, "people.row.\(index)"), "\(name) joining the table", in: app, timeout: 8)
        }
    }

    /// One line, whole: open its sheet, tick the people, close.
    @MainActor
    private func markWhole(_ item: String, for people: [Int], in app: XCUIApplication) {
        let row = itemRow(item, in: app)
        scrollTo(row, in: app)
        row.tap()
        XCTAssertTrue(element(app, "assign.sheet").waitForExistence(timeout: 5))
        // No drags in the sheet: a drag over its rows ticks or unticks them (the home indicator also makes Done report as
        // not hittable, which sent the old helper dragging). XCTest scrolls a button into view by itself when it taps it.
        for person in people {
            let button = app.buttons["assign.sheet.person.\(person)"]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(button) never appeared")
            button.tap()
        }
        attachDiagnostics(of: app, named: "sheet of \(item) before Done")
        let done = app.buttons["assign.sheet.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "\(done) never appeared")
        done.tap()
        expectNoElement("assign.sheet", in: app, within: 5)
        attachDiagnostics(of: app, named: "after marking \(item)")
    }

    @MainActor
    func testTheMainPathAtTheLargestTextSizeInSpanish() {
        let app = launch(large())
        let scanButton = app.buttons["home.scan"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 20))
        tapReaching(scanButton, in: app)
        expectScreen("review", in: app)
        XCTAssertTrue(element(app, "review.banner").label.contains("Todo quedó nítido"), element(app, "review.banner").label)
        XCTAssertTrue(reviewRow("Mofongo", in: app).label.contains("14 dólares"), "the price is not cut short")
        tapNext(app)

        addPeopleLarge(["Ana", "Luis"], in: app)
        tapNext(app)

        expectScreen("mark", in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 2")
        markWhole("Mofongo", for: [0], in: app)
        markWhole("Arroz con gandules", for: [1], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "Chequear el espliteo")
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        let shareButton = app.buttons["totals.share"]
        scrollTo(shareButton, in: app)
        XCTAssertTrue(shareButton.isEnabled)
        share(app, previewContains: ["Ana debe $19.07", "Luis debe $10.52"], successTitle: "¡Wepa! Cuentas claras.")
        tapReaching(app.buttons["success.again"], in: app)
        expectScreen("home", in: app)
    }

    @MainActor
    func testTheMainPathAtTheLargestTextSizeInEnglish() {
        let app = launch(large(Options().english))
        tapReaching(app.buttons["home.scan"], in: app)
        expectScreen("review", in: app)
        tapNext(app)
        addPeopleLarge(["Ana", "Luis"], in: app)
        tapNext(app)

        expectScreen("mark", in: app)
        markWhole("Mofongo", for: [0], in: app)
        markWhole("Arroz con gandules", for: [1], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "Review split")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Adds up to $29.59")
        share(app, previewContains: ["Ana owes $19.07", "Luis owes $10.52"], successTitle: "All settled up!")
    }

    @MainActor
    func testTheRelaunchQuestionAndTheResumedBillAtTheLargestTextSize() {
        let directory = Self.newDraftDirectory()
        let app = launch(large(Options(draftDirectory: directory)))
        tapReaching(app.buttons["home.scan"], in: app)
        expectScreen("review", in: app)
        tapNext(app)
        addPeopleLarge(["Ana"], in: app)
        backgroundAndTerminate(app)

        var again = large(Options(draftDirectory: directory))
        again.receipt = nil
        let second = launch(again)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("mark", in: second)
        XCTAssertEqual(second.buttons["screen.next"].label, "Chequear el espliteo · faltan 2")
    }

    @MainActor
    func testAMismatchAtTheLargestTextSizeIsReadableAndBlocksTheShare() {
        var options = large()
        options.receipt = .unbalanced
        let app = launch(options)
        tapReaching(app.buttons["home.scan"], in: app)
        expectScreen("review", in: app)
        XCTAssertTrue(element(app, "review.banner").label.contains("no cuadran"), element(app, "review.banner").label)
        tapNext(app)
        let keepGoing = app.buttons["review.confirm.continue"]
        XCTAssertTrue(keepGoing.waitForExistence(timeout: 5))
        keepGoing.tap()
        addPeopleLarge(["Ana"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        markWhole("Burger", for: [0], in: app)
        markWhole("Fries", for: [0], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Diferencia de $4.00")
        XCTAssertFalse(app.buttons["totals.share"].isEnabled)
    }
}

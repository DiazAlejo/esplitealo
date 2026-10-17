import XCTest

/// The app is ended at each stage of a bill and opened again over the same draft folder. The relaunch asks whether to
/// continue, and what comes back is the bill as it was: the same lines, the same people, the same marks, the same tip,
/// compared screen by screen by the labels the screen shows (the identifiers of scanned lines hold their ids, so a
/// bill restored with new ids would not match either).
///
/// Where the app puts the person back is decided by the bill (`AppRoute.path(resuming:)`): Review while nobody is at
/// the table, Mark items while items are left, Totals once everything is marked. A test that expects a screen
/// before the destination goes back to it first.
final class JourneyRelaunchUITests: JourneyTestCase {
    private let reviewPrefixes = ["review.item.", "review.field.", "review.banner"]
    private let peoplePrefixes = ["people.row."]
    private let markPrefixes = ["assign.item.", "assign.chip.", "assign.left"]
    private let totalsPrefixes = ["totals.person.", "totals.banner"]

    /// A launch over the folder the first run used, with no fixture receipt: whatever shows up came from the file.
    @MainActor
    private func relaunch(_ directory: String, english: Bool = false) -> XCUIApplication {
        var options = Options(draftDirectory: directory)
        options.receipt = nil
        return launch(english ? options.english : options)
    }

    // MARK: Home

    @MainActor
    func testNoBillMeansNoQuestionAtLaunch() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        expectScreen("home", in: app)
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        expectScreen("home", in: second)
        XCTAssertFalse(second.alerts.firstMatch.waitForExistence(timeout: 1))
    }

    @MainActor
    func testRelaunchFromHomeWithABillInProgressResumesOnReview() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        let before = fingerprint(of: app, prefixes: reviewPrefixes)
        XCTAssertGreaterThanOrEqual(before.count, 4)
        goBack(app)
        expectScreen("home", in: app)
        _ = expect("home.resume", in: app, timeout: 5)
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("review", in: second)
        waitForLabel(element(second, "review.banner"), containing: "Todo quedó nítido")
        XCTAssertEqual(fingerprint(of: second, prefixes: reviewPrefixes), before)
    }

    // MARK: Review

    @MainActor
    func testRelaunchOnReviewKeepsTheEditsMadeThere() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        let mofongo = reviewRow("Mofongo", in: app)
        XCTAssertTrue(mofongo.waitForExistence(timeout: 5))
        mofongo.tap()
        let name = app.textFields["sheet.item.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Mofongo relleno")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(reviewRow("Mofongo relleno", in: app).waitForExistence(timeout: 5))
        let before = fingerprint(of: app, prefixes: reviewPrefixes)

        backgroundAndTerminate(app)
        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("review", in: second)
        XCTAssertTrue(reviewRow("Mofongo relleno", in: second).waitForExistence(timeout: 5))
        XCTAssertEqual(fingerprint(of: second, prefixes: reviewPrefixes), before)
    }

    // MARK: Add people

    @MainActor
    func testRelaunchOnAddPeopleBringsTheTableBackAndMarkItemsIsNext() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        let before = fingerprint(of: app, prefixes: peoplePrefixes)
        XCTAssertEqual(before.count, 2)
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        // Two people and nothing marked: the bill goes on at Mark items, with Add people one step back.
        expectScreen("mark", in: second)
        XCTAssertEqual(second.buttons["screen.next"].label, "Chequear el espliteo · faltan 2")
        goBack(second)
        expectScreen("people", in: second)
        XCTAssertEqual(fingerprint(of: second, prefixes: peoplePrefixes), before)
        goBack(second)
        expectScreen("review", in: second)
        XCTAssertTrue(reviewRow("Mofongo", in: second).exists)
    }

    // MARK: Mark items

    @MainActor
    func testRelaunchOnMarkItemsKeepsEveryMark() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "faltan 1")
        let before = fingerprint(of: app, prefixes: markPrefixes)
        XCTAssertTrue(before.values.contains { $0.contains("Ana") })
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("mark", in: second)
        waitForLabel(second.buttons["screen.next"], containing: "faltan 1")
        XCTAssertEqual(fingerprint(of: second, prefixes: markPrefixes), before)

        // And the bill goes on from there to a shared total.
        paint(person: 1, items: ["Arroz con gandules"], in: second)
        tapNext(second)
        expectScreen("totals", in: second)
        share(second, previewContains: ["Ana debe $19.07", "Luis debe $10.52"], successTitle: "¡Wepa! Cuentas claras.")
    }

    @MainActor
    func testRelaunchOnMarkItemsWithAQuantityLineKeepsTheUnitsApart() {
        let directory = Self.newDraftDirectory()
        var options = Options(draftDirectory: directory)
        options.receipt = .partyStore
        let app = launch(options)
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis", "Keishla"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        markUnits(of: "Negro", [[0], [1]], in: app)
        let hats = itemRow("Negro", in: app)
        XCTAssertTrue(hats.label.contains("2 de 3"), hats.label)
        let before = fingerprint(of: app, prefixes: markPrefixes)
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("mark", in: second)
        XCTAssertEqual(fingerprint(of: second, prefixes: markPrefixes), before)
        markUnits(of: "Negro", [[], [], [2]], in: second)
        paint(person: 0, items: ["Marrón"], in: second)
        tapNext(second)
        expectScreen("totals", in: second)
        waitForLabel(element(second, "totals.banner"), containing: "Suma $60.50")
    }

    // MARK: Totals

    @MainActor
    func testRelaunchOnTotalsKeepsTheTipAndEveryShare() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        app.buttons["totals.tip.preset.15"].tap()
        // 15% of $22.50 is $3.38 (rounded), $25.09 + $3.38 = $28.47.
        waitForLabel(element(app, "totals.banner"), containing: "Suma $28.4")
        let before = fingerprint(of: app, prefixes: totalsPrefixes)
        XCTAssertEqual(before.count, 3)
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("totals", in: second)
        waitForLabel(element(second, "totals.banner"), containing: "Suma $28.4")
        XCTAssertTrue(second.buttons["totals.tip.preset.15"].isSelected, "the tip is the one that was chosen")
        XCTAssertEqual(fingerprint(of: second, prefixes: totalsPrefixes), before)
        XCTAssertTrue(second.buttons["totals.share"].isEnabled)
    }

    @MainActor
    func testRelaunchOnTotalsWithAConfirmedMismatchStaysBlocked() {
        let directory = Self.newDraftDirectory()
        var options = Options(draftDirectory: directory)
        options.receipt = .unbalanced
        let app = launch(options)
        scan(app)
        tapNext(app)
        XCTAssertTrue(app.buttons["review.confirm.continue"].waitForExistence(timeout: 5))
        app.buttons["review.confirm.continue"].tap()
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Burger"], in: app)
        paint(person: 1, items: ["Fries"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Diferencia de $4.00")
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("totals", in: second)
        waitForLabel(element(second, "totals.banner"), containing: "Diferencia de $4.00")
        XCTAssertFalse(second.buttons["totals.share"].isEnabled, "the confirmation survives, the permission to share does not exist")
        XCTAssertTrue(element(second, "totals.blocked").exists)
    }

    // MARK: Killed without warning

    @MainActor
    func testAnAppKilledWithoutWarningLosesNothingOlderThanTheAutosave() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "faltan 1")
        let before = fingerprint(of: app, prefixes: markPrefixes)
        killWithoutWarning(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("mark", in: second)
        waitForLabel(second.buttons["screen.next"], containing: "faltan 1")
        XCTAssertEqual(fingerprint(of: second, prefixes: markPrefixes), before)
    }

    // MARK: Twice, and in English

    @MainActor
    func testARelaunchedBillCanBeLeftAndRelaunchedAgainAndStaysTheSame() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo", "Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        let before = fingerprint(of: app, prefixes: totalsPrefixes)
        backgroundAndTerminate(app)

        let second = relaunch(directory)
        answerResumePrompt(second, button: "Continuar")
        expectScreen("totals", in: second)
        waitForLabel(element(second, "totals.banner"), containing: "Suma $29.59")
        backgroundAndTerminate(second)

        let third = relaunch(directory)
        answerResumePrompt(third, button: "Continuar")
        expectScreen("totals", in: third)
        waitForLabel(element(third, "totals.banner"), containing: "Suma $29.59")
        XCTAssertEqual(fingerprint(of: third, prefixes: totalsPrefixes), before)
    }

    @MainActor
    func testTheRelaunchQuestionIsInEnglishToo() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory).english)
        scan(app)
        tapNext(app)
        addPeople(["Ana"], in: app)
        backgroundAndTerminate(app)

        let second = relaunch(directory, english: true)
        let alert = second.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts["Continue your bill?"].exists)
        XCTAssertTrue(alert.buttons["Start over"].exists)
        alert.buttons["Continue"].tap()
        expectScreen("mark", in: second)
        XCTAssertEqual(second.buttons["screen.next"].label, "Review split · 2 left")
    }
}

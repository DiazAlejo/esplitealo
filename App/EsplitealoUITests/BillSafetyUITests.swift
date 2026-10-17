import XCTest

/// A bill can never be lost or replaced by navigation: Back from Review goes Home, Home offers to continue the bill,
/// a new scan asks before it replaces one, a bill can be abandoned on purpose, and a shared bill is not offered again
/// at the next launch. The simulator has no camera, so the app reads the committed real-receipt fixture and starts
/// from fixture bills (`--fixture=`), as in the other flow tests.
final class BillSafetyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private static var receiptFixture: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EsplitealoUITests
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // repository
            .appendingPathComponent("Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json")
            .path
    }

    private func makeDraftDirectory() -> String {
        NSTemporaryDirectory() + "esplitealo-uitest-draft-\(UUID().uuidString)"
    }

    /// `fixture` starts from a bill; `scan` makes the camera and photo picker read the receipt fixture.
    @MainActor
    private func launch(
        fixture: String? = nil, startAt: String? = nil, scan: Bool = true, language: String = "es", region: String = "PR",
        draftDirectory: String? = nil, extra: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        if let fixture { app.launchArguments.append("--fixture=\(fixture)") }
        if let startAt { app.launchArguments.append("--start-at=\(startAt)") }
        if scan { app.launchArguments += ["--uitesting-recognized-text", Self.receiptFixture] }
        if let draftDirectory { app.launchArguments += ["--uitesting-draft-dir", draftDirectory] }
        app.launchArguments += extra
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0 ..< 8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    /// Puts the app in the background (which writes the draft at once) and ends it, as when iOS or the user closes it.
    @MainActor
    private func backgroundAndTerminate(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackgroundSuspended, timeout: 5)
        app.terminate()
    }

    // MARK: Back from Review

    @MainActor
    func testBackFromReviewGoesHomeAndNeverOpensTheCamera() {
        let app = launch()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "screen.capture").exists)
        XCTAssertFalse(element(app, "capture.progress").exists)
        // The scanned bill is still there, one tap away.
        XCTAssertTrue(element(app, "home.resume").waitForExistence(timeout: 5))
    }

    // MARK: Continue your bill

    @MainActor
    func testHomeShowsNoCardWhenThereIsNoBill() {
        let app = launch()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, "home.resume").exists)
    }

    @MainActor
    func testHomeOffersToContinueTheBillWithItsSizeAndTotal() {
        let app = launch(fixture: "midway")
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "home.resume").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Continuar con tu cuenta"].exists)
        let summary = element(app, "home.resume.summary").firstMatch
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summary.label.contains("artículos"), summary.label)
        XCTAssertTrue(summary.label.contains("$"), summary.label)
    }

    @MainActor
    func testTheCardResumesTheBillAtTheStepItReached() {
        let app = launch(fixture: "midway")
        XCTAssertTrue(app.buttons["home.resume.continue"].waitForExistence(timeout: 15))
        app.buttons["home.resume.continue"].tap()
        XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 5))
        // Back goes through the earlier steps to Home, and the bill is still offered there.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "home.resume").exists)
    }

    @MainActor
    func testTheCardIsInEnglishToo() {
        let app = launch(fixture: "midway", language: "en", region: "US")
        XCTAssertTrue(element(app, "home.resume").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Continue your bill"].exists)
        XCTAssertEqual(app.buttons["home.resume.discard"].label, "Discard bill")
    }

    // MARK: A new scan asks first

    @MainActor
    func testANewScanAsksBeforeReplacingTheBillAndCanContinueTheExistingOne() {
        let app = launch(fixture: "midway")
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["¿Empezar una cuenta nueva?"].exists)
        XCTAssertFalse(element(app, "screen.capture").exists)

        alert.buttons["Continuar con mi cuenta"].tap()
        XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 5))
    }

    @MainActor
    func testChoosingAPhotoAsksTooAndStartingANewBillReplacesTheOldOne() {
        let app = launch(fixture: "midway")
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.photo"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Empezar una nueva"].tap()

        // The new scan opens Review with a bill nobody has added people to yet.
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        app.buttons["home.resume.continue"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 5), "the old bill (with people) is gone")
    }

    @MainActor
    func testCancellingTheCameraAfterConfirmingKeepsTheOldBill() {
        let app = launch(fixture: "midway", extra: ["--uitesting-scan-delay", "30"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["Empezar una nueva"].tap()
        XCTAssertTrue(element(app, "capture.progress").waitForExistence(timeout: 10))

        app.buttons["capture.back"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "home.resume").waitForExistence(timeout: 5))
        app.buttons["home.resume.continue"].tap()
        XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 5))
    }

    @MainActor
    func testTheReplaceQuestionIsInEnglishToo() {
        let app = launch(fixture: "midway", language: "en", region: "US")
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Start a new bill?"].exists)
        XCTAssertTrue(alert.buttons["Continue my bill"].exists)
        XCTAssertTrue(alert.buttons["Start a new one"].exists)
    }

    // MARK: Discard on purpose

    @MainActor
    func testDiscardingFromHomeAsksAndThenForgetsTheBill() {
        let app = launch(fixture: "midway")
        XCTAssertTrue(app.buttons["home.resume.discard"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["home.resume.discard"].label, "Abandonar cuenta")
        app.buttons["home.resume.discard"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        // Keeping the bill changes nothing.
        alert.buttons["Seguir con la cuenta"].tap()
        XCTAssertTrue(element(app, "home.resume").waitForExistence(timeout: 5))

        app.buttons["home.resume.discard"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["Abandonar cuenta"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "home.resume").waitForExistence(timeout: 2))

        // With no bill left, a new scan starts without a question.
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
    }

    @MainActor
    func testDiscardingFromReviewGoesHomeWithoutTheBill() {
        let app = launch(fixture: "scanned", startAt: "review")
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
        let discard = app.buttons["review.discard"]
        scrollTo(discard, in: app)
        discard.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Abandonar cuenta"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "home.resume").waitForExistence(timeout: 2))
    }

    @MainActor
    func testKeepingTheBillOnTheDiscardQuestionStaysOnReview() {
        let app = launch(fixture: "scanned", startAt: "review", language: "en", region: "US")
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
        let discard = app.buttons["review.discard"]
        scrollTo(discard, in: app)
        XCTAssertEqual(discard.label, "Discard bill")
        discard.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["Keep the bill"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 5))
    }

    // MARK: Relaunching

    @MainActor
    func testAnUnfinishedBillIsStillOfferedAfterRelaunch() {
        let directory = makeDraftDirectory()
        let first = launch(fixture: "midway", draftDirectory: directory)
        XCTAssertTrue(element(first, "home.resume").waitForExistence(timeout: 15))
        backgroundAndTerminate(first)

        let second = launch(draftDirectory: directory)
        XCTAssertTrue(second.alerts.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(second.alerts.firstMatch.staticTexts["¿Seguimos con tu cuenta?"].exists)
        second.alerts.firstMatch.buttons["Continuar"].tap()
        XCTAssertTrue(element(second, "screen.mark").waitForExistence(timeout: 5))
    }

    @MainActor
    func testASharedBillIsNotOfferedAfterRelaunch() {
        let directory = makeDraftDirectory()
        let first = launch(fixture: "complete", startAt: "totals", draftDirectory: directory, extra: ["--uitesting-share", "complete"])
        XCTAssertTrue(first.buttons["totals.share"].waitForExistence(timeout: 15))
        first.buttons["totals.share"].tap()
        XCTAssertTrue(first.buttons["share.send"].waitForExistence(timeout: 10))
        first.buttons["share.send"].tap()
        XCTAssertTrue(element(first, "success.title").waitForExistence(timeout: 10))
        backgroundAndTerminate(first)

        let second = launch(draftDirectory: directory)
        XCTAssertTrue(element(second, "screen.home").waitForExistence(timeout: 15))
        XCTAssertFalse(second.alerts.firstMatch.waitForExistence(timeout: 3), "a finished bill is not offered again")
        XCTAssertFalse(element(second, "home.resume").exists)
    }

    @MainActor
    func testTheSuccessScreenStillStartsANewBillAfterSharing() {
        let app = launch(fixture: "complete", startAt: "totals", extra: ["--uitesting-share", "complete"])
        XCTAssertTrue(app.buttons["totals.share"].waitForExistence(timeout: 15))
        app.buttons["totals.share"].tap()
        XCTAssertTrue(app.buttons["share.send"].waitForExistence(timeout: 10))
        app.buttons["share.send"].tap()
        XCTAssertTrue(app.buttons["success.again"].waitForExistence(timeout: 10))
        app.buttons["success.again"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "home.resume").exists)
    }

    @MainActor
    func testBackOnTheSuccessScreenStillReturnsToTheTotals() {
        let app = launch(fixture: "complete", startAt: "totals", extra: ["--uitesting-share", "complete"])
        XCTAssertTrue(app.buttons["totals.share"].waitForExistence(timeout: 15))
        app.buttons["totals.share"].tap()
        XCTAssertTrue(app.buttons["share.send"].waitForExistence(timeout: 10))
        app.buttons["share.send"].tap()
        XCTAssertTrue(app.buttons["success.back"].waitForExistence(timeout: 10))
        app.buttons["success.back"].tap()
        XCTAssertTrue(app.buttons["totals.share"].waitForExistence(timeout: 10))
    }
}

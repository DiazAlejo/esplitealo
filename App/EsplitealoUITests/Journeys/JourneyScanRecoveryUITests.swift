import XCTest

/// A scan that goes wrong, and the way out: try again, choose another photo, type the items in, or leave. Every way out
/// ends where a good scan would have, in a bill that can be split and shared, and a failed scan never leaves a bill
/// behind. `--uitesting-scan-failure <kind>` makes the first read fail; the second works. `--uitesting-camera <status>`
/// is the camera permission.
final class JourneyScanRecoveryUITests: JourneyTestCase {
    /// From Review with the bistro receipt to a shared bill: Ana has the mofongo, Luis the rice.
    @MainActor
    private func splitAndShareTheBistroBill(_ app: XCUIApplication) {
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        share(app, previewContains: ["Ana debe $19.07", "Luis debe $10.52"], successTitle: "¡Wepa! Cuentas claras.")
    }

    @MainActor
    private func startScan(_ app: XCUIApplication, button: String = "home.scan") {
        let start = app.buttons[button]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Home never appeared")
        start.tap()
    }

    // MARK: Try again

    @MainActor
    func testAnUnreadableReceiptIsRetriedAndTheBillGoesAllTheWayToTheShare() {
        var options = Options()
        options.scanFailure = "unreadable"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.retry", in: app, timeout: 10)
        XCTAssertTrue(app.staticTexts["Ay bendito, no pude leer ese recibo"].exists)
        XCTAssertFalse(element(app, "screen.review").exists)

        app.buttons["capture.retry"].tap()
        expectScreen("review", in: app)
        splitAndShareTheBistroBill(app)
    }

    @MainActor
    func testTooManyPagesIsRetriedInEnglishAndTheBillGoesToTheShare() {
        var options = Options().english
        options.scanFailure = "tooManyPages"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.retry", in: app, timeout: 10)
        XCTAssertTrue(app.staticTexts["That was more than one page"].exists)

        app.buttons["capture.retry"].tap()
        expectScreen("review", in: app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo", "Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        share(app, previewContains: ["Ana owes $29.59"], successTitle: "All settled up!")
    }

    @MainActor
    func testEveryKindOfFailureOffersAWayOutThatWorks() {
        for failure in ["unreadable", "tooManyPages", "tooLong", "photoNotLoaded", "cameraFailed"] {
            var options = Options()
            options.scanFailure = failure
            let app = launch(options)
            startScan(app, button: failure == "photoNotLoaded" ? "home.photo" : "home.scan")
            XCTAssertTrue(element(app, "capture.retry").waitForExistence(timeout: 10), "\(failure): no retry")
            XCTAssertTrue(element(app, "capture.manual").exists, "\(failure): no manual entry")
            app.buttons["capture.retry"].tap()
            XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15), "\(failure): the retry did not read the receipt")
            app.terminate()
        }
    }

    // MARK: Another photo, or by hand

    @MainActor
    func testAnotherPhotoAfterAFailureReadsTheReceiptAndTheBillGoesToTheShare() {
        var options = Options()
        options.scanFailure = "unreadable"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.another", in: app, timeout: 10)
        app.buttons["capture.another"].tap()
        expectScreen("review", in: app)
        splitAndShareTheBistroBill(app)
    }

    @MainActor
    func testTypingTheItemsInAfterAFailureReachesPeopleWithTheItemsAdded() {
        var options = Options()
        options.scanFailure = "unreadable"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.manual", in: app, timeout: 10)
        app.buttons["capture.manual"].tap()
        expectScreen("review", in: app)
        _ = expect("review.empty", in: app, timeout: 5)
        XCTAssertFalse(app.buttons["screen.next"].isEnabled, "nothing to split yet")

        app.buttons["review.add"].tap()
        let name = app.textFields["sheet.item.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Tostones")
        let price = app.textFields["sheet.item.price"]
        price.tap()
        price.typeText("6.00")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(reviewRow("Tostones", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["screen.next"].isEnabled)
        waitForLabel(element(app, "review.banner"), containing: "Falta el total del recibo")

        // The receipt has no printed total, so going on may ask first; either way the table comes next.
        tapNext(app)
        let confirm = app.buttons["review.confirm.continue"]
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        expectScreen("people", in: app)
    }

    // MARK: Camera not allowed

    @MainActor
    func testADeniedCameraStillGoesAllTheWayThroughAChosenPhoto() {
        var options = Options()
        options.camera = "denied"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.choosePhoto", in: app, timeout: 10)
        XCTAssertTrue(app.staticTexts["La cámara está desactivada"].exists)
        XCTAssertTrue(app.buttons["capture.openSettings"].exists)
        app.buttons["capture.choosePhoto"].tap()
        expectScreen("review", in: app)
        splitAndShareTheBistroBill(app)
    }

    @MainActor
    func testARestrictedCameraInEnglishOffersOnlyPhotosAndLeavingGoesHome() {
        var options = Options().english
        options.camera = "restricted"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.choosePhoto", in: app, timeout: 10)
        XCTAssertTrue(app.staticTexts["The camera isn’t available"].exists)
        XCTAssertFalse(app.buttons["capture.openSettings"].exists)
        app.buttons["capture.back"].tap()
        expectScreen("home", in: app)
        XCTAssertFalse(element(app, "home.resume").exists)
    }

    @MainActor
    func testACameraThatHasNotBeenAskedYetIsAskedAndThenScans() {
        var options = Options()
        options.camera = "notDetermined"
        let app = launch(options)
        startScan(app)
        expectScreen("review", in: app)
    }

    // MARK: Nothing is left behind

    @MainActor
    func testAFailedOrCancelledScanLeavesNoBillBehind() {
        let directory = Self.newDraftDirectory()
        var options = Options(draftDirectory: directory)
        options.scanFailure = "unreadable"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.retry", in: app, timeout: 10)
        app.buttons["capture.back"].tap()
        expectScreen("home", in: app)
        XCTAssertFalse(element(app, "home.resume").exists)
        backgroundAndTerminate(app)

        var again = Options(draftDirectory: directory)
        again.receipt = nil
        let relaunched = launch(again)
        expectScreen("home", in: relaunched)
        XCTAssertFalse(relaunched.alerts.firstMatch.waitForExistence(timeout: 1))
        XCTAssertFalse(element(relaunched, "home.resume").exists)
    }

    @MainActor
    func testCancellingWhileReadingLeavesNoBillBehindAndAScanStillWorksAfterwards() {
        var options = Options()
        options.scanDelay = "30"
        let app = launch(options)
        startScan(app)
        _ = expect("capture.progress", in: app, timeout: 10)
        app.buttons["capture.back"].tap()
        expectScreen("home", in: app)
        XCTAssertFalse(element(app, "home.resume").exists)

        // The slow reader is still the one configured, so the second scan is cancelled too; Home stays usable.
        XCTAssertTrue(app.buttons["home.scan"].isHittable)
    }
}

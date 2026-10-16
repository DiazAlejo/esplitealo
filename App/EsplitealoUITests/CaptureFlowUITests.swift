import XCTest

/// Home, capture and processing on a real simulator. The simulator has no camera, so the app reads the committed
/// real-receipt recognized-text fixture instead of opening the document camera (debug launch arguments).
final class CaptureFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json`, found from this file's path.
    private static var fixturePath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EsplitealoUITests
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // repository
            .appendingPathComponent("Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json")
            .path
    }

    @MainActor
    private func launch(language: String = "es", region: String = "PR", _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting", "--uitesting-recognized-text", Self.fixturePath]
        app.launchArguments += extra
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    // MARK: Home

    @MainActor
    func testHomeOffersScanAndChoosePhotoInSpanish() {
        let app = launch()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["home.scan"].label, "Escanear recibo")
        XCTAssertEqual(app.buttons["home.photo"].label, "Elegir foto")
        XCTAssertTrue(app.buttons["home.how"].exists)
    }

    @MainActor
    func testHowItWorksOpensAndCloses() {
        let app = launch(language: "en", region: "US")
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.how"].tap()
        XCTAssertTrue(element(app, "how.sheet").waitForExistence(timeout: 5))
        app.buttons["how.done"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "how.sheet").exists)
    }

    // MARK: The happy path

    @MainActor
    func testScanReadsTheReceiptAndOpensReview() {
        let app = launch()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
    }

    @MainActor
    func testChoosingAPhotoReadsTheReceiptAndOpensReviewInEnglish() {
        let app = launch(language: "en", region: "US")
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.photo"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
    }

    @MainActor
    func testReadingScreenShowsChavitoAndCanBeCancelled() {
        let app = launch(["--uitesting-scan-delay", "30"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.progress").waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["capture.back"].label, "Cancelar")
        app.buttons["capture.back"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
    }

    // MARK: Camera not usable

    @MainActor
    func testDeniedCameraExplainsSettingsAndKeepsPhotosAvailable() {
        let app = launch(["--uitesting-camera", "denied"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.choosePhoto").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["La cámara está desactivada"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["capture.openSettings"].waitForExistence(timeout: 10))
        app.buttons["capture.choosePhoto"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
    }

    @MainActor
    func testRestrictedCameraOnlyOffersPhotos() {
        let app = launch(language: "en", region: "US", ["--uitesting-camera", "restricted"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.choosePhoto").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The camera isn’t available"].exists)
        XCTAssertFalse(app.buttons["capture.openSettings"].exists)
        XCTAssertTrue(app.buttons["capture.choosePhoto"].exists)
    }

    @MainActor
    func testLeavingTheBlockedScreenGoesBackHome() {
        let app = launch(["--uitesting-camera", "denied"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.choosePhoto").waitForExistence(timeout: 10))
        app.buttons["capture.back"].tap()
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 5))
    }

    // MARK: Failures

    @MainActor
    func testUnreadableReceiptCanBeTriedAgain() {
        let app = launch(["--uitesting-scan-failure", "unreadable"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.retry").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Ay bendito, no pude leer ese recibo"].exists)
        XCTAssertTrue(app.buttons["capture.manual"].exists)
        XCTAssertTrue(app.buttons["capture.another"].exists)
        app.buttons["capture.retry"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
    }

    @MainActor
    func testTooManyPagesIsExplainedInEnglish() {
        let app = launch(language: "en", region: "US", ["--uitesting-scan-failure", "tooManyPages"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.retry").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["That was more than one page"].exists)
    }

    @MainActor
    func testAFailedScanCanContinueByHand() {
        let app = launch(["--uitesting-scan-failure", "unreadable"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.retry").waitForExistence(timeout: 10))
        app.buttons["capture.manual"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 10))
    }

    @MainActor
    func testAFailedScanCanChooseAnotherPhoto() {
        let app = launch(["--uitesting-scan-failure", "unreadable"])
        XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        XCTAssertTrue(element(app, "capture.retry").waitForExistence(timeout: 10))
        app.buttons["capture.another"].tap()
        XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
    }
}

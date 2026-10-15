import XCTest

/// Launches the real app on a simulator: it must reach Home, show Spanish first, and walk the six-screen shell.
/// `--uitesting` keeps the draft in a throwaway directory so a saved bill never interrupts the run.
final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(language: String = "es", region: String = "PR") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting", "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)"]
        app.launch()
        return app
    }

    func testLaunchesToHomeInSpanish() {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 15))
        let scan = app.buttons["home.scan"]
        XCTAssertTrue(scan.exists)
        XCTAssertEqual(scan.label, "Escanear recibo")
    }

    func testLaunchesToHomeInEnglish() {
        let app = launch(language: "en", region: "US")
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["home.scan"].label, "Scan receipt")
    }

    func testWalksThroughTheSixScreens() {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 15))
        app.buttons["home.scan"].tap()
        for screen in ["capture", "review", "people", "mark", "totals"] {
            XCTAssertTrue(app.descendants(matching: .any)["screen.\(screen)"].waitForExistence(timeout: 10), "screen.\(screen)")
            if screen != "totals" { app.buttons["screen.next"].tap() }
        }
        XCTAssertFalse(app.buttons["screen.next"].exists)
    }
}

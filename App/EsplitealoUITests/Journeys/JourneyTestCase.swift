import XCTest

/// What the full-journey tests share. A journey starts the app at Home with no bill, reads a committed real receipt
/// through the fixture scanner (the simulator has no camera) and goes through the screens the way a person does:
/// scan, review, add people, mark items, totals, share. Every launch gets its own draft folder, and a relaunch reuses
/// it, so "quit and open the app again" is a real relaunch over the file the first run wrote.
///
/// Launch arguments (honoured only with `--uitesting`, in Debug builds): see `UITestFixture` and
/// `ScanLaunchConfiguration`. Receipts are `Tests/Fixtures/Receipts/<name>.recognized.json`:
///
/// - `bistro`: two lines, $22.50 + $2.59 tax = $25.09.
/// - `partyStore`: a line of 3 units ($34.50) and one of 1 ($11.50), two tax lines ($4.83 + $0.47), $51.30.
/// - `unbalanced`: two lines that add up to $16.00 under a printed $20.00 subtotal and total.
class JourneyTestCase: XCTestCase {
    enum Receipt: String {
        case bistro = "pr-ivu-bistro"
        case partyStore = "pr-party-store-wrapped-names"
        case unbalanced = "mismatch-adversarial"
    }

    struct Options {
        var language = "es"
        var region = "PR"
        var receipt: Receipt? = .bistro
        /// Keeps the draft across launches. Pass the same folder to relaunch.
        var draftDirectory: String
        var fixture: String?
        var startAt: String?
        var share = "complete"
        var scanFailure: String?
        var camera: String?
        var scanDelay: String?
        /// An accessibility content size such as `UICTContentSizeCategoryAccessibilityXXXL`.
        var textSize: String?

        init(draftDirectory: String = JourneyTestCase.newDraftDirectory()) {
            self.draftDirectory = draftDirectory
        }

        var english: Options {
            var copy = self
            copy.language = "en"
            copy.region = "US"
            return copy
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    nonisolated static func newDraftDirectory() -> String {
        NSTemporaryDirectory() + "esplitealo-journey-draft-\(UUID().uuidString)"
    }

    nonisolated static func receiptPath(_ receipt: Receipt) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Journeys
            .deletingLastPathComponent() // EsplitealoUITests
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // repository
            .appendingPathComponent("Tests/Fixtures/Receipts/\(receipt.rawValue).recognized.json")
            .path
    }

    @MainActor
    func launch(_ options: Options = Options()) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["--uitesting", "--uitesting-draft-dir", options.draftDirectory, "--uitesting-share", options.share]
        if let receipt = options.receipt { arguments += ["--uitesting-recognized-text", Self.receiptPath(receipt)] }
        if let fixture = options.fixture { arguments.append("--fixture=\(fixture)") }
        if let startAt = options.startAt { arguments.append("--start-at=\(startAt)") }
        if let failure = options.scanFailure { arguments += ["--uitesting-scan-failure", failure] }
        if let camera = options.camera { arguments += ["--uitesting-camera", camera] }
        if let delay = options.scanDelay { arguments += ["--uitesting-scan-delay", delay] }
        if let size = options.textSize { arguments += ["-UIPreferredContentSizeCategoryName", size] }
        arguments += ["-AppleLanguages", "(\(options.language))", "-AppleLocale", "\(options.language)_\(options.region)"]
        app.launchArguments += arguments
        app.launch()
        return app
    }

    /// Puts the app in the background, which writes the draft at once, and ends it, as iOS does to an app left alone.
    @MainActor
    func backgroundAndTerminate(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackgroundSuspended, timeout: 5)
        app.terminate()
    }

    /// Ends the app with no warning, as a crash or a force quit would: only what the autosave already wrote survives.
    /// The wait is longer than the half-second quiet period before a save.
    @MainActor
    func killWithoutWarning(_ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
    }

    // MARK: Looking

    @MainActor
    func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor @discardableResult
    func expect(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let found = element(app, identifier)
        XCTAssertTrue(found.waitForExistence(timeout: timeout), "\(identifier) never appeared", file: file, line: line)
        return found
    }

    @MainActor
    func expectScreen(_ screen: String, in app: XCUIApplication, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        _ = expect("screen.\(screen)", in: app, timeout: timeout, file: file, line: line)
    }

    @MainActor
    func expectNoElement(_ identifier: String, in app: XCUIApplication, within seconds: TimeInterval = 2, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element(app, identifier))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: seconds), .completed, "\(identifier) is still there", file: file, line: line)
    }

    /// Waits until the element's label contains the text: screens update a moment after a sheet closes.
    @MainActor
    func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("expected a label containing \"\(text)\", got \"\(element.label)\"", file: file, line: line)
        }
    }

    @MainActor
    func scrollTo(_ target: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0 ..< 8 where !target.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable, "\(target) is not reachable", file: file, line: line)
    }

    /// The labels of what a screen shows, by identifier, for comparing a screen before and after a relaunch. The
    /// identifiers of scanned lines hold their id, so a restored bill with new ids would not match either.
    @MainActor
    func fingerprint(of app: XCUIApplication, prefixes: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for prefix in prefixes {
            let matches = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            for match in matches.allElementsBoundByIndex where match.exists {
                result[match.identifier] = match.label
            }
        }
        return result
    }

    // MARK: Doing

    /// Replaces what is in a text field: tap at the far end, delete what is there, type.
    @MainActor
    func replaceText(in field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    @MainActor
    func tapNext(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let next = app.buttons["screen.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "no continue button", file: file, line: line)
        next.tap()
    }

    @MainActor
    func goBack(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// Home, Scan: reads the receipt and lands on Review.
    @MainActor
    func scan(_ app: XCUIApplication) {
        let scan = app.buttons["home.scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 20), "Home never appeared")
        scan.tap()
        expectScreen("review", in: app)
    }

    @MainActor
    func addPeople(_ names: [String], in app: XCUIApplication) {
        expectScreen("people", in: app)
        for name in names {
            let field = app.textFields["people.name"]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()
            field.typeText(name)
            app.buttons["people.add"].tap()
            XCTAssertTrue(element(app, "people.row.\(names.firstIndex(of: name) ?? 0)").waitForExistence(timeout: 5), "\(name) did not join the table")
        }
    }

    /// A row of Mark items, found by (part of) the item's name: the ids of scanned lines are not known to a test.
    @MainActor
    func itemRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'assign.item.' AND label CONTAINS %@", name)).firstMatch
    }

    /// A row of Review, by (part of) the item's name.
    @MainActor
    func reviewRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'review.item.' AND label CONTAINS %@", name)).firstMatch
    }

    /// Marks items for one person with paint mode: tap their chip, tap the lines, tap Done.
    @MainActor
    func paint(person index: Int, items: [String], in app: XCUIApplication) {
        let chip = element(app, "assign.chip.\(index)")
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "no chip for person \(index)")
        chip.tap()
        XCTAssertTrue(element(app, "assign.paintbar").waitForExistence(timeout: 5))
        for name in items {
            let row = itemRow(name, in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "no row for \(name)")
            row.tap()
        }
        app.buttons["assign.paintbar.done"].tap()
    }

    /// Opens the sheet of one line and marks its units one at a time: `units[0]` are the people (by index) for unit 1.
    @MainActor
    func markUnits(of item: String, _ units: [[Int]], in app: XCUIApplication) {
        let row = itemRow(item, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no row for \(item)")
        row.tap()
        XCTAssertTrue(element(app, "assign.sheet").waitForExistence(timeout: 5))
        for (offset, people) in units.enumerated() {
            app.buttons["assign.sheet.unit.\(offset + 1)"].tap()
            for person in people { app.buttons["assign.sheet.person.\(person)"].tap() }
        }
        app.buttons["assign.sheet.done"].tap()
        expectNoElement("assign.sheet", in: app, within: 5)
    }

    /// Totals, Share: checks the preview text, sends it and lands on the success moment.
    @MainActor
    func share(_ app: XCUIApplication, previewContains fragments: [String], successTitle: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["totals.share"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no share button", file: file, line: line)
        XCTAssertTrue(button.isEnabled, "sharing is blocked", file: file, line: line)
        button.tap()
        let preview = expect("share.preview", in: app, timeout: 10, file: file, line: line)
        for fragment in fragments {
            XCTAssertTrue(preview.label.contains(fragment), "the share text lacks \"\(fragment)\": \(preview.label)", file: file, line: line)
        }
        XCTAssertFalse(preview.label.localizedCaseInsensitiveContains("monto"), file: file, line: line)
        app.buttons["share.send"].tap()
        expect("success.title", in: app, timeout: 10, file: file, line: line)
        XCTAssertTrue(app.staticTexts[successTitle].exists, "no \"\(successTitle)\"", file: file, line: line)
    }

    /// The answer to the "continue your bill?" question a relaunch asks, by the button's label.
    @MainActor
    func answerResumePrompt(_ app: XCUIApplication, button: String, file: StaticString = #filePath, line: UInt = #line) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "the relaunch did not ask about the bill", file: file, line: line)
        alert.buttons[button].tap()
    }
}

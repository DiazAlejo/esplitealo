import XCTest

/// `performAccessibilityAudit()` on every screen and sheet, each one in two situations: the default one (Spanish,
/// light, default text size) and the hardest one (English, dark, the largest accessibility text size, AX5). The audit
/// checks contrast, hit regions, clipped text, Dynamic Type support, missing descriptions and element traits. Long
/// screens are audited again after scrolling to the bottom, because the audit only sees what is on screen.
///
/// The app starts from a fixture bill (`--fixture=<name> --start-at=<screen>`), so no camera is needed. After the audit,
/// every button on screen must be at least 44 x 44 pt (`assertTapTargets`).
final class AccessibilityAuditUITests: XCTestCase {
    struct Situation {
        let name: String
        let language: String
        let region: String
        let dark: Bool
        let sizeCategory: String

        static let standard = Situation(name: "es-light-default", language: "es", region: "PR", dark: false, sizeCategory: "UICTContentSizeCategoryL")
        static let hardest = Situation(name: "en-dark-AX5", language: "en", region: "US", dark: true, sizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        static let all = [standard, hardest]
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private static var receiptFixture: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json").path
    }

    @MainActor
    private func launch(_ situation: Situation, _ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting"] + arguments
        app.launchArguments += ["-AppleLanguages", "(\(situation.language))", "-AppleLocale", "\(situation.language)_\(situation.region)"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", situation.sizeCategory]
        if situation.dark { app.launchArguments += ["-AppleInterfaceStyle", "Dark"] }
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Runs `body` once per situation with a fresh launch. An audit takes seconds, so most screens are audited in the
    /// hardest situation only (`hardestOnly`), where layout problems are likeliest; the others in both.
    @MainActor
    private func eachSituation(_ arguments: [String], hardestOnly: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ body: (XCUIApplication, Situation) -> Void) {
        for situation in hardestOnly ? [Situation.hardest] : Situation.all {
            let app = launch(situation, arguments)
            body(app, situation)
            app.terminate()
        }
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ label: String, scrolls: Int = 0, underSheet: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        run(app, label, underSheet: underSheet, file: file, line: line)
        // Scrolled audits only where the text is largest: that is where content falls off the first screen.
        for index in 0 ..< min(scrolls, label.contains("AX5") ? 2 : 0) {
            app.swipeUp()
            run(app, "\(label), scrolled \(index + 1)", underSheet: underSheet, file: file, line: line)
        }
    }

    @MainActor
    private func run(_ app: XCUIApplication, _ label: String, underSheet: Bool, file: StaticString, line: UInt) {
        let keyboard = app.keyboards.firstMatch
        let keyboardFrame = keyboard.exists ? keyboard.frame : nil
        let alertFrames = app.alerts.allElementsBoundByIndex.filter(\.exists).map(\.frame)
        let navigationBar = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame : nil
        let window = app.windows.firstMatch.frame
        let isDark = label.contains("dark")
        // The pinned bottom bar of a screen: from just above its main button to the bottom of the window.
        let pinnedBars = ["screen.next", "totals.share"].map { app.buttons[$0] }.filter(\.exists).map { button in
            let top = button.frame.minY - 16
            return CGRect(x: 0, y: top, width: window.width, height: max(0, window.maxY - top))
        }

        func handle(_ issue: XCUIAccessibilityAuditIssue, failing: Bool) -> Bool {
            // One greppable line per finding in the CI log: what, where and on which element.
            let element = issue.element
            let frame = element.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "-"
            let kind: AuditWaiver.Kind = switch issue.auditType {
            case .dynamicType: .dynamicType
            case .contrast: .contrast
            case .textClipped: .textClipped
            default: issue.compactDescription == "Potentially inaccessible text" ? .inaccessibleText : .other
            }
            let reason = AuditWaiver.reason(
                kind: kind, elementFrame: element?.frame, elementIdentifier: element?.identifier ?? "", isHittable: element?.isHittable ?? true,
                window: window, navigationBar: navigationBar, keyboard: keyboardFrame, alerts: alertFrames, pinnedBars: pinnedBars, underSheet: underSheet
            )
            let outcome = reason.map { "waived=\($0)" } ?? (failing ? "FAILS" : "not failing (dark contrast)")
            let text = "AUDIT [\(label)] \(issue.compactDescription) | auditType=\(issue.auditType.rawValue) type=\(element?.elementType.rawValue ?? 0) id=\(element?.identifier ?? "-") label=\(element?.label ?? "-") frame=\(frame) | \(outcome)"
            XCTContext.runActivity(named: text) { _ in }
            return !failing || reason != nil
        }

        do {
            if isDark {
                // XCTest's contrast check reads pixels of dark screens and reports text that passes (12:1 ink on a banner).
                // So in dark mode it runs apart, is logged, and does not fail; the dark pairs are `ContrastTests`.
                try app.performAccessibilityAudit(for: .all.subtracting(.contrast)) { handle($0, failing: true) }
                try app.performAccessibilityAudit(for: .contrast) { handle($0, failing: false) }
            } else {
                try app.performAccessibilityAudit { handle($0, failing: true) }
            }
        } catch {
            XCTFail("\(label): the audit could not run: \(error)", file: file, line: line)
        }
        assertTapTargets(app, label, file: file, line: line)
    }

    @MainActor
    private func assertTapTargets(_ app: XCUIApplication, _ label: String, file: StaticString, line: UInt) {
        let screen = app.windows.firstMatch.frame
        for button in app.buttons.allElementsBoundByIndex where button.exists {
            let frame = button.frame
            // Fully on screen only: `isHittable` throws for a chip scrolled out of view sideways.
            guard screen.contains(frame) else { continue }
            // System chrome (the sheet grabber, the keyboard) is not ours; partly visible buttons are measured on screen.
            guard screen.contains(CGPoint(x: frame.midX, y: frame.midY)), button.identifier != "", frame.width > 0 else { continue }
            XCTAssertGreaterThanOrEqual(frame.width, 43.5, "\(label): \(button.identifier) is \(frame.width) pt wide", file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height, 43.5, "\(label): \(button.identifier) is \(frame.height) pt tall", file: file, line: line)
        }
    }

    // MARK: Home and capture

    @MainActor
    func testHome() {
        eachSituation([]) { app, situation in
            XCTAssertTrue(element(app, "screen.home").waitForExistence(timeout: 15))
            audit(app, "Home \(situation.name)", scrolls: 3)
        }
    }

    @MainActor
    func testHowItWorksSheet() {
        eachSituation([]) { app, situation in
            XCTAssertTrue(app.buttons["home.how"].waitForExistence(timeout: 15))
            app.buttons["home.how"].tap()
            XCTAssertTrue(element(app, "how.sheet").waitForExistence(timeout: 5))
            audit(app, "How it works \(situation.name)", scrolls: 2, underSheet: true)
        }
    }

    @MainActor
    func testCameraBlockedScreens() {
        for state in ["denied"] {
            eachSituation(["--uitesting-camera", state, "--uitesting-recognized-text", Self.receiptFixture]) { app, situation in
                XCTAssertTrue(app.buttons["home.scan"].waitForExistence(timeout: 15))
                app.buttons["home.scan"].tap()
                XCTAssertTrue(app.buttons["capture.choosePhoto"].waitForExistence(timeout: 10))
                audit(app, "Camera \(state) \(situation.name)", scrolls: 2)
            }
        }
    }

    @MainActor
    func testReadingScreen() {
        eachSituation(["--uitesting-scan-delay", "60", "--uitesting-recognized-text", Self.receiptFixture]) { app, situation in
            XCTAssertTrue(app.buttons["home.scan"].waitForExistence(timeout: 15))
            app.buttons["home.scan"].tap()
            XCTAssertTrue(element(app, "capture.progress").waitForExistence(timeout: 10))
            audit(app, "Reading \(situation.name)", scrolls: 2)
        }
    }

    @MainActor
    func testScanFailedScreen() {
        eachSituation(["--uitesting-scan-failure", "unreadable", "--uitesting-recognized-text", Self.receiptFixture]) { app, situation in
            XCTAssertTrue(app.buttons["home.scan"].waitForExistence(timeout: 15))
            app.buttons["home.scan"].tap()
            XCTAssertTrue(app.buttons["capture.retry"].waitForExistence(timeout: 10))
            audit(app, "Scan failed \(situation.name)", scrolls: 2)
        }
    }

    @MainActor
    func testResumeDraftPrompt() {
        eachSituation(["--uitesting-resume-prompt"], hardestOnly: true) { app, situation in
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 15), situation.name)
            XCTAssertGreaterThanOrEqual(alert.buttons.count, 2, "continue and discard")
            XCTAssertTrue(alert.staticTexts.count >= 2, "a title and a message")
            audit(app, "Resume prompt \(situation.name)")
        }
    }

    // MARK: Review

    @MainActor
    func testReviewWithAFlaggedRowAndItsSheets() {
        eachSituation(["--fixture=parsed", "--start-at=review"]) { app, situation in
            XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
            audit(app, "Review \(situation.name)", scrolls: 4)
        }
        eachSituation(["--fixture=parsed", "--start-at=review"], hardestOnly: true) { app, situation in
            XCTAssertTrue(app.buttons["review.add"].waitForExistence(timeout: 15))
            if !app.buttons["review.add"].isHittable { for _ in 0 ..< 6 where !app.buttons["review.add"].isHittable { app.swipeUp() } }
            app.buttons["review.add"].tap()
            XCTAssertTrue(app.buttons["sheet.save"].waitForExistence(timeout: 5))
            audit(app, "Item editor \(situation.name)", scrolls: 1, underSheet: true)
        }
        eachSituation(["--fixture=parsed", "--start-at=review"], hardestOnly: true) { app, situation in
            let total = app.buttons["review.field.total"]
            XCTAssertTrue(total.waitForExistence(timeout: 15))
            for _ in 0 ..< 8 where !total.isHittable { app.swipeUp() }
            total.tap()
            XCTAssertTrue(app.buttons["sheet.save"].waitForExistence(timeout: 5))
            audit(app, "Amount sheet \(situation.name)", scrolls: 1, underSheet: true)
        }
        eachSituation(["--fixture=parsed", "--start-at=review"], hardestOnly: true) { app, situation in
            XCTAssertTrue(app.buttons["screen.next"].waitForExistence(timeout: 15))
            // At the largest sizes the button scrolls with the page instead of being pinned.
            for _ in 0 ..< 8 where !app.buttons["screen.next"].isHittable { app.swipeUp() }
            app.buttons["screen.next"].tap()
            XCTAssertTrue(app.buttons["review.confirm.fix"].waitForExistence(timeout: 5))
            audit(app, "Mismatch confirmation \(situation.name)", scrolls: 1, underSheet: true)
        }
    }

    @MainActor
    func testReviewWithNothingRead() {
        eachSituation(["--fixture=empty", "--start-at=review"], hardestOnly: true) { app, situation in
            XCTAssertTrue(element(app, "screen.review").waitForExistence(timeout: 15))
            audit(app, "Empty review \(situation.name)", scrolls: 2)
        }
    }

    // MARK: People

    @MainActor
    func testPeopleEmptyAndFilled() {
        eachSituation(["--fixture=scanned", "--start-at=people"]) { app, situation in
            XCTAssertTrue(element(app, "screen.people").waitForExistence(timeout: 15))
            audit(app, "People, empty \(situation.name)", scrolls: 3)
        }
        eachSituation(["--fixture=midway", "--start-at=people"], hardestOnly: true) { app, situation in
            XCTAssertTrue(element(app, "screen.people").waitForExistence(timeout: 15))
            audit(app, "People, four \(situation.name)", scrolls: 4)
        }
    }

    @MainActor
    func testPeopleSheets() {
        eachSituation(["--fixture=midway", "--start-at=people"], hardestOnly: true) { app, situation in
            let rename = app.buttons["people.rename.1"]
            XCTAssertTrue(rename.waitForExistence(timeout: 15))
            for _ in 0 ..< 8 where !rename.isHittable { app.swipeUp() }
            rename.tap()
            XCTAssertTrue(app.buttons["sheet.save"].waitForExistence(timeout: 5))
            audit(app, "Rename sheet \(situation.name)", scrolls: 1, underSheet: true)
        }
        eachSituation(["--fixture=midway", "--start-at=people"], hardestOnly: true) { app, situation in
            let remove = app.buttons["people.remove.1"]
            XCTAssertTrue(remove.waitForExistence(timeout: 15))
            for _ in 0 ..< 8 where !remove.isHittable { app.swipeUp() }
            remove.tap()
            XCTAssertTrue(app.buttons["people.remove.keep"].waitForExistence(timeout: 5))
            audit(app, "Remove sheet \(situation.name)", scrolls: 1, underSheet: true)
        }
    }

    // MARK: Mark items

    @MainActor
    func testMarkItemsScreenAndSheet() {
        eachSituation(["--fixture=midway", "--start-at=mark"]) { app, situation in
            XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 15))
            audit(app, "Mark items \(situation.name)", scrolls: 4)
        }
        eachSituation(["--fixture=quantities", "--start-at=mark"], hardestOnly: true) { app, situation in
            XCTAssertTrue(element(app, "screen.mark").waitForExistence(timeout: 15))
            let firstRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'assign.item.'")).firstMatch
            XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
            for _ in 0 ..< 6 where !firstRow.isHittable { app.swipeUp() }
            firstRow.tap()
            XCTAssertTrue(app.buttons["assign.sheet.done"].waitForExistence(timeout: 5))
            audit(app, "Assign sheet \(situation.name)", scrolls: 2, underSheet: true)
        }
    }

    @MainActor
    func testMarkItemsWithItemsLeftWarning() {
        eachSituation(["--fixture=midway", "--start-at=mark"], hardestOnly: true) { app, situation in
            XCTAssertTrue(app.buttons["screen.next"].waitForExistence(timeout: 15))
            for _ in 0 ..< 8 where !app.buttons["screen.next"].isHittable { app.swipeUp() }
            app.buttons["screen.next"].tap()
            XCTAssertTrue(element(app, "assign.warning").waitForExistence(timeout: 5))
            audit(app, "Mark items warning \(situation.name)", scrolls: 3)
        }
    }

    // MARK: Totals and share

    @MainActor
    func testTotalsInEveryState() {
        for fixture in ["complete", "midway", "mismatch", "service"] {
            eachSituation(["--fixture=\(fixture)", "--start-at=totals"]) { app, situation in
                XCTAssertTrue(element(app, "screen.totals").waitForExistence(timeout: 15))
                audit(app, "Totals \(fixture) \(situation.name)", scrolls: 5)
            }
        }
    }

    @MainActor
    func testShareSheetAndSuccess() {
        eachSituation(["--fixture=complete", "--start-at=totals", "--uitesting-share", "complete"]) { app, situation in
            let share = app.buttons["totals.share"]
            XCTAssertTrue(share.waitForExistence(timeout: 15))
            for _ in 0 ..< 10 where !share.isHittable { app.swipeUp() }
            share.tap()
            XCTAssertTrue(app.buttons["share.send"].waitForExistence(timeout: 10))
            // The sheet first opens at a guessed height and slides to the measured one: audit it once it rests, because
            // the Dynamic Type check compares the text before and after a size change and a moving sheet looks unscaled.
            var resting = app.buttons["share.send"].frame
            for _ in 0 ..< 20 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                let now = app.buttons["share.send"].frame
                if now == resting { break }
                resting = now
            }
            audit(app, "Share sheet \(situation.name)", scrolls: 2, underSheet: true)
            for _ in 0 ..< 6 where !app.buttons["share.send"].isHittable { app.swipeUp() }
            app.buttons["share.send"].tap()
            XCTAssertTrue(element(app, "success.title").waitForExistence(timeout: 10))
            audit(app, "Success \(situation.name)", scrolls: 2)
        }
    }

    // MARK: Text fields

    @MainActor
    func testTheNameFieldAndTheAddButtonAreTheFirstTwoStopsOnTheTable() {
        let app = launch(.standard, ["--fixture=scanned", "--start-at=people"])
        XCTAssertTrue(app.textFields["people.name"].waitForExistence(timeout: 15))
        let field = app.textFields["people.name"].frame
        let add = app.buttons["people.add"].frame
        XCTAssertLessThanOrEqual(field.minY, add.minY, "the field comes before its button, the order of a keyboard or Switch Control pass")
    }
}

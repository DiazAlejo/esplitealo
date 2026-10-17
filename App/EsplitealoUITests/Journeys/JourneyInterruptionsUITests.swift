import XCTest

/// The detours a real bill takes: a receipt that does not add up, items nobody claimed, someone who leaves the table,
/// a price fixed after the people were added, going back, and giving up. Each one ends in a shared bill or in nothing
/// left behind, never in a lost or half-changed bill.
///
/// Numbers, by hand (20% tip before tax):
///
/// - `bistro` ($14.50 mofongo, $8.00 rice, $2.59 tax, $25.09): Ana with the mofongo owes $19.07, Luis with the rice
///   $10.52, together $29.59. The tax cent goes to the bigger remainder.
/// - `unbalanced` (a $12.00 burger and $4.00 fries under a printed $20.00): it adds up once the fries are $8.00, and
///   then Ana owes $14.40 and Luis $9.60.
final class JourneyInterruptionsUITests: JourneyTestCase {
    // MARK: A receipt that does not add up

    @MainActor
    func testAMismatchCanBeConfirmedPastButIsNotSharedUntilTheReceiptIsFixed() {
        var options = Options()
        options.receipt = .unbalanced
        let app = launch(options)
        scan(app)
        XCTAssertTrue(element(app, "review.banner").label.contains("no cuadran"), element(app, "review.banner").label)

        tapNext(app)
        let keepGoing = app.buttons["review.confirm.continue"]
        XCTAssertTrue(keepGoing.waitForExistence(timeout: 5), "going on past a mismatch asks first")
        keepGoing.tap()

        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Burger"], in: app)
        paint(person: 1, items: ["Fries"], in: app)
        tapNext(app)

        expectScreen("totals", in: app)
        let banner = element(app, "totals.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("Diferencia de $4.00"), banner.label)
        XCTAssertFalse(app.buttons["totals.share"].isEnabled, "the person went on, but the bill cannot be shared as it is")
        XCTAssertTrue(element(app, "totals.blocked").exists)

        // Fixing the fries on Review makes the receipt add up and the same bill, with its people, comes back to Totals.
        scrollTo(app.buttons["totals.editReceipt"], in: app)
        app.buttons["totals.editReceipt"].tap()
        expectScreen("review", in: app)
        let fries = reviewRow("Fries", in: app)
        XCTAssertTrue(fries.waitForExistence(timeout: 5))
        fries.tap()
        let price = app.textFields["sheet.item.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        replaceText(in: price, with: "8.00")
        app.buttons["sheet.save"].tap()
        waitForLabel(element(app, "review.banner"), containing: "Todo quedó nítido")

        tapNext(app)
        expectScreen("people", in: app)
        XCTAssertTrue(element(app, "people.row.1").label.contains("Luis"), "the people are still at the table")
        tapNext(app)
        expectScreen("mark", in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo", "and so are their marks")
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $24.00")
        share(app, previewContains: ["Ana debe $14.40", "Luis debe $9.60"], successTitle: "¡Wepa! Cuentas claras.")
    }

    // MARK: Items nobody claimed

    @MainActor
    func testItemsLeftUnmarkedBlockTheSplitUntilTheRestIsSplitEvenly() {
        let app = launch()
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 1")

        tapNext(app)
        let warning = element(app, "assign.warning")
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(warning.label.contains("Falta 1 artículo por marcar"), warning.label)
        XCTAssertFalse(element(app, "screen.totals").exists, "asking is not continuing")

        app.buttons["assign.restEven"].tap()
        expectNoElement("assign.warning", in: app, within: 5)
        waitForLabel(app.buttons["screen.next"], containing: "Chequear el espliteo")
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")
        tapNext(app)

        // The rice is split between both: Ana $18.50 of items, Luis $4.00.
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        share(app, previewContains: ["Ana debe $24.33", "Luis debe $5.26"], successTitle: "¡Wepa! Cuentas claras.")
    }

    // MARK: Someone leaves the table

    @MainActor
    func testRemovingAPersonWhoHasItemsReturnsTheirItemsAndTheBillStillShares() {
        let app = launch()
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis", "Keishla"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")

        // Back through Mark to the table, where Luis is told what leaving means.
        goBack(app)
        expectScreen("mark", in: app)
        goBack(app)
        expectScreen("people", in: app)
        let remove = app.buttons["people.remove.1"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        let body = expect("people.remove.body", in: app, timeout: 5)
        XCTAssertTrue(body.label.contains("Luis tiene 1 artículo marcado."), body.label)
        XCTAssertTrue(body.label.contains("Arroz con gandules volverá a quedar sin marcar."), body.label)
        app.buttons["people.remove.confirm"].tap()
        XCTAssertTrue(element(app, "people.row.1").label.contains("Keishla"), "Keishla moves up to Luis's place")
        expectNoElement("people.row.2", in: app, within: 5)

        tapNext(app)
        expectScreen("mark", in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo · faltan 1", "the rice has no owner again")
        XCTAssertTrue(itemRow("Mofongo", in: app).label.contains("Ana"), "Ana keeps hers")
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        tapNext(app)

        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        share(app, previewContains: ["Ana debe $19.07", "Keishla debe $10.52"], successTitle: "¡Wepa! Cuentas claras.")
    }

    @MainActor
    func testKeepingTheLeavingPersonChangesNothing() {
        let app = launch()
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        goBack(app)
        expectScreen("people", in: app)

        app.buttons["people.remove.1"].tap()
        XCTAssertTrue(app.buttons["people.remove.keep"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["people.remove.keep"].label, "Dejar a Luis")
        app.buttons["people.remove.keep"].tap()
        XCTAssertTrue(element(app, "people.row.1").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "people.row.1").label.contains("1 artículo marcado"), element(app, "people.row.1").label)
    }

    // MARK: A price fixed after the people were added

    @MainActor
    func testRenamingAnItemOnReviewAfterAddingPeopleKeepsWhoHadIt() {
        let app = launch()
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)

        scrollTo(app.buttons["totals.editReceipt"], in: app)
        app.buttons["totals.editReceipt"].tap()
        expectScreen("review", in: app)
        let mofongo = reviewRow("Mofongo", in: app)
        XCTAssertTrue(mofongo.waitForExistence(timeout: 5))
        mofongo.tap()
        let name = app.textFields["sheet.item.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "Mofongo de pollo")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(reviewRow("Mofongo de pollo", in: app).waitForExistence(timeout: 5))

        tapNext(app)
        expectScreen("people", in: app)
        XCTAssertTrue(element(app, "people.row.0").label.contains("1 artículo marcado"), element(app, "people.row.0").label)
        tapNext(app)
        expectScreen("mark", in: app)
        XCTAssertTrue(itemRow("Mofongo de pollo", in: app).label.contains("Ana"), itemRow("Mofongo de pollo", in: app).label)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")
        tapNext(app)
        expectScreen("totals", in: app)
        share(app, previewContains: ["Ana debe $19.07", "Luis debe $10.52"], successTitle: "¡Wepa! Cuentas claras.")
    }

    @MainActor
    func testChangingAPriceOnReviewAfterAddingPeopleRepricesEachShare() {
        let app = launch()
        scan(app)
        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        tapNext(app)
        expectScreen("totals", in: app)

        scrollTo(app.buttons["totals.editReceipt"], in: app)
        app.buttons["totals.editReceipt"].tap()
        expectScreen("review", in: app)
        // The rice is $10.00, so the receipt's subtotal and total are $24.50 and $27.09: change all three, as one does.
        let rice = reviewRow("Arroz con gandules", in: app)
        XCTAssertTrue(rice.waitForExistence(timeout: 5))
        rice.tap()
        let price = app.textFields["sheet.item.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        replaceText(in: price, with: "10.00")
        app.buttons["sheet.save"].tap()
        waitForLabel(element(app, "review.banner"), containing: "no cuadran")

        for (field, value) in [("subtotal", "24.50"), ("total", "27.09")] {
            let button = app.buttons["review.field.\(field)"]
            scrollTo(button, in: app)
            button.tap()
            let amount = app.textFields["sheet.amount.field"]
            XCTAssertTrue(amount.waitForExistence(timeout: 5))
            replaceText(in: amount, with: value)
            app.buttons["sheet.save"].tap()
            expectNoElement("sheet.amount.field", in: app, within: 5)
        }
        waitForLabel(element(app, "review.banner"), containing: "Todo quedó nítido")

        tapNext(app)
        expectScreen("people", in: app)
        tapNext(app)
        expectScreen("mark", in: app)
        XCTAssertEqual(app.buttons["screen.next"].label, "Chequear el espliteo")
        tapNext(app)
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $31.99")
        share(app, previewContains: ["Ana debe $18.93", "Luis debe $13.06"], successTitle: "¡Wepa! Cuentas claras.")
    }

    // MARK: Going back

    @MainActor
    func testGoingBackAtEveryStepKeepsTheBillAndForwardAgainFindsItUnchanged() {
        let app = launch()
        scan(app)
        let review = ["review.item.", "review.field.", "review.banner"]
        let reviewBefore = fingerprint(of: app, prefixes: review)
        XCTAssertGreaterThanOrEqual(reviewBefore.count, 4)

        tapNext(app)
        addPeople(["Ana", "Luis"], in: app)
        let people = ["people.row."]
        let peopleBefore = fingerprint(of: app, prefixes: people)
        XCTAssertEqual(peopleBefore.count, 2)

        tapNext(app)
        expectScreen("mark", in: app)
        paint(person: 0, items: ["Mofongo"], in: app)
        paint(person: 1, items: ["Arroz con gandules"], in: app)
        waitForLabel(app.buttons["screen.next"], containing: "Chequear el espliteo")
        let mark = ["assign.item.", "assign.chip.", "assign.left"]
        let markBefore = fingerprint(of: app, prefixes: mark)

        tapNext(app)
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        let totals = ["totals.person.", "totals.banner"]
        let totalsBefore = fingerprint(of: app, prefixes: totals)

        // Back, one screen at a time: each one shows what it showed on the way in.
        goBack(app)
        expectScreen("mark", in: app)
        XCTAssertEqual(fingerprint(of: app, prefixes: mark), markBefore)
        goBack(app)
        expectScreen("people", in: app)
        XCTAssertEqual(fingerprint(of: app, prefixes: people), peopleBefore)
        goBack(app)
        expectScreen("review", in: app)
        XCTAssertEqual(fingerprint(of: app, prefixes: review), reviewBefore)

        // Back from Review is Home, and Home still has the bill, ready to go on where it stopped.
        goBack(app)
        expectScreen("home", in: app)
        let card = expect("home.resume", in: app, timeout: 5)
        XCTAssertTrue(card.exists)
        app.buttons["home.resume.continue"].tap()
        expectScreen("totals", in: app)
        waitForLabel(element(app, "totals.banner"), containing: "Suma $29.59")
        XCTAssertEqual(fingerprint(of: app, prefixes: totals), totalsBefore)
        share(app, previewContains: ["Ana debe $19.07", "Luis debe $10.52"], successTitle: "¡Wepa! Cuentas claras.")
    }

    // MARK: Giving up

    @MainActor
    func testDiscardingFromReviewWithPeopleAndMarksLeavesNothingToResume() {
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

        scrollTo(app.buttons["totals.editReceipt"], in: app)
        app.buttons["totals.editReceipt"].tap()
        expectScreen("review", in: app)
        let discard = app.buttons["review.discard"]
        scrollTo(discard, in: app)
        discard.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Abandonar cuenta"].tap()
        expectScreen("home", in: app)
        XCTAssertFalse(element(app, "home.resume").waitForExistence(timeout: 2))

        backgroundAndTerminate(app)
        var again = Options(draftDirectory: directory)
        again.receipt = nil
        let relaunched = launch(again)
        expectScreen("home", in: relaunched)
        XCTAssertFalse(relaunched.alerts.firstMatch.waitForExistence(timeout: 3), "an abandoned bill is not offered")
        XCTAssertFalse(element(relaunched, "home.resume").exists)
    }

    @MainActor
    func testDiscardingFromHomeAfterWalkingBackLeavesNothingToResume() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana"], in: app)
        goBack(app)
        expectScreen("review", in: app)
        goBack(app)
        expectScreen("home", in: app)

        app.buttons["home.resume.discard"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["Abandonar cuenta"].tap()
        XCTAssertFalse(element(app, "home.resume").waitForExistence(timeout: 2))

        backgroundAndTerminate(app)
        var again = Options(draftDirectory: directory)
        again.receipt = nil
        let relaunched = launch(again)
        expectScreen("home", in: relaunched)
        XCTAssertFalse(relaunched.alerts.firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testStartingOverOnTheRelaunchPromptForgetsTheBillForGood() {
        let directory = Self.newDraftDirectory()
        let app = launch(Options(draftDirectory: directory))
        scan(app)
        tapNext(app)
        addPeople(["Ana"], in: app)
        backgroundAndTerminate(app)

        var again = Options(draftDirectory: directory)
        again.receipt = nil
        let second = launch(again)
        answerResumePrompt(second, button: "Comenzar de nuevo")
        expectScreen("home", in: second)
        XCTAssertFalse(element(second, "home.resume").exists)

        backgroundAndTerminate(second)
        let third = launch(again)
        expectScreen("home", in: third)
        XCTAssertFalse(third.alerts.firstMatch.waitForExistence(timeout: 3), "starting over deleted the draft")
    }
}

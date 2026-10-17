import XCTest

/// The audit waivers are narrow: these tests are what keeps them narrow. (Plain XCTest, no app launch.)
final class AuditWaiverTests: XCTestCase {
    private let window = CGRect(x: 0, y: 0, width: 402, height: 874)
    private let navigationBar = CGRect(x: 0, y: 50, width: 402, height: 44)
    private let keyboard = CGRect(x: 0, y: 583, width: 402, height: 233)
    private let alert = CGRect(x: 32, y: 89, width: 338, height: 724)
    private let inContent = CGRect(x: 20, y: 300, width: 100, height: 20)

    private func reason(
        _ kind: AuditWaiver.Kind, _ frame: CGRect?, id: String = "", hittable: Bool = true,
        bar: Bool = true, keyboard hasKeyboard: Bool = false, alerts: Bool = false, sheet: Bool = false, pinned: [CGRect] = []
    ) -> AuditWaiver.Reason? {
        AuditWaiver.reason(
            kind: kind, elementFrame: frame, elementIdentifier: id, isHittable: hittable, window: window,
            navigationBar: bar ? navigationBar : nil, keyboard: hasKeyboard ? keyboard : nil, alerts: alerts ? [alert] : [], pinnedBars: pinned, underSheet: sheet
        )
    }

    func testTheKeyboardAndItsSuggestionBarWaiveEveryKindOfFinding() {
        let suggestion = CGRect(x: 0, y: 538, width: 134, height: 45)
        let key = CGRect(x: 10, y: 700, width: 30, height: 40)
        for kind in [AuditWaiver.Kind.dynamicType, .contrast, .inaccessibleText, .textClipped, .other] {
            XCTAssertEqual(reason(kind, suggestion, keyboard: true), .systemView, "\(kind)")
            XCTAssertEqual(reason(kind, key, keyboard: true), .systemView, "\(kind)")
        }
        XCTAssertNil(reason(.other, CGRect(x: 16, y: 300, width: 100, height: 45), keyboard: true), "content well above the keyboard is ours")
    }

    func testAnAlertWaivesWhatIsInsideIt() {
        XCTAssertEqual(reason(.dynamicType, CGRect(x: 48, y: 99, width: 306, height: 125), alerts: true), .systemView)
        XCTAssertNil(reason(.dynamicType, CGRect(x: 2, y: 300, width: 20, height: 20), alerts: true), "outside the alert")
    }

    func testTheNavigationBarWaivesDynamicTypeAndNothingElse() {
        let inBar = CGRect(x: 160, y: 60, width: 80, height: 20)
        XCTAssertEqual(reason(.dynamicType, inBar), .navigationBarDoesNotScale)
        XCTAssertNil(reason(.other, inBar), "a hit area or a description in the bar is still a failure")
        XCTAssertNil(reason(.contrast, inBar))
    }

    func testTextInTheContentIsNeverWaivedForDynamicType() {
        XCTAssertNil(reason(.dynamicType, inContent, keyboard: true))
        XCTAssertNil(reason(.dynamicType, inContent, bar: false))
    }

    func testContrastIsWaivedOnlyForAnElementThatIsHiddenOrPartlyOffScreen() {
        XCTAssertNil(reason(.contrast, inContent), "fully visible: a real finding")
        XCTAssertEqual(reason(.contrast, CGRect(x: 28, y: -123, width: 265, height: 125)), .contrastOfAHiddenElement)
        XCTAssertEqual(reason(.contrast, CGRect(x: 20, y: 860, width: 100, height: 40)), .contrastOfAHiddenElement)
        XCTAssertEqual(reason(.contrast, CGRect(x: 84, y: 685, width: 58, height: 20), hittable: false), .contrastOfAHiddenElement, "under the pinned bar")
        let pinnedBar = CGRect(x: 0, y: 700, width: 402, height: 174)
        XCTAssertEqual(reason(.contrast, CGRect(x: 84, y: 685, width: 58, height: 20), pinned: [pinnedBar]), .contrastOfAHiddenElement, "straddling the pinned bar")
        XCTAssertNil(reason(.contrast, CGRect(x: 84, y: 400, width: 58, height: 20), pinned: [pinnedBar]), "above the bar")
        XCTAssertNil(reason(.other, CGRect(x: 28, y: -123, width: 265, height: 125)), "only contrast")
    }

    func testInaccessibleTextIsWaivedOnlyBehindASheet() {
        XCTAssertEqual(reason(.inaccessibleText, nil, sheet: true), .screenBehindASheet)
        XCTAssertNil(reason(.inaccessibleText, nil, sheet: false))
        XCTAssertNil(reason(.other, nil, sheet: true))
    }

    func testOnlyADynamicTypeFindingWithoutAnElementIsWaivedForHavingNone() {
        XCTAssertEqual(reason(.dynamicType, nil), .dynamicTypeWithoutAnElement)
        for kind in [AuditWaiver.Kind.contrast, .textClipped, .other] {
            XCTAssertNil(reason(kind, nil), "\(kind)")
        }
    }

    func testOnlyTheNamedFootnotesMayWrapInsteadOfClip() {
        XCTAssertEqual(reason(.textClipped, inContent, id: "capture.privacy"), .wrappingText)
        XCTAssertEqual(reason(.textClipped, inContent, id: "assign.rowHint"), .wrappingText)
        XCTAssertNil(reason(.textClipped, inContent, id: ""), "an unnamed text that may clip is a finding")
        XCTAssertNil(reason(.textClipped, inContent, id: "review.item.1"))
        XCTAssertNil(reason(.other, inContent, id: "capture.privacy"))
    }
}

import XCTest

/// The audit waivers are narrow: these tests are what keeps them narrow. (Plain XCTest, no app launch.)
final class AuditWaiverTests: XCTestCase {
    private let window = CGRect(x: 0, y: 0, width: 402, height: 874)
    private let navigationBar = CGRect(x: 0, y: 50, width: 402, height: 44)
    private let keyboard = CGRect(x: 0, y: 500, width: 402, height: 300)

    private func reason(_ kind: AuditWaiver.Kind, _ frame: CGRect?, bar: Bool = true, system: [CGRect] = [], sheet: Bool = false) -> AuditWaiver.Reason? {
        AuditWaiver.reason(kind: kind, elementFrame: frame, window: window, navigationBar: bar ? navigationBar : nil, systemFrames: system, underSheet: sheet)
    }

    func testTheKeyboardWaivesEveryKindOfFinding() {
        let inKeyboard = CGRect(x: 0, y: 538, width: 134, height: 45)
        for kind in [AuditWaiver.Kind.dynamicType, .contrast, .inaccessibleText, .other] {
            XCTAssertEqual(reason(kind, inKeyboard, system: [keyboard]), .systemView, "\(kind)")
        }
    }

    func testTheNavigationBarWaivesDynamicTypeAndNothingElse() {
        let inBar = CGRect(x: 160, y: 60, width: 80, height: 20)
        XCTAssertEqual(reason(.dynamicType, inBar), .navigationBarDoesNotScale)
        XCTAssertNil(reason(.other, inBar), "a hit area or a description in the bar is still a failure")
        XCTAssertNil(reason(.contrast, inBar))
    }

    func testTextInTheContentIsNeverWaivedForDynamicType() {
        let inContent = CGRect(x: 20, y: 300, width: 100, height: 20)
        XCTAssertNil(reason(.dynamicType, inContent, system: [keyboard]))
        XCTAssertNil(reason(.dynamicType, inContent, bar: false))
    }

    func testContrastIsWaivedOnlyForAnElementPartlyOffScreen() {
        XCTAssertNil(reason(.contrast, CGRect(x: 20, y: 300, width: 100, height: 20)), "fully on screen: a real finding")
        XCTAssertEqual(reason(.contrast, CGRect(x: 28, y: -123, width: 265, height: 125)), .contrastOfAPartlyHiddenElement)
        XCTAssertEqual(reason(.contrast, CGRect(x: 20, y: 860, width: 100, height: 40)), .contrastOfAPartlyHiddenElement)
        XCTAssertNil(reason(.other, CGRect(x: 28, y: -123, width: 265, height: 125)), "only contrast")
    }

    func testInaccessibleTextIsWaivedOnlyBehindASheet() {
        XCTAssertEqual(reason(.inaccessibleText, nil, sheet: true), .screenBehindASheet)
        XCTAssertNil(reason(.inaccessibleText, nil, sheet: false))
        XCTAssertNil(reason(.other, nil, sheet: true))
    }
}

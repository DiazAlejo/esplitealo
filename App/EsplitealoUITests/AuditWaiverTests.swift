import XCTest

/// The audit waivers are narrow: these tests are what keeps them narrow. (Plain XCTest, no app launch.)
final class AuditWaiverTests: XCTestCase {
    private let navigationBar = CGRect(x: 0, y: 50, width: 390, height: 44)
    private let keyboard = CGRect(x: 0, y: 500, width: 390, height: 300)

    func testTheKeyboardWaivesEveryKindOfFinding() {
        for isDynamicType in [true, false] {
            XCTAssertEqual(
                AuditWaiver.reason(isDynamicTypeIssue: isDynamicType, elementCenter: CGPoint(x: 100, y: 600), navigationBar: navigationBar, systemFrames: [keyboard]),
                .systemView
            )
        }
    }

    func testTheNavigationBarWaivesDynamicTypeAndNothingElse() {
        let inBar = CGPoint(x: 195, y: 70)
        XCTAssertEqual(AuditWaiver.reason(isDynamicTypeIssue: true, elementCenter: inBar, navigationBar: navigationBar, systemFrames: []), .navigationBarDoesNotScale)
        XCTAssertNil(AuditWaiver.reason(isDynamicTypeIssue: false, elementCenter: inBar, navigationBar: navigationBar, systemFrames: []), "a hit area or a description in the bar is still a failure")
    }

    func testTextInTheContentIsNeverWaived() {
        let inContent = CGPoint(x: 100, y: 300)
        XCTAssertNil(AuditWaiver.reason(isDynamicTypeIssue: true, elementCenter: inContent, navigationBar: navigationBar, systemFrames: [keyboard]))
        XCTAssertNil(AuditWaiver.reason(isDynamicTypeIssue: false, elementCenter: inContent, navigationBar: nil, systemFrames: []))
    }

    func testWithoutANavigationBarNothingIsWaivedForItsSake() {
        XCTAssertNil(AuditWaiver.reason(isDynamicTypeIssue: true, elementCenter: CGPoint(x: 195, y: 70), navigationBar: nil, systemFrames: []))
    }
}

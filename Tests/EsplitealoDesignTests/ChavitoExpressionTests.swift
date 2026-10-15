import XCTest
@testable import EsplitealoDesign

final class ChavitoExpressionTests: XCTestCase {
    func testFourExpressionsInMockupOrder() {
        XCTAssertEqual(ChavitoExpression.allCases, [.neutral, .happy, .thinking, .worried])
    }

    func testDefaultLookMatchesMockup() {
        XCTAssertEqual(ChavitoExpression.neutral.defaultLook, ChavitoPoint(x: 0, y: 0))
        XCTAssertEqual(ChavitoExpression.happy.defaultLook, ChavitoPoint(x: 0, y: 0))
        XCTAssertEqual(ChavitoExpression.thinking.defaultLook, ChavitoPoint(x: 3, y: -4))
        XCTAssertEqual(ChavitoExpression.worried.defaultLook, ChavitoPoint(x: -2, y: 2))
    }

    func testOnlyHappyHasShutEyes() {
        XCTAssertEqual(ChavitoExpression.allCases.filter { !$0.hasOpenEyes }, [.happy])
    }
}

final class ChavitoAccessibilityTests: XCTestCase {
    func testSpanishLabelsMatchMockupStrings() {
        let labels = ChavitoExpression.allCases.map { ChavitoAccessibility.label(for: $0, in: .spanish) }
        XCTAssertEqual(labels, [
            "Chavito, el mapache",
            "Chavito, el mapache, contento",
            "Chavito, el mapache, pensando",
            "Chavito, el mapache, preocupado",
        ])
    }

    func testEnglishLabelsMatchMockupStrings() {
        let labels = ChavitoExpression.allCases.map { ChavitoAccessibility.label(for: $0, in: .english) }
        XCTAssertEqual(labels, [
            "Chavito the raccoon",
            "Chavito the raccoon, happy",
            "Chavito the raccoon, thinking",
            "Chavito the raccoon, worried",
        ])
    }

    func testLanguageFollowsLocale() {
        XCTAssertEqual(ChavitoLanguage(locale: Locale(identifier: "es_PR")), .spanish)
        XCTAssertEqual(ChavitoLanguage(locale: Locale(identifier: "es")), .spanish)
        XCTAssertEqual(ChavitoLanguage(locale: Locale(identifier: "en_US")), .english)
        XCTAssertEqual(ChavitoLanguage(locale: Locale(identifier: "fr_FR")), .english)
    }

    func testDecorativeMascotHasNoLabel() {
        XCTAssertNil(ChavitoAccessibility.description(for: .happy, language: .english, decorative: true))
        XCTAssertEqual(
            ChavitoAccessibility.description(for: .happy, language: .english, decorative: false),
            "Chavito the raccoon, happy"
        )
    }
}

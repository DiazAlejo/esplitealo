import XCTest
@testable import EsplitealoCore
@testable import OCRBenchmarkKit

final class StringSimilarityTests: XCTestCase {
    func testNormalizedSimilarityIdentical() {
        XCTAssertEqual(StringSimilarity.normalized("Coffee", "Coffee"), 1.0, accuracy: 0.001)
    }

    func testNormalizedSimilarityTypo() {
        let sim = StringSimilarity.normalized("Margherita", "Margarita")
        XCTAssertGreaterThan(sim, 0.7)
    }
}

import XCTest
@testable import EsplitealoCore

final class PriceStringParsingTests: XCTestCase {
    func testInfersDotDecimalFormatFromPriceStrings() {
        let format = PriceStringParsing.inferFormat(from: ["12.50", "3.00", "not a price"])
        XCTAssertEqual(format.decimalSeparator, ".")
        XCTAssertEqual(format.fractionDigits, 2)
    }

    func testInfersCommaDecimalFormatFromPriceStrings() {
        let format = PriceStringParsing.inferFormat(from: ["12,50", "3,00"])
        XCTAssertEqual(format.decimalSeparator, ",")
        XCTAssertEqual(format.fractionDigits, 2)
    }

    func testMinorUnitsUsesTheGivenFormat() {
        XCTAssertEqual(PriceStringParsing.minorUnits(of: "12.50", format: .usdCents), 1250)
        XCTAssertEqual(PriceStringParsing.minorUnits(of: "12", format: .usdCents), 1200)
        XCTAssertNil(PriceStringParsing.minorUnits(of: "hello", format: .usdCents))
    }
}

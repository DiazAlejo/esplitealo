import XCTest
@testable import EsplitealoCore

final class AmountTokenTests: XCTestCase {
    func testDotDecimal() {
        let token = AmountToken.parse("12.50")!
        XCTAssertEqual(token.shape, .decimalDot)
        let format = NumberFormat.usdCents
        XCTAssertEqual(NumberFormatInference.minorUnits(token, format: format), 1250)
    }

    func testCommaDecimal() {
        let token = AmountToken.parse("12,50")!
        let format = NumberFormat(decimalSeparator: ",", groupSeparator: ".", fractionDigits: 2)
        XCTAssertEqual(NumberFormatInference.minorUnits(token, format: format), 1250)
    }

    func testThousandsDotZeroDecimalLocale() {
        let tokens = ["32.000", "14.000", "50.600"].compactMap(AmountToken.parse)
        let format = NumberFormatInference.infer(from: tokens)
        XCTAssertEqual(format.fractionDigits, 0)
        XCTAssertEqual(NumberFormatInference.minorUnits(tokens[0], format: format), 32000)
    }

    func testPhoneIsNotAmount() {
        XCTAssertNil(AmountToken.parse("555-0142"))
    }

    func testDateIsNotAmount() {
        XCTAssertNil(AmountToken.parse("03/14/2026"))
    }

    func testPlainIntegerNotReadAsCentsOnUSD() {
        let token = AmountToken.parse("1250")!
        XCTAssertEqual(token.shape, .integer)
        XCTAssertNil(NumberFormatInference.minorUnits(token, format: .usdCents))
    }
}

import XCTest
@testable import EsplitealoCore

final class CordGroundTruthParserTests: XCTestCase {
    func testParsesSimpleMenuArray() throws {
        let json = """
        {
          "menu": [
            {"nm": "Latte", "cnt": "2", "price": "5500"},
            {"nm": "Cake", "cnt": "1", "price": "12000"}
          ],
          "sub_total": {"price": "23000"},
          "tax": {"price": "2300"},
          "total": {"price": "25300"}
        }
        """.data(using: .utf8)!
        let truth = try CordGroundTruthParser.parse(id: "cord-test", data: json)
        XCTAssertEqual(truth.items.count, 2)
        XCTAssertEqual(truth.items[0].lineTotalMinor, 5500)
        XCTAssertEqual(truth.items[0].quantity, 2)
        XCTAssertEqual(truth.subtotalMinor, 23000)
        XCTAssertEqual(truth.totalMinor, 25300)
    }

    func testDigitsOnlyMinorStripsFormatting() {
        XCTAssertEqual(CordGroundTruthParser.digitsOnlyMinor("12.500"), 12500)
    }

    func testParsesCordSubtotalAndTotalFields() throws {
        let json = """
        {
          "menu": {"nm": "Latte", "cnt": "1", "price": "5500"},
          "sub_total": {"subtotal_price": "5500"},
          "total": {"total_price": "6050"}
        }
        """.data(using: .utf8)!
        let truth = try CordGroundTruthParser.parse(id: "c1", data: json)
        XCTAssertEqual(truth.subtotalMinor, 5500)
        XCTAssertEqual(truth.totalMinor, 6050)
    }
}

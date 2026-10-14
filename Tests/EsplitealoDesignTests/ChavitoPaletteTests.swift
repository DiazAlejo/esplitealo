import XCTest
@testable import EsplitealoDesign

final class ChavitoPaletteTests: XCTestCase {
    func testHexInit() {
        let c = ChavitoColor(hex: 0xEA5A78)
        XCTAssertEqual(c.red, 0xEA)
        XCTAssertEqual(c.green, 0x5A)
        XCTAssertEqual(c.blue, 0x78)
        XCTAssertEqual(c.hexString, "#EA5A78")
    }

    func testPinkIsTheSameInDarkMode() {
        for role in [ChavitoColorRole.nose, .cheek] {
            XCTAssertEqual(ChavitoPalette.light.color(for: role).hexString, "#EA5A78")
            XCTAssertEqual(ChavitoPalette.dark.color(for: role).hexString, "#EA5A78")
        }
    }

    func testMascotColoursMatchTokens() {
        let p = ChavitoPalette.light
        XCTAssertEqual(p.color(for: .fur).hexString, "#9AA5B1")
        XCTAssertEqual(p.color(for: .furShade).hexString, "#5A6470")
        XCTAssertEqual(p.color(for: .mask).hexString, "#2B333D")
        XCTAssertEqual(p.color(for: .cream).hexString, "#F5EEDF")
        XCTAssertEqual(p.color(for: .tear).hexString, "#7FC4E8")
        XCTAssertEqual(p.color(for: .white).hexString, "#FFFFFF")
    }

    func testCreamStaysCreamOnDark() {
        XCTAssertEqual(ChavitoPalette.dark.color(for: .cream).hexString, "#F5EEDF")
    }

    func testSoftDiscFollowsPinkSoftToken() {
        // light: pink 14% on white; dark: pink 24% on #1B1519 (tokens.css section 3)
        XCTAssertEqual(ChavitoPalette.light.color(for: .disc).hexString, "#FCE8EC")
        XCTAssertEqual(ChavitoPalette.dark.color(for: .disc).hexString, "#4D2630")
    }

    func testGroundColours() {
        XCTAssertEqual(ChavitoPalette.light.ground.hexString, "#FBF7EF")
        XCTAssertEqual(ChavitoPalette.dark.ground.hexString, "#0F2A21")
    }

    func testPaletteForAppearance() {
        XCTAssertEqual(ChavitoPalette.palette(for: .light), ChavitoPalette.light)
        XCTAssertEqual(ChavitoPalette.palette(for: .dark), ChavitoPalette.dark)
    }

    func testEveryRoleResolves() {
        for role in ChavitoColorRole.allCases {
            XCTAssertEqual(ChavitoPalette.light.color(for: role).hexString.count, 7)
            XCTAssertEqual(ChavitoPalette.dark.color(for: role).hexString.count, 7)
        }
    }
}

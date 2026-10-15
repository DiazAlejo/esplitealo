import CoreText
import Foundation
import Testing
@testable import EsplitealoDesign

struct TypographyTests {
    @Test func scaleMatchesTheDesignGuide() {
        let expected: [(TypeStyle, Double, TypeWeight)] = [
            (.displayAmount, 40, .semibold),
            (.amount, 22, .medium),
            (.headline, 17, .semibold),
            (.body, 17, .regular),
            (.subhead, 15, .regular),
            (.footnote, 13, .regular),
            (.caption, 12, .medium),
        ]
        for (style, size, weight) in expected {
            #expect(style.spec.size == size, "\(style) size")
            #expect(style.spec.weight == weight, "\(style) weight")
        }
    }

    @Test func nothingIsSmallerThanTwelvePoints() {
        for style in TypeStyle.allCases {
            #expect(style.spec.size >= 12, "\(style)")
        }
    }

    @Test func unkemptSetsTitlesAndTheWordmarkOnly() {
        let unkempt = TypeStyle.allCases.filter { $0.spec.family.isUnkempt }
        #expect(Set(unkempt) == [.title, .wordmark])
    }

    @Test func moneyNeverUsesUnkempt() {
        // Unkempt has proportional digits and no tabular figures, so prices would not line up.
        for style in TypeStyle.allCases where style.isMoney {
            #expect(!style.spec.family.isUnkempt, "\(style)")
        }
    }

    @Test func moneyStylesAreRoundedWithMonospacedDigits() {
        let money = TypeStyle.allCases.filter(\.isMoney)
        #expect(Set(money) == [.displayAmount, .amount])
        for style in money {
            #expect(style.spec.family == .systemRounded)
            #expect(style.spec.monospacedDigits)
        }
    }

    @Test func everyStyleScalesWithDynamicType() {
        for style in TypeStyle.allCases {
            #expect(style.spec.textStyle != nil, "\(style)")
        }
    }

    @Test func onlyTheDisplayAmountMayShrinkAndOnlyAtAccessibilitySizes() {
        for style in TypeStyle.allCases {
            #expect((style.spec.minimumScaleFactor != nil) == (style == .displayAmount), "\(style)")
        }
    }

    @Test func titlesUseRegularAndTheWordmarkUsesBold() {
        #expect(TypeStyle.title.spec.family == .unkempt(.regular))
        #expect(TypeStyle.wordmark.spec.family == .unkempt(.bold))
        #expect(TypeStyle.title.spec.size == 26)
    }

    @Test func fontFilesShipWithTheirLicenses() throws {
        let fonts = DesignFonts.fontURLs()
        #expect(fonts.map(\.lastPathComponent).sorted() == ["Unkempt-Bold.ttf", "Unkempt-Regular.ttf"])
        let licenses = DesignFonts.licenseURLs()
        #expect(licenses.map(\.lastPathComponent).sorted() == ["LICENSE-Unkempt-Apache-2.0.txt", "LICENSE-Unkempt-Bold-OFL-1.1.txt"])
        for url in licenses {
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.contains("Font Diner") || text.contains("Apache License"))
        }
    }

    @Test func registeringTheFontsMakesThemAvailableAndIsIdempotent() {
        DesignFonts.registerAll()
        DesignFonts.registerAll()
        for name in ["Unkempt-Regular", "Unkempt-Bold"] {
            let font = CTFontCreateWithName(name as CFString, 20, nil)
            #expect(CTFontCopyPostScriptName(font) as String == name)
        }
    }
}

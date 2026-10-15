import Testing
@testable import EsplitealoDesign

struct PersonColorTests {
    @Test func eightSlotsInTheDocumentedOrder() {
        #expect(PersonColorSlot.allCases.map(\.name) == [
            "Denim", "Ochre", "Plum", "Umber", "Lagoon", "Stone", "Heather", "Slate",
        ])
    }

    @Test func fillsMatchTokens() {
        let light = PersonColorSlot.allCases.map { $0.fill(in: .light).hexString }
        let dark = PersonColorSlot.allCases.map { $0.fill(in: .dark).hexString }
        #expect(light == ["#5070B2", "#72650F", "#572F5F", "#634521", "#146579", "#5E5A54", "#77618F", "#363D4B"])
        #expect(dark == ["#9BBAF7", "#D9CE8D", "#AF89B6", "#BCA07F", "#7CB9CA", "#CDC9C2", "#D6C2EE", "#979EAC"])
    }

    @Test func letterColorIsWhiteInLightAndDarkInkInDark() {
        #expect(PersonColorSlot.denim.letter(in: .light).hexString == "#FFFFFF")
        #expect(PersonColorSlot.denim.letter(in: .dark).hexString == "#111915")
    }

    @Test func slotsAreHandedOutInOrderAndWrapAfterEight() {
        #expect(PersonColorSlot(participantIndex: 0) == .denim)
        #expect(PersonColorSlot(participantIndex: 7) == .slate)
        #expect(PersonColorSlot(participantIndex: 8) == .denim)
        #expect(PersonColorSlot(participantIndex: 11) == .umber)
    }

    @Test func ninthPersonOnwardsGetsTheDottedRing() {
        #expect(!PersonColorSlot.usesDottedRing(participantIndex: 7))
        #expect(PersonColorSlot.usesDottedRing(participantIndex: 8))
        #expect(PersonColorSlot.usesDottedRing(participantIndex: 20))
    }

    @Test func personColorsAvoidTheBrandColours() {
        // Nothing may sit on top of the green, the pink or the warn red-orange.
        for appearance in [DesignAppearance.light, .dark] {
            let palette = DesignPalette.palette(for: appearance)
            for slot in PersonColorSlot.allCases {
                let fill = slot.fill(in: appearance)
                #expect(fill != palette.primary)
                #expect(fill != palette.pink)
                #expect(fill != palette.warn)
            }
        }
    }

    @Test(arguments: [
        ("Ana", "A"), ("  ben ", "B"), ("ñandú", "Ñ"), ("élodie", "É"), ("🦝 Chavito", "🦝"), ("", "?"), ("   ", "?"),
    ])
    func initialIsTheFirstLetterUppercased(name: String, expected: String) {
        #expect(PersonInitial.make(from: name) == expected)
    }
}

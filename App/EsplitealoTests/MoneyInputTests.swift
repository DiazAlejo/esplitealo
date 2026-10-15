import Testing
@testable import Esplitealo

/// What people type into a price or an amount field becomes integer cents, or nothing: never a guess.
struct MoneyInputTests {
    @Test(arguments: [
        ("12.50", 1250), ("12", 1200), ("12.5", 1250), ("0", 0), ("0.05", 5), (".50", 50), ("12.", 1200),
        ("12,50", 1250), ("12,5", 1250),
        ("$12.50", 1250), (" 12.50 ", 1250), ("$ 12.50", 1250),
        ("1,234.56", 123_456), ("1,234", 123_400), ("999,999.99", 99_999_999),
    ])
    func readsAmounts(text: String, cents: Int) {
        #expect(MoneyInput.cents(from: text) == cents)
    }

    @Test(arguments: [
        "", " ", "abc", "-5", "−5", "12.345", "1.234", "1,2,3", "12..50", "1e5", "12.50.10", "$", ".", "12 50", "12,3456",
        "1000000", "999999999.99", "١٢",
    ])
    func rejectsAnythingElse(text: String) {
        #expect(MoneyInput.cents(from: text) == nil)
    }

    @Test func editableTextAlwaysHasTwoDecimalsAndADot() {
        #expect(MoneyInput.editableText(cents: 1900) == "19.00")
        #expect(MoneyInput.editableText(cents: 5) == "0.05")
        #expect(MoneyInput.editableText(cents: 0) == "0.00")
        #expect(MoneyInput.editableText(cents: 123_456) == "1234.56")
    }

    @Test func editableTextReadsBackToTheSameCents() {
        for cents in [0, 1, 99, 100, 1250, 99_999, 9_999_999] {
            #expect(MoneyInput.cents(from: MoneyInput.editableText(cents: cents)) == cents)
        }
    }
}

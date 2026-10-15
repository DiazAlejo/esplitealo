import EsplitealoDesign
import SwiftUI
import Testing

/// Snapshots of the design-system components in light/dark, Spanish/English and the largest Dynamic Type size.
/// Delete the matching file in `__Snapshots__` and re-run to record a new reference after an intended change.
@MainActor
struct ComponentSnapshotTests {
    @Test func primaryButton() {
        assertDesignSnapshot(
            VStack(spacing: Spacing.sm) {
                Button("home.scan") {}.buttonStyle(.espPrimary(showsDivisionCoin: true))
                Button("review.continue") {}.buttonStyle(.espPrimary)
                Button("home.scan") {}.buttonStyle(.espPrimary).disabled(true)
            }
            .padding(Spacing.screenMargin),
            named: "primary-button"
        )
    }

    @Test func secondaryAndQuietButtons() {
        assertDesignSnapshot(
            VStack(spacing: Spacing.sm) {
                Button("home.photo") {}.buttonStyle(.espSecondary)
                Button("processing.cancel") {}.buttonStyle(.espQuiet)
                Button("review.fixIt") {}.buttonStyle(.espWarn)
            }
            .padding(Spacing.screenMargin),
            named: "secondary-buttons"
        )
    }

    @Test func card() {
        assertDesignSnapshot(
            EspCard {
                AmountRow(verbatim: "Jugo de parcha", cents: 400)
                AmountRow(verbatim: "Mofongo de camarones", cents: 2200)
                AmountRow(verbatim: "Flan para compartir", cents: 900)
            }
            .padding(Spacing.screenMargin),
            named: "card-rows"
        )
    }

    @Test func personAvatars() {
        let names = ["Marisol", "Héctor", "Keishla", "Yadiel", "Ñandú", "Lola", "Ivelisse", "Samuel", "Nueve", "Diez"]
        assertDesignSnapshot(
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                        PersonAvatar(name: name, participantIndex: index, size: 28)
                    }
                }
                ForEach(0 ..< 3, id: \.self) { index in
                    PersonChip(name: names[index], participantIndex: index, subtotalCents: [1400, 2650, 900][index])
                }
            }
            .padding(Spacing.screenMargin),
            named: "person-avatars"
        )
    }

    @Test func sectionHeaderAndTitle() {
        assertDesignSnapshot(
            VStack(alignment: .leading, spacing: Spacing.md) {
                EspTitle("review.title")
                EspSectionHeader("review.items")
                EspSectionHeader("review.amounts")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin),
            named: "title-and-section-headers"
        )
    }

    @Test func moneyUsesMonospacedDigitsAndNeverUnkempt() {
        assertDesignSnapshot(
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                MoneyText(cents: 111_111, style: .displayAmount)
                MoneyText(cents: 88_888, style: .displayAmount)
                MoneyText(cents: 12_345, style: .amount)
                MoneyText(cents: 1_000, style: .amount)
                MoneyText(cents: -250, style: .amount)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(Spacing.screenMargin),
            named: "money"
        )
    }

    @Test func wordmark() {
        assertDesignSnapshot(
            EspWordmark().padding(Spacing.screenMargin),
            named: "wordmark",
            variants: [.lightSpanish, .darkSpanish]
        )
    }

    @Test func typeScale() {
        assertDesignSnapshot(
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Chequea el recibo").espText(.title)
                Text("Fonda Doña Lola").espText(.headline)
                Text("Pernil con gandules").espText(.body)
                Text("Corrige lo que leí mal.").espText(.subhead)
                Text("Incluye 1¢ de redondeo").espText(.footnote)
                Text("Sin marcar").espText(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screenMargin),
            named: "type-scale"
        )
    }

    @Test func palette() {
        assertDesignSnapshot(
            PaletteSpecimen().padding(Spacing.screenMargin),
            named: "palette",
            variants: [.lightSpanish, .darkSpanish]
        )
    }
}

/// Every colour role as a swatch, so a token change shows up as a snapshot diff.
private struct PaletteSpecimen: View {
    private let roles: [(String, Color)] = [
        ("paper", Color.esp.paper), ("surface", Color.esp.surface), ("well", Color.esp.well),
        ("ink", Color.esp.ink), ("ink2", Color.esp.inkSecondary), ("line", Color.esp.line),
        ("primary", Color.esp.primary), ("lip", Color.esp.primaryLip), ("pink", Color.esp.pink),
        ("pinkInk", Color.esp.pinkInk), ("pinkSoft", Color.esp.pinkSoft), ("warn", Color.esp.warn),
        ("warnBg", Color.esp.warnBackground), ("okBg", Color.esp.okBackground),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 4), spacing: Spacing.xs) {
                ForEach(roles, id: \.0) { name, color in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 8).fill(color).frame(height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.esp.line))
                        Text(name).font(.system(size: 10, design: .monospaced))
                    }
                }
            }
            HStack(spacing: Spacing.xs) {
                ForEach(PersonColorSlot.allCases, id: \.self) { slot in
                    Circle().fill(slot.fillColor).frame(height: 32)
                }
            }
        }
    }
}

import EsplitealoDesign
import SwiftUI

/// "Continuar con tu cuenta": shown on Home whenever a bill with content exists, with its size and total, the way
/// back in at the step it reached, and the way to abandon it. A bill is never reachable only by luck.
struct ResumeBillCard: View {
    let bill: BillStore.BillInProgress
    let onContinue: () -> Void
    let onDiscard: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("home.resume.title")
                    .espText(.headline)
                    .foregroundStyle(Color.esp.ink)
                Text(.homeResumeSummary(MoneyFormatter(locale: locale).string(cents: bill.totalCents), bill.itemCount))
                    .espText(.subhead)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .accessibilityIdentifier("home.resume.summary")
            }
            Button("resume.continue", action: onContinue)
                .buttonStyle(.espSecondary)
                .accessibilityIdentifier("home.resume.continue")
            Button("bill.discard", role: .destructive, action: onDiscard)
                .buttonStyle(.espQuiet)
                .accessibilityIdentifier("home.resume.discard")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color.esp.surface))
        .overlay { shape.strokeBorder(Color.esp.line, lineWidth: Stroke.hairline) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.resume")
    }
}

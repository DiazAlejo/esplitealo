import EsplitealoDesign
import SwiftUI

/// "Cómo funciona": the four steps of a bill, one tap away from Home, replayable any time.
struct HowItWorksSheet: View {
    var onDone: () -> Void

    private struct Step: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private let steps = [
        Step(id: 1, title: "how.step1.title", detail: "how.step1.body"),
        Step(id: 2, title: "how.step2.title", detail: "how.step2.body"),
        Step(id: 3, title: "how.step3.title", detail: "how.step3.body"),
        Step(id: 4, title: "how.step4.title", detail: "how.step4.body"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                EspTitle("how.title")
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(steps) { step in
                        HStack(alignment: .center, spacing: Spacing.sm) {
                            Text(verbatim: "\(step.id)")
                                .espText(.headline)
                                .foregroundStyle(Color.esp.primary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.esp.okBackground))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(step.title).espText(.headline).foregroundStyle(Color.esp.ink)
                                Text(step.detail).espText(.subhead).foregroundStyle(Color.esp.inkSecondary)
                            }
                        }
                        .frame(minHeight: TapTarget.minimum)
                        .accessibilityElement(children: .combine)
                    }
                }
                Button("how.ok", action: onDone)
                    .buttonStyle(.espPrimary)
                    .accessibilityIdentifier("how.done")
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .espScreenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("how.sheet")
    }
}

#Preview("How it works, Español") {
    HowItWorksSheet(onDone: {})
        .environment(\.locale, Locale(identifier: "es"))
}

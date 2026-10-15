import EsplitealoDesign
import SwiftUI

/// The reading screen: Chavito with his magnifying-glass look, the status line, a thin indeterminate bar, the privacy
/// reassurance, and (after a few seconds) a way out by typing the items in.
struct ProcessingContent: View {
    var messageIndex: Int
    var offersManualEntry: Bool
    var animates = true
    var onManual: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        CenteredScroll {
            VStack(spacing: Spacing.sm) {
                ChavitoView(expression: .thinking, size: 220, disc: true, animated: animates)
                    .accessibilityLabel("mascot.processing")
                message
                    .espText(.title)
                    .foregroundStyle(Color.esp.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                    .accessibilityAddTraits(.isHeader)
                IndeterminateBar(animates: animates)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("processing.bar")
                    .accessibilityValue(messageText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("capture.progress")
                Text("processing.footer")
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)
                Group {
                    if offersManualEntry {
                        Button("processing.manual", action: onManual)
                            .buttonStyle(.espSecondary)
                            .accessibilityIdentifier("capture.manual")
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
                .frame(minHeight: 56)
                .padding(.top, Spacing.xs)
            }
        }
        .espScreenBackground()
        .captureBackButton("processing.cancel", showsChevron: false, action: onCancel)
    }

    @ViewBuilder private var message: some View {
        switch messageIndex % ScanFlow.messageCount {
        case 0: Text("processing.message1")
        case 1: Text("processing.message2")
        default: Text("processing.message3")
        }
    }

    private var messageText: Text {
        switch messageIndex % ScanFlow.messageCount {
        case 0: Text("processing.message1")
        case 1: Text("processing.message2")
        default: Text("processing.message3")
        }
    }
}

#Preview("Reading, Español") {
    NavigationStack { ProcessingContent(messageIndex: 1, offersManualEntry: false) }
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Reading, English, dark, slow") {
    NavigationStack { ProcessingContent(messageIndex: 2, offersManualEntry: true) }
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

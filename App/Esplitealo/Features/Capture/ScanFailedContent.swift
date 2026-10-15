import EsplitealoDesign
import SwiftUI

/// A scan that did not work: a worried Chavito, what happened in plain words, and three ways forward. Nothing is
/// lost, and the screen says so.
struct ScanFailedContent: View {
    var failure: ScanFailure
    var source: ScanSource
    var animates = true
    var onRetry: () -> Void = {}
    var onManual: () -> Void = {}
    var onAnotherPhoto: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        CenteredScroll {
            VStack(spacing: Spacing.sm) {
                ChavitoView(expression: .worried, size: 220, disc: true, animated: animates)
                    .accessibilityLabel("mascot.failed")
                Text(failure.title)
                    .espText(.title)
                    .foregroundStyle(Color.esp.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xxs)
                    .accessibilityAddTraits(.isHeader)
                Text(failure.body)
                    .espText(.body)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.bottom, Spacing.xs)
                Button("processing.retry", action: onRetry)
                    .buttonStyle(.espPrimary(showsDivisionCoin: true))
                    .accessibilityIdentifier("capture.retry")
                Button("processing.manual", action: onManual)
                    .buttonStyle(.espSecondary)
                    .accessibilityIdentifier("capture.manual")
                if failure.offersAnotherPhoto(from: source) {
                    Button("processing.another", action: onAnotherPhoto)
                        .buttonStyle(.espQuiet)
                        .accessibilityIdentifier("capture.another")
                }
            }
        }
        .espScreenBackground()
        .captureBackButton("processing.back", showsChevron: true, action: onBack)
    }
}

#Preview("Failed, Español") {
    NavigationStack { ScanFailedContent(failure: .unreadable, source: .camera) }
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Too many pages, English, dark") {
    NavigationStack { ScanFailedContent(failure: .tooManyPages, source: .camera) }
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

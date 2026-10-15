import EsplitealoDesign
import SwiftUI

/// The camera cannot be used. Denied: explain how to turn it on in Settings, and keep the photo picker one tap away.
/// Restricted or missing: say so and offer the photo picker as the way to scan.
struct CaptureBlockedContent: View {
    var block: CaptureBlock
    var animates = false
    var onOpenSettings: () -> Void = {}
    var onChoosePhoto: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        CenteredScroll {
            VStack(spacing: Spacing.md) {
                VStack(spacing: Spacing.xs) {
                    ChavitoView(expression: .thinking, size: 140, disc: true, decorative: true, animated: animates)
                    Text(block.title)
                        .espText(.title)
                        .foregroundStyle(Color.esp.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(block.body)
                        .espText(.body)
                        .foregroundStyle(Color.esp.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Spacing.xs)
                    if block.offersSettings {
                        Button("capture.openSettings", action: onOpenSettings)
                            .buttonStyle(.espPrimary)
                            .accessibilityIdentifier("capture.openSettings")
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.esp.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.esp.line, lineWidth: Stroke.hairline)
                )
                photoButton
            }
        }
        .espScreenBackground()
        .captureBackButton("capture.cancel", showsChevron: false, action: onCancel)
    }

    @ViewBuilder private var photoButton: some View {
        let label = Label("capture.choose", systemImage: "photo.on.rectangle")
        if block.offersSettings {
            Button(action: onChoosePhoto) { label }
                .buttonStyle(.espSecondary)
                .accessibilityIdentifier("capture.choosePhoto")
        } else {
            // Nothing else to try: the photo picker is the one main action.
            Button(action: onChoosePhoto) { label }
                .buttonStyle(.espPrimary)
                .accessibilityIdentifier("capture.choosePhoto")
        }
    }
}

#Preview("Camera denied, Español") {
    NavigationStack { CaptureBlockedContent(block: .denied) }
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Camera unavailable, English, dark") {
    NavigationStack { CaptureBlockedContent(block: .unavailable) }
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

import EsplitealoDesign
import SwiftUI

/// A scrolling screen body whose content is centred when it fits and scrolls when it does not (large Dynamic Type).
struct CenteredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// The thin indeterminate bar of the reading screen: a green segment sliding along a quiet track. Under Reduce Motion
/// (or `animates: false`) the segment holds still in the middle.
struct IndeterminateBar: View {
    var animates = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    private let height: CGFloat = 6
    private let period = 1.4

    var body: some View {
        GeometryReader { proxy in
            let segment = proxy.size.width * 0.4
            ZStack(alignment: .leading) {
                Capsule().fill(Color.esp.well)
                if animates && !reduceMotion {
                    TimelineView(.animation) { context in
                        let phase = context.date.timeIntervalSince(started).truncatingRemainder(dividingBy: period) / period
                        // From fully off the left edge to fully off the right one, like the mockup's `slide`.
                        let x = -segment + (proxy.size.width + segment) * phase
                        Capsule().fill(Color.esp.primary).frame(width: segment).offset(x: x)
                    }
                } else {
                    Capsule().fill(Color.esp.primary).frame(width: segment).offset(x: (proxy.size.width - segment) / 2)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .frame(maxWidth: 220)
    }
}

extension View {
    /// The quiet text button at the top left of the capture screens ("Cancelar", "Atrás").
    func captureBackButton(_ title: LocalizedStringKey, showsChevron: Bool, action: @escaping () -> Void) -> some View {
        navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: action) {
                        // Not a `Label`: toolbars show only the icon of a label.
                        HStack(spacing: Spacing.xxs) {
                            if showsChevron {
                                Image(systemName: "chevron.backward").font(.body.weight(.semibold))
                            }
                            Text(title)
                        }
                        .espText(.body)
                        .foregroundStyle(Color.esp.primary)
                    }
                    .accessibilityIdentifier("capture.back")
                }
            }
    }
}

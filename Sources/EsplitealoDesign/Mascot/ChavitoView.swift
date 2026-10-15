import SwiftUI

/// Chavito, the Esplitealo raccoon, drawn natively with SwiftUI paths (no assets, no animation library).
///
/// - `size` is the width in points. The bare head keeps the mockup's 200 × 190 aspect; with `disc` the view is
///   a square holding the soft pink disc (`--disc-hero`) with Chavito peeking over it.
/// - Blink, bob and the thinking tilt run on a `TimelineView` and stop entirely under Reduce Motion
///   (or `animated: false`).
/// - Unless `decorative`, VoiceOver reads a Spanish or English label for the expression, following the locale.
public struct ChavitoView: View {
    private let expression: ChavitoExpression
    private let size: CGFloat
    private let disc: Bool
    private let decorative: Bool
    private let language: ChavitoLanguage?
    private let animated: Bool
    private let drawing: ChavitoDrawing

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var appeared = Date()
    @State private var reactionStart: Date?

    public init(
        expression: ChavitoExpression,
        size: CGFloat,
        disc: Bool = false,
        decorative: Bool = false,
        language: ChavitoLanguage? = nil,
        animated: Bool = true
    ) {
        self.expression = expression
        self.size = size
        self.disc = disc
        self.decorative = decorative
        self.language = language
        self.animated = animated
        drawing = ChavitoDrawing(expression: expression, disc: disc)
    }

    public var body: some View {
        let motion = ChavitoMotion(expression: expression, reduceMotion: reduceMotion || !animated)
        let layout = ChavitoMetrics.layoutSize(forWidth: Double(size), disc: disc)
        let frame = CGSize(width: layout.width, height: layout.height)
        let palette = ChavitoPalette.palette(for: colorScheme == .dark ? .dark : .light)

        return Group {
            if motion.isAnimated {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    canvas(
                        palette: palette,
                        pose: motion.pose(
                            at: context.date.timeIntervalSince(appeared),
                            reactionElapsed: reactionStart.map { context.date.timeIntervalSince($0) }
                        )
                    )
                }
            } else {
                canvas(palette: palette, pose: .rest)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .onChange(of: expression) { reactionStart = Date() }
        .modifier(AccessibilityModifier(label: ChavitoAccessibility.description(
            for: expression,
            language: language ?? ChavitoLanguage(locale: locale),
            decorative: decorative
        )))
    }

    private func canvas(palette: ChavitoPalette, pose: ChavitoPose) -> some View {
        Canvas { context, canvasSize in
            drawing.draw(in: context, size: canvasSize, palette: palette, pose: pose)
        }
    }

    private struct AccessibilityModifier: ViewModifier {
        let label: String?

        func body(content: Content) -> some View {
            if let label {
                content
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: label))
                    .accessibilityAddTraits(.isImage)
            } else {
                content.accessibilityHidden(true)
            }
        }
    }
}

import SwiftUI

/// A card with hairline rows: every direct child view becomes a row, separated by a 1 pt hairline.
/// Surface fill, 16 pt corners, 1 pt `line` border.
///
/// The rows are laid out with `_VariadicView`: rows made with `Group(subviews:)` were measured at the default text
/// size and clipped at the larger Dynamic Type sizes.
public struct EspCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        _VariadicView.Tree(CardRows()) { content }
            .background(shape.fill(Color.esp.surface))
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.esp.line, lineWidth: Stroke.hairline) }
    }
}

private struct CardRows: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            ForEach(children) { row in
                row
                    .frame(maxWidth: .infinity, minHeight: TapTarget.minimum, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    // A hairline on top of every row; the first one sits under the card's own border.
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.esp.hairline)
                            .frame(height: Stroke.hairline)
                            .accessibilityHidden(true)
                    }
            }
        }
    }
}

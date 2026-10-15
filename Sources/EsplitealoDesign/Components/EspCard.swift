import SwiftUI

/// A card with hairline rows: every direct child view becomes a row, separated by a 1 pt hairline.
/// Surface fill, 16 pt corners, 1 pt `line` border.
public struct EspCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]
                        .frame(maxWidth: .infinity, minHeight: TapTarget.minimum, alignment: .leading)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color.esp.hairline)
                            .frame(height: Stroke.hairline)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .background(shape.fill(Color.esp.surface))
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.esp.line, lineWidth: Stroke.hairline) }
    }
}

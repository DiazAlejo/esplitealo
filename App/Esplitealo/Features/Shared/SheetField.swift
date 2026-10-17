import EsplitealoDesign
import SwiftUI

/// A labelled text input for sheets and forms: the label above, the field on a `well` fill, and the problem in words
/// under it (with a warn outline) when there is one. Pass the `TextField` as the content.
struct SheetField<Field: View>: View {
    private let label: LocalizedStringKey
    private let error: Text?
    private let field: Field

    init(_ label: LocalizedStringKey, error: Text? = nil, @ViewBuilder field: () -> Field) {
        self.label = label
        self.error = error
        self.field = field()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .espText(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.inkSecondary)
            field
                .espText(.body)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: TapTarget.primaryButtonHeight)
                .background(Color.esp.well, in: RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous))
                .espFieldOutline(isInvalid: error != nil)
            if let error {
                Label {
                    error
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                }
                .espText(.footnote)
                .foregroundStyle(Color.esp.warn)
            }
        }
    }
}

extension View {
    /// The outline of a text field. The fill alone is 1.1:1 against the page, which does not show where the field is;
    /// the outline is 3:1 (WCAG 1.4.11). A field with a problem gets the thicker warn outline.
    func espFieldOutline(isInvalid: Bool = false) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous)
                .strokeBorder(isInvalid ? Color.esp.warn : Color.esp.inkSecondary, lineWidth: isInvalid ? 1.5 : Stroke.hairline)
        }
    }
}

extension View {
    /// The decimal pad has no return key, so a "Listo" button on the keyboard is the way to put it away without
    /// reaching for the page (for Full Keyboard Access, Switch Control and anyone who cannot swipe the sheet down).
    func decimalPadDoneButton(_ dismiss: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done", action: dismiss)
            }
        }
    }
}

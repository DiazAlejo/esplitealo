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
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous)
                        .strokeBorder(Color.esp.warn, lineWidth: error == nil ? 0 : 1.5)
                }
            if let error {
                Label {
                    error
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .espText(.footnote)
                .foregroundStyle(Color.esp.warn)
            }
        }
    }
}

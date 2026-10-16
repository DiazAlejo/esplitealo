import EsplitealoDesign
import SwiftUI

/// Rows in a rounded card with a hairline between them, for rows that carry their own background (a flagged receipt
/// row, a row to check). `EspCard` pads every row itself; here a row fills the card edge to edge.
struct RowsCard<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    enum Style {
        /// White-ish card on the paper.
        case surface
        /// Quiet tinted card (receipt amounts).
        case well
        /// Card with a warn outline (the rows the parser wants checked).
        case warn
    }

    private let rows: Data
    private let style: Style
    private let row: (Data.Element) -> Row

    init(_ rows: Data, style: Style = .surface, @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.rows = rows
        self.style = style
        self.row = row
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, element in
                if index > 0 {
                    Rectangle()
                        .fill(Color.esp.hairline)
                        .frame(height: Stroke.hairline)
                        .accessibilityHidden(true)
                }
                row(element)
            }
        }
        .background(style == .well ? Color.esp.well : Color.esp.surface)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(style == .warn ? Color.esp.warn : Color.esp.line, lineWidth: style == .warn ? 1.5 : Stroke.hairline)
        }
    }
}

/// The pressed look of a tappable row: the `well` fill under it.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.esp.well : Color.clear)
            .contentShape(Rectangle())
    }
}

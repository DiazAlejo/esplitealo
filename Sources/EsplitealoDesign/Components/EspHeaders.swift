import SwiftUI

/// A screen title in Unkempt, with the pink ÷ before it. Wraps at large Dynamic Type sizes.
public struct EspTitle: View {
    private let title: LocalizedStringKey
    @ScaledMetric(relativeTo: .title) private var markSize: CGFloat = 16

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            DivisionMark()
                .fill(Color.esp.pink)
                .frame(width: markSize, height: markSize)
                .accessibilityHidden(true)
            Text(title)
                .espText(.title)
                .foregroundStyle(Color.esp.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A small label above a group of rows ("Artículos", "Totales del recibo").
public struct EspSectionHeader: View {
    private let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .espText(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(Color.esp.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The ESPLITÉALO wordmark in Unkempt Bold: ink letters and a pink acute on the É. Titles and the wordmark are the
/// only places Unkempt is used.
public struct EspWordmark: View {
    public init() {}

    private var text: AttributedString {
        var base = AttributedString("ESPLITE")
        base.foregroundColor = Color.esp.ink
        var acute = AttributedString("\u{0301}")
        acute.foregroundColor = Color.esp.pink
        var rest = AttributedString("ALO")
        rest.foregroundColor = Color.esp.ink
        return base + acute + rest
    }

    public var body: some View {
        Text(text)
            .espText(.wordmark)
            .tracking(0.5)
            .accessibilityLabel("Esplitéalo")
            .accessibilityAddTraits(.isHeader)
    }
}

import CoreText
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
/// only places Unkempt is used. The acute is drawn as its own pink mark over a plain E, because a text run cannot
/// colour half of one letter.
public struct EspWordmark: View {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = TypeStyle.wordmark.spec.size

    public init() {}

    /// Height of the strip above the capital letters, which is where the acute of the É lives.
    private var accentBand: CGFloat {
        let font = CTFontCreateWithName(UnkemptWeight.bold.postScriptName as CFString, size, nil)
        return CTFontGetAscent(font) - CTFontGetCapHeight(font)
    }

    public var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "ESPLIT")
            ZStack(alignment: .top) {
                Text(verbatim: "E")
                // The real É in pink, cut down to the strip above the capitals, so only its acute shows.
                Text(verbatim: "É")
                    .foregroundStyle(Color.esp.pink)
                    .mask(alignment: .top) { Rectangle().frame(height: accentBand) }
            }
            Text(verbatim: "ALO")
        }
        .espText(.wordmark)
        .tracking(0.5)
        .foregroundStyle(Color.esp.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Esplitéalo"))
        .accessibilityAddTraits(.isHeader)
    }
}

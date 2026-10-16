import SwiftUI

/// A person's colour, initial and (past eight people) a dotted ring. Colour is never the only signal:
/// the initial is inside, and chips also carry the name.
public struct PersonAvatar: View {
    private let name: String
    private let participantIndex: Int
    private let showsName: Bool
    @ScaledMetric private var scaledSize: CGFloat
    private let baseSize: CGFloat

    public init(name: String, participantIndex: Int, size: CGFloat = 28, announcesName: Bool = true) {
        self.name = name
        self.participantIndex = participantIndex
        self.showsName = announcesName
        baseSize = size
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    /// The circle grows with the text, but not past 1.75 times its size: at AX5 a 40 pt avatar would be 124 pt wide and
    /// leave no room for the name next to it.
    private var size: CGFloat { min(scaledSize, baseSize * 1.75) }

    public var body: some View {
        let slot = PersonColorSlot(participantIndex: participantIndex)
        Circle()
            .fill(slot.fillColor)
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: PersonInitial.make(from: name))
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(slot.letterColor)
                    .minimumScaleFactor(0.6)
            }
            .overlay {
                if PersonColorSlot.usesDottedRing(participantIndex: participantIndex) {
                    Circle()
                        .inset(by: -3)
                        .stroke(slot.fillColor, style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                }
            }
            .padding(PersonColorSlot.usesDottedRing(participantIndex: participantIndex) ? 3 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: name))
            .accessibilityHidden(!showsName)
    }
}

/// Avatar, name, and (optionally) the person's pre-tax subtotal, the way the assign screen lists people.
public struct PersonChip: View {
    private let name: String
    private let participantIndex: Int
    private let subtotalCents: Int?

    public init(name: String, participantIndex: Int, subtotalCents: Int? = nil) {
        self.name = name
        self.participantIndex = participantIndex
        self.subtotalCents = subtotalCents
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            PersonAvatar(name: name, participantIndex: participantIndex, size: 32, announcesName: false)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: name)
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
                if let subtotalCents {
                    MoneyText(cents: subtotalCents, style: .amount)
                        .foregroundStyle(Color.esp.ink)
                }
            }
        }
        .frame(minHeight: 56, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

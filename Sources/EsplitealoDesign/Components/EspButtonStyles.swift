import SwiftUI

/// The one raised "lip" button of a screen: green, 56 pt tall, a darker edge underneath, and optionally the pink ÷
/// on a round chip at the end (pink itself never sits on the green: 1.56:1).
public struct EspPrimaryButtonStyle: ButtonStyle {
    public var showsDivisionCoin: Bool
    @Environment(\.isEnabled) private var isEnabled

    public init(showsDivisionCoin: Bool = false) {
        self.showsDivisionCoin = showsDivisionCoin
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        configuration.label
            .espText(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.esp.onPrimary : Color.esp.inkSecondary)
            .padding(.horizontal, showsDivisionCoin && isEnabled ? 48 : Spacing.md)
            .padding(.vertical, Spacing.xs)
            .padding(.bottom, isEnabled ? Stroke.buttonLip : 0)
            .frame(maxWidth: .infinity, minHeight: TapTarget.primaryButtonHeight)
            .background(alignment: .top) {
                shape.fill(isEnabled ? Color.esp.primary : Color.esp.well)
                    .padding(.bottom, isEnabled ? Stroke.buttonLip : 0)
            }
            .background {
                shape.fill(isEnabled ? Color.esp.primaryLip : Color.esp.well)
            }
            .overlay {
                if !isEnabled {
                    shape.strokeBorder(Color.esp.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .overlay(alignment: .trailing) {
                if showsDivisionCoin && isEnabled {
                    DivisionCoin()
                        .padding(.trailing, 14)
                        .padding(.bottom, Stroke.buttonLip)
                }
            }
            .pressFeedback(configuration.isPressed)
            .contentShape(shape)
    }
}

/// The round chip with the pink ÷ that sits on the primary button.
struct DivisionCoin: View {
    var body: some View {
        Circle()
            .fill(Color.esp.onPrimary)
            .frame(width: 30, height: 30)
            .overlay {
                DivisionMark().fill(Color.esp.pink).frame(width: 16, height: 16)
            }
            .accessibilityHidden(true)
    }
}

/// A plain bordered button: surface fill, green label, 1.5 pt green border.
public struct EspSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        configuration.label
            .espText(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.esp.primary : Color.esp.inkSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: TapTarget.secondaryButtonHeight)
            .background(shape.fill(isEnabled ? Color.esp.surface : Color.esp.well))
            .overlay {
                shape.strokeBorder(
                    isEnabled ? Color.esp.primary : Color.esp.line,
                    style: StrokeStyle(lineWidth: 1.5, dash: isEnabled ? [] : [5, 4])
                )
            }
            .pressFeedback(configuration.isPressed)
            .contentShape(shape)
    }
}

/// Text-only button for cancel and back actions.
public struct EspQuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .espText(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.esp.primary : Color.esp.inkSecondary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
            .pressFeedback(configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Like the secondary button, in the warn colour (always paired with words or an icon).
public struct EspWarnButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        configuration.label
            .espText(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.esp.warn : Color.esp.inkSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: TapTarget.secondaryButtonHeight)
            .background(shape.fill(Color.esp.surface))
            .overlay { shape.strokeBorder(isEnabled ? Color.esp.warn : Color.esp.line, lineWidth: 1.5) }
            .pressFeedback(configuration.isPressed)
            .contentShape(shape)
    }
}

extension ButtonStyle where Self == EspPrimaryButtonStyle {
    public static var espPrimary: EspPrimaryButtonStyle { EspPrimaryButtonStyle() }
    public static func espPrimary(showsDivisionCoin: Bool) -> EspPrimaryButtonStyle {
        EspPrimaryButtonStyle(showsDivisionCoin: showsDivisionCoin)
    }
}

extension ButtonStyle where Self == EspSecondaryButtonStyle {
    public static var espSecondary: EspSecondaryButtonStyle { EspSecondaryButtonStyle() }
}

extension ButtonStyle where Self == EspQuietButtonStyle {
    public static var espQuiet: EspQuietButtonStyle { EspQuietButtonStyle() }
}

extension ButtonStyle where Self == EspWarnButtonStyle {
    public static var espWarn: EspWarnButtonStyle { EspWarnButtonStyle() }
}

extension View {
    /// Darkens to 80 % and shrinks to 97 % in 0.1 s while pressed.
    fileprivate func pressFeedback(_ pressed: Bool) -> some View {
        self
            .colorMultiply(pressed ? Color(white: PressFeedback.brightness) : .white)
            .scaleEffect(pressed ? PressFeedback.scale : 1)
            .animation(.easeOut(duration: PressFeedback.duration), value: pressed)
    }
}

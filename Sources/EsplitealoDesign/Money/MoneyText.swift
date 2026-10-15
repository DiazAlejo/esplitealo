import SwiftUI

/// An amount in dollars from integer cents. Always SF Pro Rounded with monospaced digits (never Unkempt), so
/// prices line up in columns; VoiceOver reads "12 dólares con 50 centavos" in the language of the environment.
public struct MoneyText: View {
    private let cents: Int
    private let style: TypeStyle
    @Environment(\.locale) private var locale

    public init(cents: Int, style: TypeStyle = .amount) {
        precondition(style.isMoney, "MoneyText only takes money styles")
        self.cents = cents
        self.style = style
    }

    public var body: some View {
        let formatter = MoneyFormatter(locale: locale)
        Text(verbatim: formatter.string(cents: cents))
            .espText(style)
            .accessibilityLabel(formatter.spokenString(cents: cents))
    }
}

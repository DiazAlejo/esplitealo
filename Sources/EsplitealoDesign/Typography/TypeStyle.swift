import Foundation

public enum TypeWeight: Sendable, Hashable {
    case regular, medium, semibold, bold
}

/// Mirrors `Font.TextStyle` without SwiftUI, so the scale is testable anywhere.
public enum DynamicTextStyle: Sendable, Hashable {
    case largeTitle, title, title2, headline, body, subheadline, footnote, caption
}

public enum UnkemptWeight: Sendable, Hashable {
    case regular, bold

    public var postScriptName: String {
        switch self {
        case .regular: "Unkempt-Regular"
        case .bold: "Unkempt-Bold"
        }
    }
}

public enum TypeFamily: Sendable, Hashable {
    case system
    case systemRounded
    case unkempt(UnkemptWeight)

    public var isUnkempt: Bool {
        if case .unkempt = self { true } else { false }
    }
}

public struct TypeSpec: Equatable, Sendable {
    public var size: Double
    public var weight: TypeWeight
    public var family: TypeFamily
    public var monospacedDigits: Bool
    public var textStyle: DynamicTextStyle
    /// Only the display amount may shrink, and only at the accessibility sizes. Everything else wraps.
    public var minimumScaleFactor: Double?
}

/// The type scale of `docs/DESIGN_GUIDE.md`, with the owner's font decision applied: Unkempt sets screen titles and
/// the ESPLITÉALO wordmark only; SF Pro Rounded with monospaced digits sets every amount (Unkempt has proportional
/// digits and no tabular figures); SF Pro sets everything else.
public enum TypeStyle: CaseIterable, Sendable, Hashable {
    case displayAmount, title, wordmark, amount, headline, body, subhead, footnote, caption

    public var isMoney: Bool { self == .displayAmount || self == .amount }

    public var spec: TypeSpec {
        switch self {
        case .displayAmount:
            TypeSpec(size: 40, weight: .semibold, family: .systemRounded, monospacedDigits: true, textStyle: .largeTitle, minimumScaleFactor: 0.7)
        case .title:
            TypeSpec(size: 26, weight: .regular, family: .unkempt(.regular), monospacedDigits: false, textStyle: .title, minimumScaleFactor: nil)
        case .wordmark:
            TypeSpec(size: 24, weight: .bold, family: .unkempt(.bold), monospacedDigits: false, textStyle: .title, minimumScaleFactor: nil)
        case .amount:
            TypeSpec(size: 22, weight: .medium, family: .systemRounded, monospacedDigits: true, textStyle: .title2, minimumScaleFactor: nil)
        case .headline:
            TypeSpec(size: 17, weight: .semibold, family: .system, monospacedDigits: false, textStyle: .headline, minimumScaleFactor: nil)
        case .body:
            TypeSpec(size: 17, weight: .regular, family: .system, monospacedDigits: false, textStyle: .body, minimumScaleFactor: nil)
        case .subhead:
            TypeSpec(size: 15, weight: .regular, family: .system, monospacedDigits: false, textStyle: .subheadline, minimumScaleFactor: nil)
        case .footnote:
            TypeSpec(size: 13, weight: .regular, family: .system, monospacedDigits: false, textStyle: .footnote, minimumScaleFactor: nil)
        case .caption:
            TypeSpec(size: 12, weight: .medium, family: .system, monospacedDigits: false, textStyle: .caption, minimumScaleFactor: nil)
        }
    }
}

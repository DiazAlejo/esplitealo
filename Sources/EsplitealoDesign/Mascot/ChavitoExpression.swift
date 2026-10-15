/// The four faces Chavito (the Esplitealo raccoon) can make, in the order the mockups list them.
public enum ChavitoExpression: String, CaseIterable, Sendable, Hashable {
    case neutral
    case happy
    case thinking
    case worried

    /// Pupil offset in art units: thinking glances up and right, worried down and left.
    public var defaultLook: ChavitoPoint {
        switch self {
        case .neutral, .happy: ChavitoPoint(x: 0, y: 0)
        case .thinking: ChavitoPoint(x: 3, y: -4)
        case .worried: ChavitoPoint(x: -2, y: 2)
        }
    }

    /// Happy squints (drawn as two arcs), so there is nothing to blink.
    public var hasOpenEyes: Bool { self != .happy }
}

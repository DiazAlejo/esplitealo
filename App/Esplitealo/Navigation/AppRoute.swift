import EsplitealoCore

/// The six screens of the flow in `docs/SCREENS.md`. Home is the root of the navigation stack; the others are
/// pushed on top of it in this order. Capture and Processing are one route: the capture screen shows processing,
/// failure and retry states itself.
enum AppRoute: String, Hashable, CaseIterable, Codable {
    case home, capture, review, people, mark, totals

    /// "Paso n de 5": capture and processing are step 1; Home has none.
    var step: Int? {
        switch self {
        case .home: nil
        case .capture: 1
        case .review: 2
        case .people: 3
        case .mark: 4
        case .totals: 5
        }
    }

    var next: AppRoute? {
        guard let index = Self.allCases.firstIndex(of: self), index + 1 < Self.allCases.count else { return nil }
        return Self.allCases[index + 1]
    }

    var previous: AppRoute? {
        guard let index = Self.allCases.firstIndex(of: self), index > 0 else { return nil }
        return Self.allCases[index - 1]
    }

    /// Key in `Localizable.xcstrings` of the screen's title.
    var titleKey: String {
        switch self {
        case .home: "home.scan"
        case .capture: "capture.title"
        case .review: "review.title"
        case .people: "people.title"
        case .mark: "assign.title"
        case .totals: "totals.title"
        }
    }

    /// Stable identifier of the screen's root view, for UI tests.
    var accessibilityIdentifier: String { "screen.\(rawValue)" }

    /// The screens to push on top of Home to put someone back where a saved bill left off.
    static func path(resuming session: BillSession) -> [AppRoute] {
        if session.participants.isEmpty { return [.review] }
        if session.unassignedUnits.isEmpty { return [.review, .people, .mark, .totals] }
        return [.review, .people, .mark]
    }
}

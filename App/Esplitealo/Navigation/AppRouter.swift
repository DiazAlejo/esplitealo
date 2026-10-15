import Observation

/// Owns the navigation path. Home is the root and is never in the path.
@MainActor @Observable
final class AppRouter {
    var path: [AppRoute] = []

    var current: AppRoute { path.last ?? .home }

    func push(_ route: AppRoute) {
        if route == .home {
            popToRoot()
        } else if route != current {
            path.append(route)
        }
    }

    /// Pushes the next screen of the flow. Does nothing on the last one.
    func advance() {
        guard let next = current.next else { return }
        push(next)
    }

    func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Replaces the whole path, for example when resuming a saved bill.
    func show(_ routes: [AppRoute]) {
        path = routes.filter { $0 != .home }
    }
}

import SwiftUI

/// The navigation shell: Home at the root, the other five screens pushed in order, and the "continue your bill?"
/// prompt when a saved draft is found at launch.
struct RootView: View {
    @Environment(BillStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .alert("resume.title", isPresented: resumePromptBinding) {
            Button("resume.continue") {
                store.resumeSavedDraft()
                if let session = store.session {
                    router.show(AppRoute.path(resuming: session))
                }
            }
            Button("resume.discard", role: .destructive) {
                store.discardSavedDraft()
            }
        } message: {
            Text("resume.message")
        }
        .task { store.loadSavedDraft() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { store.saveNow() }
        }
    }

    /// The prompt closes only through its two buttons.
    private var resumePromptBinding: Binding<Bool> {
        Binding(get: { store.resumeCandidate != nil }, set: { _ in })
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .home: HomeView()
        case .capture: CaptureView()
        case .review: ReviewView()
        case .people: PeopleView()
        case .mark: AssignView()
        case .totals: TotalsView()
        }
    }
}

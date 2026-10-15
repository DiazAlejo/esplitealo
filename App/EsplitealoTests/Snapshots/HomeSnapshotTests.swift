import SwiftUI
import Testing
@testable import Esplitealo

/// The Home screen with Chavito on his pink disc, in both appearances and languages and at the largest type size.
@MainActor
struct HomeSnapshotTests {
    @Test func home() {
        assertDesignSnapshot(
            NavigationStack { HomeView(animatesMascot: false) }
                .environment(AppRouter())
                .environment(ScanFlow.preview()),
            named: "home",
            fixedHeight: 844
        )
    }

    @Test func howItWorksSheet() {
        assertDesignSnapshot(
            HowItWorksSheet(onDone: {}),
            named: "how-it-works",
            fixedHeight: 700
        )
    }
}

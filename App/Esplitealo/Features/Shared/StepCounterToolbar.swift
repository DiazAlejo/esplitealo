import EsplitealoDesign
import SwiftUI

extension View {
    /// "Paso n de 5" in the middle of the navigation bar, in the bar's standard inline style. The back button stays
    /// the system's (so the swipe back keeps working).
    func stepCounterToolbar(for route: AppRoute) -> some View {
        navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let step = route.step {
                    ToolbarItem(placement: .principal) {
                        Text(.navStep(step))
                            .espText(.footnote)
                            .foregroundStyle(Color.esp.inkSecondary)
                    }
                }
            }
    }
}

import SwiftUI

struct TotalsView: View {
    var body: some View {
        PlaceholderScreen(route: .totals, nextKey: nil)
    }
}

#Preview {
    NavigationStack { TotalsView() }
        .environment(AppRouter())
}

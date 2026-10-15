import SwiftUI

struct ReviewView: View {
    var body: some View {
        PlaceholderScreen(route: .review, nextKey: "review.continue")
    }
}

#Preview {
    NavigationStack { ReviewView() }
        .environment(AppRouter())
}

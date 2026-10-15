import SwiftUI

struct AssignView: View {
    var body: some View {
        PlaceholderScreen(route: .mark, nextKey: "assign.button")
    }
}

#Preview {
    NavigationStack { AssignView() }
        .environment(AppRouter())
}

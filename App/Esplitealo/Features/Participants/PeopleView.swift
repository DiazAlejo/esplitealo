import SwiftUI

struct PeopleView: View {
    var body: some View {
        PlaceholderScreen(route: .people, nextKey: "people.next")
    }
}

#Preview {
    NavigationStack { PeopleView() }
        .environment(AppRouter())
}

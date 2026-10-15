import SwiftUI

struct CaptureView: View {
    var body: some View {
        PlaceholderScreen(route: .capture, nextKey: "capture.use")
    }
}

#Preview {
    NavigationStack { CaptureView() }
        .environment(AppRouter())
}

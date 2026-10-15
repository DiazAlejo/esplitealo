import EsplitealoDesign
import SwiftUI

/// Home: start a bill with one tap. Chavito and the recent-bills list come later.
struct HomeView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            EspWordmark()
            EspTitle("home.title")
            Text("home.subtitle")
                .espText(.body)
                .foregroundStyle(Color.esp.inkSecondary)
            Spacer(minLength: Spacing.md)
            VStack(spacing: Spacing.sm) {
                Button("home.scan") { router.push(.capture) }
                    .buttonStyle(.espPrimary(showsDivisionCoin: true))
                    .accessibilityIdentifier("home.scan")
                Button("home.photo") { router.push(.capture) }
                    .buttonStyle(.espSecondary)
                    .accessibilityIdentifier("home.photo")
                Text("home.privacy")
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .espScreenBackground()
        .navigationBarHidden(true)
        .accessibilityIdentifier(AppRoute.home.accessibilityIdentifier)
    }
}

#Preview("Home, Español") {
    NavigationStack { HomeView() }
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Home, English, dark") {
    NavigationStack { HomeView() }
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

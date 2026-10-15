import EsplitealoDesign
import SwiftUI

/// Home: Chavito on his pink disc, the pitch, and two buttons to start a bill. The recent-bills list comes later.
/// The content scrolls (large Dynamic Type), the buttons stay pinned at the bottom.
struct HomeView: View {
    /// Chavito blinks and bobs; snapshot tests turn that off. Reduce Motion turns it off too.
    var animatesMascot = true

    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                EspWordmark()
                ChavitoView(expression: .neutral, size: 220, disc: true, animated: animatesMascot)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("mascot.home")
                EspTitle("home.title")
                Text("home.subtitle")
                    .espText(.body)
                    .foregroundStyle(Color.esp.inkSecondary)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
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
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.sm)
            .background(Color.esp.paper)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
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

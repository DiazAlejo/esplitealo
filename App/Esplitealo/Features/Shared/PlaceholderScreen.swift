import EsplitealoDesign
import SwiftUI

/// What every screen shows until its own worker builds it: the title, the step, a note, and one button to the next
/// screen so the whole flow can be walked. Replace the body of the feature view; keep the screen identifier.
struct PlaceholderScreen: View {
    let route: AppRoute
    /// Key of the label on the button to the next screen.
    let nextKey: LocalizedStringKey?

    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            EspTitle(LocalizedStringKey(route.titleKey))
            EspCard {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("placeholder.title").espText(.headline)
                    Text("placeholder.body").espText(.subhead).foregroundStyle(Color.esp.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.md)
            if let nextKey {
                Button(nextKey) { router.advance() }
                    .buttonStyle(.espPrimary(showsDivisionCoin: true))
                    .accessibilityIdentifier("screen.next")
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .espScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let step = route.step {
                ToolbarItem(placement: .principal) {
                    Text(String(format: String(localized: "nav.step"), step))
                        .espText(.footnote)
                        .foregroundStyle(Color.esp.inkSecondary)
                }
            }
        }
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(route.accessibilityIdentifier)
    }
}

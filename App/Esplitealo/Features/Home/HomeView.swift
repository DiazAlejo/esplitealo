import EsplitealoDesign
import SwiftUI

/// Home: Chavito on his pink disc, the pitch, and two buttons to start a bill: scan with the document camera or
/// choose a photo. While a bill with content exists a "Continuar con tu cuenta" card offers to resume it (or abandon
/// it), and starting a scan asks before it would replace that bill. A saved bill from a previous launch is offered by
/// the shell's "¿Seguimos con tu cuenta?" prompt (see `RootView`), which sits on top of this screen. The recent-bills
/// list is optional in the first version and is not built.
/// The content scrolls (large Dynamic Type); the buttons stay pinned at the bottom, except at accessibility sizes.
struct HomeView: View {
    /// Chavito blinks and bobs; snapshot tests turn that off. Reduce Motion turns it off too.
    var animatesMascot = true

    @Environment(ScanFlow.self) private var flow
    @Environment(BillStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showsHowItWorks = false
    @State private var confirmsDiscard = false

    /// At accessibility sizes, and in landscape, the buttons would take half the screen if they stayed pinned, so they
    /// scroll with the page.
    private var pinsActions: Bool {
        ChromePolicy.pinsExtraActions(dynamicTypeSize: dynamicTypeSize, verticalSizeClass: verticalSizeClass)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AdaptiveStack(rowSpacing: Spacing.xs, stackedSpacing: Spacing.xs) {
                    EspWordmark().frame(maxWidth: .infinity, alignment: .leading)
                    howItWorksButton
                }
                if let bill = store.billInProgress {
                    ResumeBillCard(
                        bill: bill,
                        onContinue: { router.show(bill.resumePath) },
                        onDiscard: { confirmsDiscard = true }
                    )
                }
                VStack(spacing: Spacing.sm) {
                    ChavitoView(expression: .neutral, size: 220, disc: true, animated: animatesMascot)
                        .accessibilityLabel("mascot.home")
                    SpeechBubble("home.bubble")
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    EspTitle("home.title")
                    Text("home.subtitle")
                        .espText(.body)
                        .foregroundStyle(Color.esp.inkSecondary)
                }
                if !pinsActions { actions }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if pinsActions {
                actions
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.esp.paper)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsHowItWorks) {
            HowItWorksSheet { showsHowItWorks = false }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .discardBillConfirmation(isPresented: $confirmsDiscard) { store.finishBill() }
        .alert("bill.replace.title", isPresented: replacementBinding) {
            Button("bill.replace.continue", role: .cancel) { flow.keepCurrentBill() }
            Button("bill.replace.start", role: .destructive) { flow.confirmReplacement() }
        } message: {
            Text("bill.replace.message")
        }
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppRoute.home.accessibilityIdentifier)
    }

    /// The question closes only through its two buttons.
    private var replacementBinding: Binding<Bool> {
        Binding(get: { flow.pendingReplacement != nil }, set: { _ in })
    }

    private var howItWorksButton: some View {
        Button { showsHowItWorks = true } label: {
            Label("home.how", systemImage: "questionmark.circle")
                .espText(.subhead)
                .foregroundStyle(Color.esp.primary)
                // The frame is inside the label: a frame around the button is not part of what can be tapped.
                .frame(minHeight: TapTarget.minimum)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("home.how")
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            Button { flow.open(.camera) } label: { Label("home.scan", systemImage: "camera.fill") }
                .buttonStyle(.espPrimary(showsDivisionCoin: true))
                .accessibilityIdentifier("home.scan")
            Button { flow.open(.photoLibrary) } label: { Label("home.photo", systemImage: "photo") }
                .buttonStyle(.espSecondary)
                .accessibilityIdentifier("home.photo")
            Label("home.privacy", systemImage: "lock.fill")
                .espText(.footnote)
                .foregroundStyle(Color.esp.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Chavito's line under him: a surface-coloured bubble with a small tail pointing up at him.
private struct SpeechBubble: View {
    private let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .espText(.subhead)
            .fontWeight(.semibold)
            .foregroundStyle(Color.esp.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.md - 2)
            .padding(.vertical, Spacing.xs - 1)
            .padding(.top, BubbleShape.tailHeight)
            .background {
                BubbleShape().fill(Color.esp.surface)
                BubbleShape().stroke(Color.esp.line, lineWidth: 1.5)
            }
            .frame(maxWidth: 300)
            .accessibilityElement(children: .combine)
    }
}

/// A rounded rectangle with a small notch pointing up from the middle of its top edge.
private struct BubbleShape: Shape {
    static let tailHeight: CGFloat = 7
    private let tailHalfWidth: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY + Self.tailHeight, width: rect.width, height: rect.height - Self.tailHeight)
        let radius = min(Radius.card, body.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        path.addLine(to: CGPoint(x: rect.midX - tailHalfWidth, y: body.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + tailHalfWidth, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        path.addArc(center: CGPoint(x: body.maxX - radius, y: body.minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
        path.addArc(center: CGPoint(x: body.maxX - radius, y: body.maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
        path.addArc(center: CGPoint(x: body.minX + radius, y: body.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        path.addArc(center: CGPoint(x: body.minX + radius, y: body.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Home, Español") {
    NavigationStack { HomeView() }
        .environment(AppRouter())
        .environment(BillStore.live(arguments: ["--uitesting"]))
        .environment(ScanFlow.preview())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Home, English, dark") {
    NavigationStack { HomeView() }
        .environment(AppRouter())
        .environment(BillStore.live(arguments: ["--uitesting"]))
        .environment(ScanFlow.preview())
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}
#endif

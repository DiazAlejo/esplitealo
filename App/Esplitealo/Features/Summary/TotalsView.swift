import EsplitealoCore
import EsplitealoDesign
import SwiftUI

/// Totals and share (step 5): how the tip is set, who owes what, where the stray cents went, and the one green button
/// that opens the share preview. Sharing is blocked while items are unmarked or the receipt does not add up.
struct TotalsView: View {
    @Environment(BillStore.self) private var store

    var body: some View {
        TotalsScreen(store: store)
    }
}

private struct TotalsScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: TotalsViewModel
    /// The success moment waits for the share preview to finish closing, so two presentations never overlap.
    @State private var showsSuccess = false

    init(store: BillStore) {
        _model = State(initialValue: TotalsViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                EspTitle("totals.title")
                TotalsStatusBanner(status: model.status)
                TipSettings(model: model)
                TotalsSummary(summary: model.summary)
                WhoOwesSection(rows: model.rows, showsService: model.summary.showsService)
                if model.hasRounding {
                    RoundingCard(notes: model.roundingNotes)
                }
                if dynamicTypeSize.isAccessibilitySize {
                    editButtons
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { footer }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        .stepCounterToolbar(for: .totals)
        .sensoryFeedback(.success, trigger: model.hasShared) { _, shared in shared }
        .sheet(isPresented: Binding(get: { model.isSharing }, set: { if !$0 { model.dismissShare() } }), onDismiss: {
            if model.hasShared { showsSuccess = true }
        }) {
            ShareSheetContent(model: model, onCancel: { model.dismissShare() })
        }
        .fullScreenCover(isPresented: $showsSuccess) {
            ShareSuccessView(
                peopleCount: model.sharedPeopleCount,
                totalCents: model.sharedTotalCents,
                onNewBill: {
                    model.startNewBill()
                    router.popToRoot()
                },
                onBack: {
                    model.dismissSuccess()
                    showsSuccess = false
                }
            )
            .espScreenBackground()
        }
        .onChange(of: model.canShare) { model.closeShareIfBlocked() }
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppRoute.totals.accessibilityIdentifier)
    }

    // MARK: Bottom bar

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                model.requestShare()
            } label: {
                Label("totals.share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.espPrimary(showsDivisionCoin: false))
            .disabled(!model.canShare)
            .accessibilityHint(model.canShare ? Text(verbatim: "") : Text("totals.blocked"))
            .accessibilityIdentifier("totals.share")

            if !model.canShare {
                Label {
                    Text("totals.blocked")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                }
                .espText(.footnote)
                .foregroundStyle(Color.esp.warn)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("totals.blocked")
            }

            if !dynamicTypeSize.isAccessibilitySize {
                editButtons
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, Spacing.sm)
        .background(Color.esp.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.esp.line).frame(height: Stroke.hairline).accessibilityHidden(true)
        }
    }

    private var editButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) { editAssignments; editReceipt }
            VStack(spacing: 0) { editAssignments; editReceipt }
        }
    }

    private var editAssignments: some View {
        Button("totals.editAssign") { router.back() }
            .buttonStyle(.espQuiet)
            .accessibilityIdentifier("totals.editAssign")
    }

    /// Back to the receipt: the screens in between are popped, and continuing walks the flow forward again.
    private var editReceipt: some View {
        Button("totals.editReceipt") { router.show([.review]) }
            .buttonStyle(.espQuiet)
            .accessibilityIdentifier("totals.editReceipt")
    }
}

#Preview("Totals, Español") {
    NavigationStack { TotalsView() }
        .environment(previewStore(SampleBill.complete()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Totals, English, dark") {
    NavigationStack { TotalsView() }
        .environment(previewStore(SampleBill.complete()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

#Preview("Totals, receipt mismatch") {
    NavigationStack { TotalsView() }
        .environment(previewStore(TotalsSamples.mismatch()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Totals, service charge") {
    NavigationStack { TotalsView() }
        .environment(previewStore(TotalsSamples.serviceCharge()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

@MainActor
private func previewStore(_ session: BillSession) -> BillStore {
    let store = BillStore(draftStore: FileBillDraftStore(directory: DraftLocation.temporaryDirectory()))
    store.startNewBill(draft: session.draft)
    store.update { $0 = session }
    return store
}

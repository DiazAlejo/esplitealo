import EsplitealoCore
import EsplitealoDesign
import SwiftUI

/// Review receipt (step 2): the items the scan found, each one editable, the amounts printed at the bottom, and the
/// result of checking that they add up, shown again after every edit. Rows the parser flagged are called out and never
/// dropped. The printed total is never changed to match the items; a receipt that does not add up can be continued
/// only after an explicit confirmation, and sharing stays blocked until it adds up.
struct ReviewView: View {
    @Environment(BillStore.self) private var store

    var body: some View {
        ReviewScreen(store: store)
    }
}

private struct ReviewScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var model: ReceiptReviewModel
    @State private var sheet: ReviewSheet?

    init(store: BillStore) {
        _model = State(initialValue: ReceiptReviewModel(store: store))
    }

    private enum ReviewSheet: Identifiable {
        case item(UUID?)
        case amount(ReceiptField)
        case confirm(differenceCents: Int?)

        var id: String {
            switch self {
            case let .item(id): "item-\(id?.uuidString ?? "new")"
            case let .amount(field): "amount-\(field.rawValue)"
            case .confirm: "confirm"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    EspTitle("review.title")
                    Text("review.subtitle")
                        .espText(.body)
                        .foregroundStyle(Color.esp.inkSecondary)
                }

                ReviewBanner(status: model.status, model: model)

                items
                adjustments

                Button {
                    sheet = .item(nil)
                } label: {
                    Label("review.add", systemImage: "plus")
                }
                .buttonStyle(.espSecondary)
                .accessibilityIdentifier("review.add")

                amounts

                if !pinsContinue { continueButton.padding(.top, Spacing.xs) }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if pinsContinue {
                continueButton
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.esp.paper)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        // The step counter is in the bar; the title is what the next screen's back button says.
        .navigationTitle("people.back")
        .stepCounterToolbar(for: .review)
        .onAppear { model.startBillIfNeeded() }
        .onChange(of: model.status) { _, status in announce(status) }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .item(id):
                ItemEditorSheet(model: model, itemID: id) { self.sheet = nil }
            case let .amount(field):
                AmountEditorSheet(model: model, field: field) { self.sheet = nil }
            case let .confirm(differenceCents):
                MismatchConfirmationSheet(differenceCents: differenceCents) {
                    self.sheet = nil
                } onContinue: {
                    model.confirmMismatch()
                    self.sheet = nil
                    router.advance()
                }
            }
        }
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppRoute.review.accessibilityIdentifier)
    }

    /// At the two largest text sizes the button would cover half the screen, so it scrolls with the page.
    private var pinsContinue: Bool {
        ChromePolicy.pinsActionBar(dynamicTypeSize: dynamicTypeSize, verticalSizeClass: verticalSizeClass)
    }

    private var continueButton: some View {
        Button("review.continue", action: continueTapped)
            .buttonStyle(.espPrimary(showsDivisionCoin: true))
            .disabled(!model.canContinue)
            .accessibilityHint(model.canContinue ? Text(verbatim: "") : Text("review.needOne"))
            .accessibilityIdentifier("screen.next")
    }

    // MARK: Sections

    @ViewBuilder
    private var items: some View {
        if model.items.isEmpty {
            ReviewEmptyCard()
        } else {
            let flagged = model.flaggedItems
            if !flagged.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ReviewSectionHeader(title: "review.needsLook", count: flagged.count, isWarning: true)
                    RowsCard(flagged, style: .warn) { row in
                        ReviewItemRow(row: row) { sheet = .item(row.id) }
                    }
                }
            }
            let plain = model.plainItems
            if !plain.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ReviewSectionHeader(title: "review.items", count: plain.count)
                    RowsCard(plain) { row in
                        ReviewItemRow(row: row) { sheet = .item(row.id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var adjustments: some View {
        let rows = model.adjustments
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ReviewSectionHeader(title: "review.adjustments")
                RowsCard(rows) { row in
                    ReviewAdjustmentRow(row: row) { model.removeAdjustment(at: row.id) }
                }
                Text("review.adjustments.note")
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
            }
        }
    }

    private var amounts: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ReviewSectionHeader(title: "review.amounts")
            RowsCard(model.showsServiceRow ? ReceiptField.allCases : ReceiptField.allCases.filter { $0 != .service }, style: .well) { field in
                ReviewFieldRow(field: field, model: model) { sheet = .amount(field) }
            }
            if !model.showsServiceRow {
                Button("review.addService") { sheet = .amount(.service) }
                    .buttonStyle(.espQuiet)
                    .accessibilityIdentifier("review.addService")
            }
        }
    }

    // MARK: Actions

    private func continueTapped() {
        switch model.requestContinue() {
        case .noItems:
            break
        case .proceed:
            router.advance()
        case let .confirmMismatch(differenceCents):
            sheet = .confirm(differenceCents: differenceCents)
        }
    }

    /// VoiceOver hears the new result after an edit, because nothing moves on screen.
    private func announce(_ status: ReceiptReviewModel.Status) {
        AccessibilityAnnouncements.post(AccessibilityAnnouncements.reviewResult(status, locale: locale))
    }
}

#Preview("Review, mismatch, Español") {
    NavigationStack { ReviewView() }
        .environment(previewStore(ReviewSamples.parsedSession()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Review, balanced, English, dark") {
    NavigationStack { ReviewView() }
        .environment(previewStore(SampleBill.scanned()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

#Preview("Review, empty") {
    NavigationStack { ReviewView() }
        .environment(previewStore(nil))
        .environment(AppRouter())
}

@MainActor
private func previewStore(_ session: BillSession?) -> BillStore {
    let store = BillStore(draftStore: FileBillDraftStore(directory: DraftLocation.temporaryDirectory()))
    store.startNewBill(draft: session?.draft ?? ReceiptDraft())
    if let session { store.update { $0 = session } }
    return store
}

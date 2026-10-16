import EsplitealoCore
import EsplitealoDesign
import SwiftUI

/// Mark items (step 4): tap an item and choose who had it. One person gets the whole item; several split it equally.
/// A line of several units (3 Medallas) is marked unit by unit. The chips on top carry each person's live pre-tax
/// subtotal; tapping a chip paints items for that person. Review split stays tappable with items left: it names what
/// is missing and offers "split the rest evenly" in one tap.
struct AssignView: View {
    @Environment(BillStore.self) private var store

    var body: some View {
        AssignScreen(model: AssignViewModel(store: store))
    }
}

struct AssignScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var model: AssignViewModel
    @State private var shakes: CGFloat = 0
    @State private var warnings = 0

    init(model: AssignViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        let rows = model.rows
        let people = model.people
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if !pinsHeader {
                        AssignHeader(model: model, people: people)
                    }
                    if !pinsExtra {
                        // The bottom bar keeps only the button at the largest sizes, so the list has room.
                        leftLine.padding(.horizontal, Spacing.screenMargin)
                    }
                    if model.showsWarning {
                        AssignWarningBanner(count: model.unassignedUnitCount, onSplitRest: { model.splitRestEvenly() })
                            .padding(.horizontal, Spacing.screenMargin)
                    }
                    list(rows)
                    if !pinsBar { bottomBar(rows: rows, proxy: proxy) }
                    if model.paintingID == nil {
                        Text("assign.footer")
                            .espText(.footnote)
                            .foregroundStyle(Color.esp.inkSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.xs)
                    }
                }
                .padding(.vertical, Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .top, spacing: 0) {
                if pinsHeader {
                    AssignHeader(model: model, people: people)
                        .background(Color.esp.paper)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pinsBar { bottomBar(rows: rows, proxy: proxy) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        // The step counter is in the bar; the title is what the next screen's back button says.
        .navigationTitle("totals.back")
        .stepCounterToolbar(for: .mark)
        .animation(reduceMotion ? nil : .snappy, value: rows)
        .sensoryFeedback(.selection, trigger: people.map(\.subtotalCents))
        .sensoryFeedback(.warning, trigger: warnings)
        .onChange(of: model.showsWarning) { _, shows in
            if shows { AccessibilityNotification.Announcement(String(resolving: .assignWarnTitle(model.unassignedUnitCount), in: locale)).post() }
        }
        .sheet(item: Binding(get: { model.sheet }, set: { if $0 == nil { model.closeSheet() } })) { _ in
            AssignSheet(model: model)
        }
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppRoute.mark.accessibilityIdentifier)
    }

    // MARK: Pinned bars

    private var pinsHeader: Bool { ChromePolicy.pinsHeader(dynamicTypeSize: dynamicTypeSize, verticalSizeClass: verticalSizeClass) }
    private var pinsExtra: Bool { ChromePolicy.pinsExtraActions(dynamicTypeSize: dynamicTypeSize, verticalSizeClass: verticalSizeClass) }
    private var pinsBar: Bool { ChromePolicy.pinsActionBar(dynamicTypeSize: dynamicTypeSize, verticalSizeClass: verticalSizeClass) }

    // MARK: Parts

    private func list(_ rows: [AssignViewModel.Row]) -> some View {
        let table = model.people
        return VStack(spacing: 0) {
            ForEach(rows) { row in
                AssignItemRow(
                    row: row,
                    table: table,
                    highlightsUnassigned: model.showsWarning,
                    isSelected: model.sheet?.itemID == row.id,
                    actions: model.actions(for: row.id),
                    onTap: { model.tapRow(row.id) },
                    onAction: { perform($0, on: row, table: table) }
                )
                .id(row.id)
                if row.id != rows.last?.id {
                    Rectangle()
                        .fill(Color.esp.hairline)
                        .frame(height: Stroke.hairline)
                        .padding(.horizontal, Spacing.sm)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, Spacing.xs)
    }

    private func bottomBar(rows: [AssignViewModel.Row], proxy: ScrollViewProxy) -> some View {
        let left = model.unassignedUnitCount
        return VStack(spacing: Spacing.xs) {
            if pinsExtra { leftLine }

            Button {
                reviewSplit(rows: rows, proxy: proxy)
            } label: {
                if left == 0 { Text("assign.button") } else { Text(.assignButtonLeft(left)) }
            }
            .buttonStyle(.espPrimary(showsDivisionCoin: true))
            .modifier(ShakeEffect(shakes: shakes))
            .accessibilityIdentifier("screen.next")
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
        .background(Color.esp.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.esp.line).frame(height: Stroke.hairline).accessibilityHidden(true)
        }
    }

    /// What is still unassigned, or that everything is marked.
    private var leftLine: some View {
        Group {
            if model.unassignedUnitCount == 0 {
                Label {
                    Text(.assignAllDone(model.totalUnitCount))
                } icon: {
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.primary)
            } else {
                Text(.assignLeft(MoneyFormatter(locale: locale).string(cents: model.unassignedCents), model.unassignedUnitCount))
                    .foregroundStyle(Color.esp.inkSecondary)
            }
        }
        .espText(.footnote)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("assign.left")
    }

    // MARK: Actions

    private func reviewSplit(rows: [AssignViewModel.Row], proxy: ScrollViewProxy) {
        switch model.reviewSplit() {
        case .proceed:
            router.advance()
        case .blocked:
            warnings += 1
            if !reduceMotion { withAnimation(.linear(duration: 0.32)) { shakes += 1 } }
            if let first = rows.first(where: { $0.state != .assigned }) {
                withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(first.id, anchor: .center) }
            }
        }
    }

    /// A VoiceOver action on a row: the change is made, then said, because the row itself is not read again.
    private func perform(_ action: AssignViewModel.RowAction, on row: AssignViewModel.Row, table: [AssignViewModel.Person]) {
        model.perform(action, on: row.id)
        func name(of id: UUID) -> String { table.first { $0.id == id }?.name ?? "" }
        let spoken: String = switch action {
        case let .mark(id): String(resolving: .assignAnnounceMarked(name(of: id)), in: locale)
        case let .unmark(id): String(resolving: .assignAnnounceUnmarked(name(of: id)), in: locale)
        case .markEveryone: String(resolving: .assignAnnounceEveryone, in: locale)
        case .clear: String(resolving: .assignUnassigned, in: locale)
        }
        AccessibilityNotification.Announcement(spoken).post()
    }
}

/// A short side-to-side shake: Review split refusing to move on.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * 2 * .pi * 2), y: 0))
    }
}

#Preview("Marcar, a medias, Español") {
    NavigationStack { AssignView() }
        .environment(previewStore(SampleBill.midway()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Assign, nothing marked, English, dark") {
    NavigationStack { AssignView() }
        .environment(previewStore(AssignSamples.table()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

#Preview("Marcar, cantidades") {
    NavigationStack { AssignView() }
        .environment(previewStore(AssignSamples.quantities()))
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

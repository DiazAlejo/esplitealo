import EsplitealoCore
import EsplitealoDesign
import SwiftUI

/// Add people (step 3): type the names of the people at the table. No accounts, no contacts. Each person gets the
/// next person colour; renaming keeps their items; removing someone who has items marked says what will happen first.
/// At least one person is needed to continue.
struct PeopleView: View {
    @Environment(BillStore.self) private var store

    var body: some View {
        PeopleScreen(store: store)
    }
}

private struct PeopleScreen: View {
    @Environment(AppRouter.self) private var router
    @State private var model: PeopleViewModel
    @FocusState private var nameFocused: Bool

    init(store: BillStore) {
        _model = State(initialValue: PeopleViewModel(store: store))
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    EspTitle("people.title")
                    Text("people.subtitle")
                        .espText(.body)
                        .foregroundStyle(Color.esp.inkSecondary)
                }

                addPersonRow(name: $model.nameDraft)

                if let message = model.message {
                    Label {
                        message.text
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    }
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.warn)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("people.message")
                }

                if model.rows.isEmpty {
                    PeopleEmptyState()
                } else {
                    table
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button("people.next") { router.advance() }
                .buttonStyle(.espPrimary(showsDivisionCoin: true))
                .disabled(!model.canContinue)
                .accessibilityHint(model.canContinue ? Text(verbatim: "") : Text("people.needOne"))
                .accessibilityIdentifier("screen.next")
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.sm)
                .background(Color.esp.paper)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .espScreenBackground()
        // The step counter is in the bar; the title is what the next screen's back button says.
        .navigationTitle("assign.back")
        .stepCounterToolbar(for: .people)
        .onAppear { model.startBillIfNeeded() }
        .onChange(of: model.message) { _, message in
            if let message { AccessibilityNotification.Announcement(message.spokenText).post() }
        }
        .sheet(item: Binding(get: { model.renaming }, set: { if $0 == nil { model.cancelRename() } })) { _ in
            RenameSheet(model: model)
        }
        .sheet(item: Binding(get: { model.pendingRemoval }, set: { if $0 == nil { model.cancelRemoval() } })) { removal in
            RemovePersonSheet(removal: removal, onKeep: { model.cancelRemoval() }, onRemove: { model.confirmRemoval() })
        }
        // `.contain` keeps the children's own identifiers; a bare identifier here would replace them.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppRoute.people.accessibilityIdentifier)
    }

    // MARK: Parts

    private func addPersonRow(name: Binding<String>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.xs) {
                nameField(name)
                addButton.fixedSize(horizontal: true, vertical: false)
            }
            VStack(spacing: Spacing.xs) {
                nameField(name)
                addButton
            }
        }
    }

    private func nameField(_ name: Binding<String>) -> some View {
        TextField(text: name, prompt: Text("people.placeholder")) { Text("people.placeholder") }
            .focused($nameFocused)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit(addPerson)
            .espText(.body)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: TapTarget.secondaryButtonHeight)
            .background(Color.esp.well, in: RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous))
            .accessibilityIdentifier("people.name")
    }

    private var addButton: some View {
        Button(action: addPerson) {
            Label("people.add", systemImage: "plus")
        }
        .buttonStyle(.espSecondary)
        .accessibilityIdentifier("people.add")
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(.peopleAtTable(model.rows.count))
                .espText(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            RowsCard(model.rows) { row in
                PersonRow(
                    row: row,
                    onRename: { model.beginRename(id: row.id) },
                    onRemove: { model.requestRemoval(id: row.id) }
                )
            }
        }
    }

    private func addPerson() {
        model.addPerson()
        // Stay in the field so the next name can be typed straight away.
        nameFocused = true
    }
}

extension PeopleViewModel.Message {
    var text: Text {
        switch self {
        case .nameMissing: Text("people.errName")
        case let .duplicate(name): Text(.peopleErrDup(name))
        case .lastPerson: Text("people.errLast")
        }
    }

    /// The same words as plain text, for the VoiceOver announcement.
    var spokenText: String {
        switch self {
        case .nameMissing: String(localized: .peopleErrName)
        case let .duplicate(name): String(localized: .peopleErrDup(name))
        case .lastPerson: String(localized: .peopleErrLast)
        }
    }
}

/// A person at the table: their colour and initial, how many items are marked for them, and Rename / Remove.
private struct PersonRow: View {
    let row: PeopleViewModel.Row
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) {
                who
                rename
                remove
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                who
                HStack(spacing: Spacing.xs) {
                    rename
                    remove
                }
            }
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    private var who: some View {
        HStack(spacing: Spacing.sm) {
            PersonAvatar(name: row.name, participantIndex: row.colorIndex, size: 40, announcesName: false)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: row.name)
                    .espText(.headline)
                    .multilineTextAlignment(.leading)
                if row.assignedItemCount > 0 {
                    Text(.peopleAssigned(row.assignedItemCount))
                        .espText(.footnote)
                        .foregroundStyle(Color.esp.inkSecondary)
                } else {
                    Text("people.none")
                        .espText(.footnote)
                        .foregroundStyle(Color.esp.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("people.row.\(row.colorIndex)")
    }

    private var rename: some View {
        Button(action: onRename) {
            Text("people.rename")
                .espText(.subhead)
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.primary)
                .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(.peopleRenameLabel(row.name)))
        .accessibilityIdentifier("people.rename.\(row.colorIndex)")
    }

    private var remove: some View {
        Button(action: onRemove) {
            Text("people.remove")
                .espText(.subhead)
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.warn)
                .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(.peopleRemoveLabel(row.name)))
        .accessibilityIdentifier("people.remove.\(row.colorIndex)")
    }
}

/// An empty table: Chavito on his pink disc over four empty places, and what to do next.
struct PeopleEmptyState: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ChavitoView(expression: .neutral, size: 220, disc: true, animated: false)
                .accessibilityLabel("mascot.empty")
            HStack(spacing: Spacing.sm) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    Circle()
                        .strokeBorder(Color.esp.inkSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.esp.inkSecondary)
                        }
                }
            }
            .accessibilityHidden(true)
            Text("people.empty.title")
                .espText(.title)
                .multilineTextAlignment(.center)
            Text("people.empty.body")
                .espText(.subhead)
                .foregroundStyle(Color.esp.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("people.empty")
    }
}

#Preview("People, four friends, Español") {
    NavigationStack { PeopleView() }
        .environment(previewStore(SampleBill.midway()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("People, empty, English, dark") {
    NavigationStack { PeopleView() }
        .environment(previewStore(SampleBill.scanned()))
        .environment(AppRouter())
        .environment(\.locale, Locale(identifier: "en"))
        .preferredColorScheme(.dark)
}

@MainActor
private func previewStore(_ session: BillSession) -> BillStore {
    let store = BillStore(draftStore: FileBillDraftStore(directory: DraftLocation.temporaryDirectory()))
    store.startNewBill(draft: session.draft)
    store.update { $0 = session }
    return store
}

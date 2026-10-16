import EsplitealoDesign
import SwiftUI

/// Change a person's name. Their colour and their items stay.
struct RenameSheet: View {
    @Bindable var model: PeopleViewModel
    @FocusState private var focused: Bool

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SheetTitle("sheet.rename")

                SheetField("sheet.name", error: model.renameMessage?.text) {
                    TextField(text: $model.renameDraft, prompt: Text("sheet.name").foregroundStyle(Color.esp.inkSecondary)) { Text("sheet.name") }
                        .focused($focused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { model.commitRename() }
                        .accessibilityIdentifier("people.rename.field")
                }

                Button("sheet.save") { model.commitRename() }
                    .buttonStyle(.espPrimary)
                    .accessibilityIdentifier("sheet.save")

                Button("sheet.cancel") { model.cancelRename() }
                    .buttonStyle(.espQuiet)
                    .accessibilityIdentifier("sheet.cancel")
            }
        }
        .onAppear { focused = true }
    }
}

/// Removing someone who has items marked: what happens to those items, and a choice. Nothing is erased silently.
struct RemovePersonSheet: View {
    let removal: PeopleViewModel.Removal
    let onKeep: () -> Void
    let onRemove: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SheetTitle(resource: .peopleRemoveTitle(removal.name))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(.peopleRemoveHad(removal.assignedItemCount, removal.name))
                    if !removal.orphanedItemNames.isEmpty {
                        let names = removal.orphanedItemNames.formatted(.list(type: .and).locale(locale))
                        Text(removal.orphanedItemNames.count == 1 ? .peopleRemoveOrphansOne(names) : .peopleRemoveOrphansMany(names))
                    }
                    if removal.sharedItemsRemain {
                        Text("people.remove.shared")
                    }
                }
                .espText(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("people.remove.body")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.sm) {
                        keep.frame(maxWidth: .infinity)
                        remove.frame(maxWidth: .infinity)
                    }
                    VStack(spacing: Spacing.xs) {
                        keep
                        remove
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
    }

    private var keep: some View {
        Button(action: onKeep) { Text(.peopleKeep(removal.name)) }
            .buttonStyle(.espPrimary)
            .accessibilityIdentifier("people.remove.keep")
    }

    private var remove: some View {
        Button("people.remove", action: onRemove)
            .buttonStyle(.espWarn)
            .accessibilityIdentifier("people.remove.confirm")
    }
}

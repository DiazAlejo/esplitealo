import EsplitealoDesign
import SwiftUI

/// "¿Quién pidió esto?": the people at the table with a mark for each, and what each pays of the item. Marking
/// changes the bill at once (the chips behind the sheet move), so Done only closes. A line of several units has a
/// picker: all units together, or one unit at a time.
struct AssignSheet: View {
    let model: AssignViewModel

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var checkSize: CGFloat = 22

    var body: some View {
        FittedSheet {
            if let content = model.sheetContent, let itemID = model.sheet?.itemID {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    header(content)
                    if content.unitCount > 1 { unitPicker(content) }
                    who(content, itemID: itemID)
                    VStack(spacing: Spacing.xxs) {
                        ForEach(content.people) { person in
                            personRow(person, itemID: itemID, scope: content.scope)
                        }
                    }
                    note(content.note, content: content)
                        .espText(.footnote)
                        .foregroundStyle(Color.esp.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("assign.sheet.note")
                    Button("assign.done") { model.closeSheet() }
                        .buttonStyle(.espPrimary)
                        .accessibilityIdentifier("assign.sheet.done")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("assign.sheet")
                .accessibilityLabel(Text(.assignSheetLabel(content.itemName)))
            }
        }
    }

    // MARK: Parts

    private func header(_ content: AssignViewModel.SheetContent) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                title(content.itemName)
                Spacer(minLength: Spacing.xs)
                MoneyText(cents: content.totalCents, style: .amount)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title(content.itemName)
                MoneyText(cents: content.totalCents, style: .amount)
            }
        }
    }

    private func title(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func who(_ content: AssignViewModel.SheetContent, itemID: UUID) -> some View {
        HStack {
            Text("assign.who")
                .espText(.subhead)
                .foregroundStyle(Color.esp.inkSecondary)
            Spacer(minLength: Spacing.xs)
            Button(content.everyoneSelected ? "assign.clear" : "assign.everyone") {
                model.toggleEveryone(on: itemID, scope: content.scope)
            }
            .espText(.subhead)
            .fontWeight(.semibold)
            .foregroundStyle(Color.esp.primary)
            .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum, alignment: .trailing)
            .accessibilityIdentifier("assign.sheet.everyone")
        }
    }

    private func unitPicker(_ content: AssignViewModel.SheetContent) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                pill(Text("assign.unit.all"), scope: .all, current: content.scope, identifier: "assign.sheet.unit.all")
                    .accessibilityLabel(Text("assign.unit.allLabel"))
                ForEach(0 ..< content.unitCount, id: \.self) { index in
                    pill(Text(.assignUnitN(index + 1)), scope: .unit(index), current: content.scope, identifier: "assign.sheet.unit.\(index + 1)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func pill(_ label: Text, scope: AssignScope, current: AssignScope, identifier: String) -> some View {
        let selected = scope == current
        return Button {
            model.selectScope(scope)
        } label: {
            label
                .espText(.subhead)
                .fontWeight(.semibold)
                .foregroundStyle(selected ? Color.esp.onPrimary : Color.esp.ink)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: TapTarget.minimum)
                .background(selected ? Color.esp.primary : Color.esp.well, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func personRow(_ person: AssignViewModel.SheetPerson, itemID: UUID, scope: AssignScope) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let money = MoneyFormatter(locale: locale)
        return Button {
            model.toggle(person.id, on: itemID, scope: scope)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // Narrow columns would break the name and the amount: the amount goes under the name.
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        checkmark(person.mark)
                        PersonAvatar(name: person.name, participantIndex: person.colorIndex, size: 40, announcesName: false)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(verbatim: person.name).espText(.headline).multilineTextAlignment(.leading)
                            trailing(person, units: model.sheetContent?.unitCount ?? 1, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(spacing: Spacing.sm) {
                        checkmark(person.mark)
                        PersonAvatar(name: person.name, participantIndex: person.colorIndex, size: 40, announcesName: false)
                        Text(verbatim: person.name)
                            .espText(.headline)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        trailing(person, units: model.sheetContent?.unitCount ?? 1, alignment: .trailing)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(person.mark == .none ? Color.clear : Color.esp.selection, in: shape)
            .overlay(alignment: .leading) {
                if person.mark != .none {
                    Capsule().fill(Color.esp.pink).frame(width: 4).padding(.vertical, 16)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: person.name))
        .accessibilityValue(spokenValue(person, money: money))
        .accessibilityAddTraits(person.mark == .all ? .isSelected : [])
        .accessibilityIdentifier("assign.sheet.person.\(person.colorIndex)")
    }

    private func checkmark(_ mark: AssignViewModel.SheetMark) -> some View {
        Circle()
            .fill(mark == .none ? Color.clear : Color.esp.primary)
            .overlay {
                Circle().strokeBorder(mark == .none ? Color.esp.inkSecondary : Color.esp.primary, lineWidth: 1.5)
            }
            .overlay {
                switch mark {
                case .none: EmptyView()
                case .some: Image(systemName: "minus").font(.system(size: checkSize * 0.5, weight: .heavy)).foregroundStyle(Color.esp.onPrimary)
                case .all: Image(systemName: "checkmark").font(.system(size: checkSize * 0.5, weight: .heavy)).foregroundStyle(Color.esp.onPrimary)
                }
            }
            .frame(width: checkSize, height: checkSize)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func trailing(_ person: AssignViewModel.SheetPerson, units: Int, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            if let share = person.shareCents {
                MoneyText(cents: share, style: .amount)
                if case let .some(count) = person.mark {
                    Text(.assignProgress(count, units)).espText(.footnote).foregroundStyle(Color.esp.inkSecondary)
                }
            } else {
                Text(verbatim: "—").espText(.footnote).foregroundStyle(Color.esp.inkSecondary)
            }
        }
    }

    private func spokenValue(_ person: AssignViewModel.SheetPerson, money: MoneyFormatter) -> Text {
        guard let share = person.shareCents else { return Text("assign.unassigned") }
        let spoken = money.spokenString(cents: share)
        if case let .some(count) = person.mark {
            return Text(.assignProgress(count, model.sheetContent?.unitCount ?? 1)) + Text(verbatim: ", \(spoken)")
        }
        return Text(verbatim: spoken)
    }

    private func note(_ note: AssignViewModel.SheetNote, content: AssignViewModel.SheetContent) -> Text {
        switch note {
        case .pickOne: Text("assign.pickOne")
        case .all: Text("assign.all")
        case let .split(ways): Text(.assignSplitN(ways))
        case let .leftover(ways, cents, names):
            Text(.assignExtra(ways, cents, names.formatted(.list(type: .and).locale(locale))))
        case .mixed: Text("assign.mixed")
        case let .incomplete(left, total): Text(.assignIncomplete(left, total))
        }
    }
}

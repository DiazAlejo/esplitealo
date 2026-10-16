import EsplitealoDesign
import SwiftUI

/// One receipt line on the Mark items screen: its name and price, and under it who it is marked for (avatars and
/// either the name or the equal split), or that nobody has it yet. A line with several units says how many and how
/// many are still unmarked. The whole row is one button that opens the assign sheet.
struct AssignItemRow: View {
    let row: AssignViewModel.Row
    /// Everyone at the table, in order.
    let table: [AssignViewModel.Person]
    /// The warning is showing: rows nobody has get a warn outline.
    let highlightsUnassigned: Bool
    /// This row's sheet is open.
    let isSelected: Bool
    let actions: [AssignViewModel.RowAction]
    let onTap: () -> Void
    let onAction: (AssignViewModel.RowAction) -> Void

    @Environment(\.locale) private var locale

    private var money: MoneyFormatter { MoneyFormatter(locale: locale) }

    /// Who is marked for at least one unit, in table order.
    private var people: [AssignViewModel.Person] {
        let marked = Set(row.assigneeIDs)
        return table.filter { marked.contains($0.id) }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: row.name)
                        .espText(.body)
                        .multilineTextAlignment(.leading)
                    if row.quantity > 1 {
                        Text(.assignUnits(row.quantity))
                            .espText(.footnote)
                            .foregroundStyle(Color.esp.inkSecondary)
                    }
                    status
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MoneyText(cents: row.totalCents, style: .amount)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(background, in: shape)
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule().fill(Color.esp.pink).frame(width: 4).padding(.vertical, 14)
                }
            }
            .overlay {
                if highlightsUnassigned && row.state != .assigned {
                    shape.strokeBorder(Color.esp.warn, lineWidth: 1.5)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint(Text("assign.tapChoose"))
        .accessibilityIdentifier("assign.item.\(row.id.uuidString.lowercased())")
        .accessibilityActions {
            ForEach(actions, id: \.self) { action in
                Button { onAction(action) } label: { actionName(action) }
            }
        }
    }

    private var background: Color {
        if isSelected { return Color.esp.selection }
        return row.state == .assigned ? Color.clear : Color.esp.warnSoft
    }

    // MARK: Status line

    @ViewBuilder
    private var status: some View {
        switch row.state {
        case .unassigned:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) { unassignedMark; Text("assign.tapChoose").espText(.footnote).foregroundStyle(Color.esp.inkSecondary) }
                VStack(alignment: .leading, spacing: Spacing.xxs) { unassignedMark; Text("assign.tapChoose").espText(.footnote).foregroundStyle(Color.esp.inkSecondary) }
            }
        case .partlyAssigned:
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    warnDot
                    Text(.assignUnitsLeft(row.unassignedUnitCount, row.quantity))
                        .espText(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.esp.warn)
                }
                assignedSummary
            }
        case .assigned:
            assignedSummary
        }
    }

    private var unassignedMark: some View {
        HStack(spacing: Spacing.xs) {
            warnDot
            Text("assign.unassigned")
                .espText(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.warn)
        }
    }

    /// The dashed circle with `!`: warn colour always comes with an icon and words.
    private var warnDot: some View {
        Image(systemName: "exclamationmark")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Color.esp.warn)
            .frame(width: 20, height: 20)
            .overlay { Circle().strokeBorder(Color.esp.warn, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])) }
            .accessibilityHidden(true)
    }

    private var assignedSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) { AvatarStack(people: people); summaryText }
            VStack(alignment: .leading, spacing: Spacing.xxs) { AvatarStack(people: people); summaryText }
        }
    }

    /// One person: the name. Several: the equal split. A quantity line whose units differ: unit by unit.
    @ViewBuilder
    private var summaryText: some View {
        if !row.hasSamePeopleOnEveryUnit {
            Text("assign.byUnit").espText(.footnote).foregroundStyle(Color.esp.inkSecondary)
        } else if people.count == 1, let only = people.first {
            Text(verbatim: only.name).espText(.footnote).foregroundStyle(Color.esp.ink)
        } else {
            let values = people.compactMap { row.personShares[$0.id] }
            if let first = values.first, values.allSatisfy({ $0 == first }) {
                Text(.assignEqual(money.string(cents: first))).espText(.footnote).foregroundStyle(Color.esp.inkSecondary)
            } else {
                Text(.assignEqualMix(values.map { money.string(cents: $0) }.joined(separator: " · ")))
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
            }
        }
    }

    // MARK: VoiceOver

    private var spokenLabel: String {
        let name = row.quantity > 1 ? String(resolving: .assignAriaUnitsName(row.name, row.quantity), in: locale) : row.name
        let price = money.spokenString(cents: row.totalCents)
        let who = people.map(\.name).formatted(.list(type: .and).locale(locale))
        switch row.state {
        case .unassigned:
            return String(resolving: .assignAriaUnassigned(name, price), in: locale)
        case .assigned:
            return String(resolving: .assignAriaAssigned(name, price, who), in: locale)
        case .partlyAssigned:
            return String(resolving: .assignAriaPartial(name, price, row.quantity - row.unassignedUnitCount, row.quantity, who), in: locale)
        }
    }

    private func actionName(_ action: AssignViewModel.RowAction) -> Text {
        func name(of id: UUID) -> String { table.first { $0.id == id }?.name ?? "" }
        switch action {
        case let .mark(id): return Text(.assignActionMark(name(of: id)))
        case let .unmark(id): return Text(.assignActionUnmark(name(of: id)))
        case .markEveryone: return Text("assign.action.everyone")
        case .clear: return Text("assign.action.clear")
        }
    }
}

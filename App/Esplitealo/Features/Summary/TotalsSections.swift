import EsplitealoDesign
import SwiftUI

/// Resolves a catalog string in the language of the view, not of the process (snapshots and previews set the locale
/// on the environment only).
private func localized(_ resource: LocalizedStringResource, in locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
}

// MARK: - Status banner

/// "Suma $132.82" when it all matches the receipt; otherwise why the split cannot be shared yet: items nobody has
/// claimed, a difference with the receipt, a missing total, discounts the app cannot split, or no priced item to
/// carry the tax and tip.
struct TotalsStatusBanner: View {
    let status: TotalsViewModel.Status

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var mascotSize: CGFloat = 62

    private func money(_ cents: Int) -> String { MoneyFormatter(locale: locale).string(cents: cents) }

    var body: some View {
        switch status {
        case let .reconciled(total):
            banner(icon: AnyView(Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.esp.primary).font(.title2).accessibilityHidden(true)),
                   fill: Color.esp.okBackground, outline: Color.esp.primary) {
                Text(.totalsOkTitle(money(total))).espText(.headline)
                Text("totals.ok.subtitle").espText(.footnote).foregroundStyle(Color.esp.inkSecondary)
            }
        case let .unassigned(items, cents):
            warning(icon: AnyView(warnIcon)) {
                Text("totals.notSettled.title").espText(.headline)
                Text(.totalsNotSettledBody(items, money(cents))).espText(.footnote)
            }
        case let .receiptMismatch(difference, items, subtotal):
            warning(icon: mascot) {
                Text(.totalsOffTitle(money(difference))).espText(.headline)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if let items, let subtotal {
                        Text(.totalsOffBody(money(items), money(subtotal)))
                    } else {
                        Text("totals.off.bodyNoItems")
                    }
                    Text("totals.off.fix")
                }
                .espText(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            }
        case .missingTotal:
            warning(icon: mascot) {
                Text("review.missingTotal.title").espText(.headline)
                Text("review.missingTotal.body").espText(.footnote)
            }
        case .discountsNotSplit:
            warning(icon: mascot) {
                Text("totals.adjust.title").espText(.headline)
                Text("review.adjustments.note").espText(.footnote)
            }
        case .nobodyCarriesCharges:
            warning(icon: mascot) {
                Text("totals.nobodyItems.title").espText(.headline)
                Text("totals.nobodyItems.body").espText(.footnote)
            }
        }
    }

    private var warnIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(Color.esp.warn)
            .font(.title2)
            .accessibilityHidden(true)
    }

    private var mascot: AnyView {
        AnyView(
            ChavitoView(expression: .worried, size: min(mascotSize, 96), decorative: true, animated: false)
                .padding(.vertical, -6)
        )
    }

    private func warning<Lines: View>(icon: AnyView, @ViewBuilder lines: () -> Lines) -> some View {
        banner(icon: icon, fill: Color.esp.warnBackground, outline: Color.esp.warn, lines: lines)
    }

    private func banner<Lines: View>(icon: AnyView, fill: Color, outline: Color, @ViewBuilder lines: () -> Lines) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        // At accessibility text sizes the picture goes above the words instead of squeezing them.
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs)) : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
        return layout {
            icon
            VStack(alignment: .leading, spacing: Spacing.xxs) { lines() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(fill, in: shape)
        .overlay { shape.strokeBorder(outline, lineWidth: 1.5) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("totals.banner")
    }
}

// MARK: - Tip

/// The tip: 15, 18 or 20 percent of the subtotal before tax, or of the total with tax, or an amount of the user's own.
struct TipSettings: View {
    let model: TotalsViewModel

    @Environment(\.locale) private var locale
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            label
            selector
            if model.tipSelection == .custom {
                customRow
            } else {
                Toggle(isOn: Binding(get: { model.usesPostTaxTip }, set: { model.usesPostTaxTip = $0 })) {
                    Text("totals.tip.postTax").espText(.subhead)
                }
                .tint(Color.esp.primary)
                .frame(minHeight: TapTarget.minimum)
                .accessibilityIdentifier("totals.tip.postTax")
            }
            hint
        }
    }

    private var label: some View {
        Group {
            if model.tipSelection == .custom {
                Text("totals.tip")
            } else if model.usesPostTaxTip {
                Text(.totalsTipLabelPostTax(MoneyFormatter(locale: locale).string(cents: model.tipBaseCents)))
            } else {
                Text(.totalsTipLabel(MoneyFormatter(locale: locale).string(cents: model.tipBaseCents)))
            }
        }
        .espText(.footnote)
        .fontWeight(.semibold)
        .foregroundStyle(Color.esp.inkSecondary)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Buttons

    private var selector: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) { segments }
            VStack(spacing: 2) {
                HStack(spacing: 2) { presetSegments }
                HStack(spacing: 2) { customSegment }
            }
        }
        .padding(3)
        .background(Color.esp.well, in: RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("totals.tip.aria"))
    }

    @ViewBuilder private var segments: some View {
        presetSegments
        customSegment
    }

    @ViewBuilder private var presetSegments: some View {
        ForEach(TotalsViewModel.tipPresets, id: \.self) { percent in
            Segment(isSelected: model.tipSelection == .preset(percent)) {
                model.selectPreset(percent)
            } label: {
                Text(verbatim: "\(percent)%")
            }
            .accessibilityLabel(Text(Double(percent) / 100, format: .percent))
            .accessibilityIdentifier("totals.tip.preset.\(percent)")
        }
    }

    private var customSegment: some View {
        Segment(isSelected: model.tipSelection == .custom) {
            model.selectCustom()
        } label: {
            Text("totals.tip.custom")
        }
        .accessibilityIdentifier("totals.tip.custom")
    }

    // MARK: Custom amount

    private var customRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                stepButton(systemImage: "minus", label: "totals.tip.decrease", delta: -TotalsViewModel.tipStep, identifier: "totals.tip.decrease")
                    .disabled(!model.canDecreaseTip)
                TextField(
                    text: Binding(get: { model.customTipText }, set: { model.customTipText = $0 }),
                    prompt: Text(verbatim: "0.00")
                ) {
                    Text("totals.tip.customAria")
                }
                .focused($fieldFocused)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .espText(.amount)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: TapTarget.primaryButtonHeight)
                .background(Color.esp.well, in: RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.smallButton, style: .continuous)
                        .strokeBorder(Color.esp.warn, lineWidth: model.customTipIsInvalid ? 1.5 : 0)
                }
                .accessibilityLabel(Text("totals.tip.customAria"))
                .accessibilityIdentifier("totals.tip.field")
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("common.done") { fieldFocused = false }
                    }
                }
                stepButton(systemImage: "plus", label: "totals.tip.increase", delta: TotalsViewModel.tipStep, identifier: "totals.tip.increase")
                    .disabled(!model.canIncreaseTip)
            }
            if model.customTipIsInvalid {
                Label {
                    Text("sheet.errAmount")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                }
                .espText(.footnote)
                .foregroundStyle(Color.esp.warn)
            }
        }
        .onChange(of: fieldFocused) { _, focused in
            if !focused { model.endCustomTipEditing() }
        }
    }

    private func stepButton(systemImage: String, label: LocalizedStringKey, delta: Int, identifier: String) -> some View {
        Button {
            model.stepCustomTip(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum)
                .background(Color.esp.well, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.esp.primary)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    // MARK: Service charge note

    @ViewBuilder private var hint: some View {
        switch model.tipHint {
        case .none:
            EmptyView()
        case let .serviceIncluded(service):
            Text(.totalsTipServiceIncluded(MoneyFormatter(locale: locale).string(cents: service)))
                .espText(.footnote)
                .foregroundStyle(Color.esp.inkSecondary)
                .accessibilityIdentifier("totals.tip.hint")
        case let .serviceDouble(service):
            Text(.totalsTipServiceDouble(MoneyFormatter(locale: locale).string(cents: service)))
                .espText(.footnote)
                .foregroundStyle(Color.esp.inkSecondary)
                .accessibilityIdentifier("totals.tip.hint")
        }
    }
}

/// One choice of the tip selector: at least 44 pt tall, the chosen one raised on the surface with the pink underline.
private struct Segment<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .espText(.headline)
                .foregroundStyle(isSelected ? Color.esp.ink : Color.esp.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: TapTarget.minimum)
                .padding(.horizontal, Spacing.xs)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.esp.surface)
                    }
                }
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule().fill(Color.esp.pink).frame(width: 28, height: 4).padding(.bottom, 4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Summary

/// The bill with the tip in big numbers, and the subtotal, tax, service charge and tip it is made of.
struct TotalsSummary: View {
    let summary: TotalsViewModel.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("totals.billTotal")
                    .espText(.caption)
                    .foregroundStyle(Color.esp.inkSecondary)
                MoneyText(cents: summary.billTotalCents, style: .displayAmount)
                    .accessibilityIdentifier("totals.billTotal")
                Capsule().fill(Color.esp.pink).frame(width: 64, height: 3).accessibilityHidden(true)
            }
            Rectangle().fill(Color.esp.hairline).frame(height: Stroke.hairline).accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.xs) { columns }
                VStack(spacing: 0) { rows }
            }
        }
        .padding(.top, Spacing.xs)
    }

    @ViewBuilder private var columns: some View {
        column("totals.subtotal", summary.subtotalCents)
        column("totals.tax", summary.taxCents)
        if summary.showsService { column("totals.service", summary.serviceCents) }
        column("totals.tip", summary.tipCents)
    }

    @ViewBuilder private var rows: some View {
        AmountRow("totals.subtotal", cents: summary.subtotalCents)
        AmountRow("totals.tax", cents: summary.taxCents)
        if summary.showsService { AmountRow("totals.service", cents: summary.serviceCents) }
        AmountRow("totals.tip", cents: summary.tipCents)
    }

    private func column(_ title: LocalizedStringKey, _ cents: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).espText(.caption).foregroundStyle(Color.esp.inkSecondary)
            MoneyText(cents: cents, style: .amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Who owes what

struct WhoOwesSection: View {
    let rows: [TotalsViewModel.PersonRow]
    let showsService: Bool

    @Environment(\.locale) private var locale
    @State private var expanded: Set<UUID> = []
    @ScaledMetric(relativeTo: .footnote) private var markSize: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                DivisionMark().fill(Color.esp.pink).frame(width: markSize, height: markSize).accessibilityHidden(true)
                Text("totals.whoOwes")
            }
            .espText(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(Color.esp.inkSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ShareBar(rows: rows)

            RowsCard(rows) { row in
                PersonCard(row: row, showsService: showsService, isExpanded: expanded.contains(row.id)) {
                    withAnimation(.snappy(duration: 0.25)) {
                        if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
                    }
                }
            }
        }
    }
}

/// One proportional bar for the whole bill, a segment per person in their colour, a pink rule under it, and a legend
/// with names and percentages (colour is never the only signal).
struct ShareBar: View {
    let rows: [TotalsViewModel.PersonRow]

    private var spoken: String {
        rows.map { "\($0.name) \($0.percent)%" }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(spacing: 6) {
                GeometryReader { proxy in
                    let gaps = CGFloat(max(0, rows.count - 1)) * 2
                    HStack(spacing: 2) {
                        ForEach(rows) { row in
                            Rectangle()
                                .fill(PersonColorSlot(participantIndex: row.colorIndex).fillColor)
                                .frame(width: max(2, (proxy.size.width - gaps) * row.fraction))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .frame(height: 10)
                Capsule().fill(Color.esp.pink).frame(height: 3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("totals.bar.aria"))
            .accessibilityValue(Text(verbatim: spoken))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: Spacing.xxs) {
                ForEach(rows) { row in
                    HStack(spacing: 6) {
                        Circle().fill(PersonColorSlot(participantIndex: row.colorIndex).fillColor).frame(width: 8, height: 8)
                        Text(verbatim: "\(row.name) \(row.percent)%")
                    }
                }
            }
            .espText(.footnote)
            .foregroundStyle(Color.esp.inkSecondary)
            .accessibilityHidden(true)
        }
    }
}

/// A person at the table: colour edge, avatar, what they owe, the three parts it is made of, and (on tap) their items.
struct PersonCard: View {
    let row: TotalsViewModel.PersonRow
    let showsService: Bool
    let isExpanded: Bool
    let toggle: () -> Void

    @Environment(\.locale) private var locale

    private var slot: PersonColorSlot { PersonColorSlot(participantIndex: row.colorIndex) }

    private func money(_ cents: Int) -> String { MoneyFormatter(locale: locale).string(cents: cents) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                header
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityHint(Text(isExpanded ? "totals.person.collapse" : "totals.person.hint"))
            .accessibilityIdentifier("totals.person.\(row.colorIndex)")

            if isExpanded {
                VStack(spacing: Spacing.xxs) {
                    ForEach(row.itemLines) { line in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.xxs) {
                                Text(verbatim: line.name)
                                if line.splitWays > 1 {
                                    Text(verbatim: "1/\(line.splitWays)").espText(.caption).foregroundStyle(Color.esp.inkSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            MoneyText(cents: line.cents, style: .amount)
                        }
                        .espText(.subhead)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.leading, 72)
                .padding(.trailing, Spacing.sm)
                .padding(.bottom, Spacing.sm)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(slot.fillColor).frame(width: 4).accessibilityHidden(true)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                who
                MoneyText(cents: row.totalCents, style: .amount)
                chevron
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                who
                HStack {
                    MoneyText(cents: row.totalCents, style: .amount)
                    Spacer(minLength: 0)
                    chevron
                }
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var who: some View {
        HStack(spacing: Spacing.sm) {
            PersonAvatar(name: row.name, participantIndex: row.colorIndex, size: 40, announcesName: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.name)
                    .espText(.headline)
                    .multilineTextAlignment(.leading)
                breakdownLine
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .multilineTextAlignment(.leading)
                if row.roundingCents > 0 {
                    Text(.totalsRounding(row.roundingCents))
                        .espText(.caption)
                        .foregroundStyle(Color.esp.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var breakdownLine: Text {
        showsService
            ? Text(.totalsLineService(money(row.itemsCents), money(row.taxCents), money(row.serviceCents), money(row.tipCents)))
            : Text(.totalsLine(money(row.itemsCents), money(row.taxCents), money(row.tipCents)))
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.esp.inkSecondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .frame(minWidth: 20)
            .accessibilityHidden(true)
    }
}

// MARK: - Rounding

/// "Dónde cayeron los chavitos sueltos": every stray cent and who got it, so nothing is hidden. Chavito thinks over it.
struct RoundingCard: View {
    let notes: [TotalsViewModel.RoundingNote]

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs)) : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
        layout {
            ChavitoView(expression: .thinking, size: 76, decorative: false, animated: false)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("totals.round.title")
                    .espText(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(verbatim: "•").accessibilityHidden(true)
                        text(for: note)
                    }
                    .espText(.footnote)
                }
                Text("totals.round.rule")
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .padding(.top, Spacing.xxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, Spacing.md)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.esp.hairline).frame(height: Stroke.hairline).accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("totals.rounding")
    }

    private func list(_ names: [String]) -> String {
        names.formatted(.list(type: .and, width: .standard).locale(locale))
    }

    private func text(for note: TotalsViewModel.RoundingNote) -> Text {
        let formatter = MoneyFormatter(locale: locale)
        switch note {
        case let .item(name, price, ways, leftover, names):
            return names.count == 1
                ? Text(.totalsRoundItemOne(name, formatter.string(cents: price), ways, leftover, list(names)))
                : Text(.totalsRoundItemMany(name, formatter.string(cents: price), ways, leftover, list(names)))
        case let .pool(pool, cents, names):
            let label: LocalizedStringResource = switch pool {
            case .tax: .totalsTax
            case .service: .totalsService
            case .tip: .totalsTip
            }
            return Text(.totalsRoundPool(localized(label, in: locale), cents, list(names)))
        }
    }
}

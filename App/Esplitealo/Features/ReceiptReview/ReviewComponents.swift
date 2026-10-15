import EsplitealoDesign
import SwiftUI

extension ItemFlagReason {
    /// The words next to the warning icon on a flagged row.
    var label: LocalizedStringKey {
        switch self {
        case .priceOnAnotherLine: "review.flag.anotherLine"
        case .quantityMismatch: "review.flag.quantity"
        case .missingPrice: "review.flag.missingPrice"
        case .formatGuessed: "review.flag.format"
        case .needsLook: "review.flag.look"
        }
    }
}

/// "Todo quedó nítido" or "Los números como quiera no cuadran", with the difference and where to look. It is the
/// reconciliation result and is recomputed after every edit. Nothing for an empty receipt.
struct ReviewBanner: View {
    let status: ReceiptReviewModel.Status
    let model: ReceiptReviewModel

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var mascotSize: CGFloat = 62

    var body: some View {
        switch status {
        case .noItems:
            EmptyView()
        case .balanced:
            banner(icon: AnyView(Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.esp.primary).font(.title2).accessibilityHidden(true)),
                   fill: Color.esp.okBackground, outline: Color.esp.primary) {
                Text("review.ok.title").espText(.headline)
                Text("review.ok.body").espText(.footnote).foregroundStyle(Color.esp.inkSecondary)
            }
        case let .itemsDoNotMatchSubtotal(items, subtotal):
            warning {
                Text(.reviewWarnItems(money(items), money(subtotal)))
                Text(.reviewDiff(money(status.differenceCents ?? 0)))
                Text("review.checkRow")
            }
        case let .totalsDoNotAddUp(expected, printed, includesService):
            let sentence: LocalizedStringResource = includesService
                ? .reviewWarnTotalService(money(expected), money(printed))
                : .reviewWarnTotal(money(expected), money(printed))
            warning {
                Text(sentence)
                Text(.reviewDiff(money(status.differenceCents ?? 0)))
                Text("review.checkAmounts")
            }
        case .missingTotal:
            banner(icon: mascot, fill: Color.esp.warnBackground, outline: Color.esp.warn) {
                Text("review.missingTotal.title").espText(.headline)
                Text("review.missingTotal.body").espText(.footnote)
            }
        }
    }

    private func money(_ cents: Int) -> String {
        MoneyFormatter(locale: locale).string(cents: cents)
    }

    private var mascot: AnyView {
        AnyView(
            ChavitoView(expression: .worried, size: min(mascotSize, 96), decorative: true, animated: false)
                .padding(.vertical, -6)
        )
    }

    private func warning<Lines: View>(@ViewBuilder lines: () -> Lines) -> some View {
        banner(icon: mascot, fill: Color.esp.warnBackground, outline: Color.esp.warn) {
            Text("review.warn.title").espText(.headline)
            lines().espText(.footnote)
        }
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
        .accessibilityIdentifier("review.banner")
    }
}

/// A small label above a group of rows with how many there are: "Artículos · 7".
struct ReviewSectionHeader: View {
    let title: LocalizedStringKey
    var count: Int?
    var isWarning = false

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Text(title)
            if let count {
                Text(verbatim: "· \(count)")
            }
        }
        .espText(.footnote)
        .fontWeight(.semibold)
        .foregroundStyle(isWarning ? Color.esp.warn : Color.esp.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Icon and words in the warn colour: "Chequear · el precio parece alto".
struct WarnPill: View {
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
        }
        .espText(.footnote)
        .fontWeight(.semibold)
        .foregroundStyle(Color.esp.warn)
    }
}

/// One receipt row: description, how many at what price when there is more than one, the parser's reason when it is
/// flagged, and the line total. The row is a button that opens the editor.
struct ReviewItemRow: View {
    let row: ReceiptReviewModel.ItemRow
    let action: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isFlagged = row.flag != nil
        // The amount stays at the end of the row; at accessibility text sizes it moves under the description.
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
        Button(action: action) {
            layout {
                details
                amount
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(isFlagged ? Color.esp.warnBackground : Color.clear)
            .overlay(alignment: .leading) {
                if isFlagged { Rectangle().fill(Color.esp.warn).frame(width: 4) }
            }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint("review.edit.hint")
        .accessibilityIdentifier("review.item.\(row.id.uuidString)")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: row.name)
                .espText(.body)
                .multilineTextAlignment(.leading)
            if row.quantity > 1 {
                Text(.reviewItemQuantityEach(row.quantity, MoneyFormatter(locale: locale).string(cents: row.unitPriceCents)))
                    .espText(.footnote)
                    .foregroundStyle(Color.esp.inkSecondary)
            }
            if let flag = row.flag {
                WarnPill(text: flag.label)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amount: some View {
        MoneyText(cents: row.lineTotalCents, style: .amount)
            .foregroundStyle(row.flag == nil ? Color.esp.ink : Color.esp.warn)
    }
}

/// One of the receipt's printed amounts (subtotal, tax, service, total). Marked to check, with the reason, when it is
/// the one that does not add up.
struct ReviewFieldRow: View {
    let field: ReceiptField
    let model: ReceiptReviewModel
    let action: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let needsAttention = model.needsAttention(field)
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
        Button(action: action) {
            layout {
                label
                value(needsAttention)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(needsAttention ? Color.esp.warnBackground : Color.clear)
            .overlay(alignment: .leading) {
                if needsAttention { Rectangle().fill(Color.esp.warn).frame(width: 4) }
            }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint("review.edit.hint")
        .accessibilityIdentifier("review.field.\(field.rawValue)")
    }

    private var title: LocalizedStringKey {
        switch field {
        case .subtotal: "review.subtotal"
        case .tax: "review.tax"
        case .service: "review.service"
        case .total: "review.total"
        }
    }

    private var note: Text? {
        let formatter = MoneyFormatter(locale: locale)
        switch (field, model.status) {
        case (.subtotal, .itemsDoNotMatchSubtotal):
            return Text(.reviewItemsAddUp(formatter.string(cents: model.itemsSumCents)))
        case let (.total, .totalsDoNotAddUp(_, _, includesService)):
            let sum = formatter.string(cents: model.subtotalPlusExtrasCents)
            let sentence: LocalizedStringResource = includesService ? .reviewSubPlusTaxService(sum) : .reviewSubPlusTax(sum)
            return Text(sentence)
        default:
            return nil
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).espText(.body)
            if let note {
                note
                    .espText(.footnote)
                    .foregroundStyle(model.needsAttention(field) ? Color.esp.warn : Color.esp.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func value(_ needsAttention: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            if needsAttention { WarnPill(text: "review.check") }
            if let cents = model.amountCents(field) {
                MoneyText(cents: cents, style: .amount)
                    .foregroundStyle(needsAttention ? Color.esp.warn : Color.esp.ink)
            } else {
                Text("review.field.missing")
                    .espText(.headline)
                    .foregroundStyle(needsAttention ? Color.esp.warn : Color.esp.inkSecondary)
            }
        }
    }
}

/// A parser row that is not an item (a discount): the label, the amount, and a way to remove it.
struct ReviewAdjustmentRow: View {
    let row: ReceiptReviewModel.AdjustmentRow
    let onRemove: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                label
                removeButton
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                label
                removeButton
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(verbatim: row.label)
                .espText(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            MoneyText(cents: row.cents, style: .amount)
        }
        .accessibilityElement(children: .combine)
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Text("review.adjustments.remove")
                .espText(.subhead)
                .fontWeight(.semibold)
                .foregroundStyle(Color.esp.warn)
                .frame(minWidth: TapTarget.minimum, minHeight: TapTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(.reviewAdjustmentsRemoveLabel(row.label)))
        .accessibilityIdentifier("review.adjustment.remove.\(row.id)")
    }
}

/// No items yet: Chavito and a nudge to add the first line.
struct ReviewEmptyCard: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            ChavitoView(expression: .neutral, size: 96, decorative: true, animated: false)
            Text("review.empty.title").espText(.headline)
            Text("review.empty.body")
                .espText(.subhead)
                .foregroundStyle(Color.esp.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(Color.esp.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.esp.line, lineWidth: Stroke.hairline) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("review.empty")
    }
}

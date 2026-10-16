import EsplitealoDesign
import SwiftUI

/// Add a receipt row or edit one: description, how many, the price of one, and (for a row the parser flagged) what it
/// read. Saving a flagged row is the user's confirmation of it.
struct ItemEditorSheet: View {
    let model: ReceiptReviewModel
    let itemID: UUID?
    let onClose: () -> Void

    @Environment(\.locale) private var locale
    @State private var name: String
    @State private var priceText: String
    @State private var quantity: Int
    @State private var error: ReceiptReviewModel.ItemInputError?
    @State private var flaggedCents: Int?
    @FocusState private var focus: Field?

    private enum Field { case name, price }

    init(model: ReceiptReviewModel, itemID: UUID?, onClose: @escaping () -> Void) {
        self.model = model
        self.itemID = itemID
        self.onClose = onClose
        let row = model.items.first { $0.id == itemID }
        _name = State(initialValue: row?.name ?? "")
        _priceText = State(initialValue: row.map { MoneyInput.editableText(cents: $0.unitPriceCents) } ?? "")
        _quantity = State(initialValue: row?.quantity ?? 1)
        _flaggedCents = State(initialValue: row.flatMap { $0.flag == nil ? nil : $0.lineTotalCents })
    }

    private var lineTotalCents: Int? {
        MoneyInput.cents(from: priceText).map { $0 * quantity }
    }

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SheetTitle(itemID == nil ? "sheet.newItem" : "sheet.editItem")

                if let flaggedCents {
                    flagNote(flaggedCents)
                }

                SheetField("sheet.description", error: error == .missingName ? Text("sheet.errName") : nil) {
                    TextField(text: $name, prompt: Text("sheet.descriptionPlaceholder").foregroundStyle(Color.esp.inkSecondary)) { Text("sheet.description") }
                        .focused($focus, equals: .name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .onSubmit { focus = .price }
                        .accessibilityIdentifier("sheet.item.name")
                }

                Stepper(value: $quantity, in: ReceiptReviewModel.quantityRange) {
                    Text(.sheetQuantityValue(quantity)).espText(.body)
                }
                .accessibilityIdentifier("sheet.item.quantity")

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SheetField("sheet.unitPrice", error: error == .invalidPrice ? Text("sheet.errPrice") : nil) {
                        TextField(text: $priceText, prompt: Text(verbatim: "0.00").foregroundStyle(Color.esp.inkSecondary)) { Text("sheet.unitPrice") }
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focus, equals: .price)
                            .decimalPadDoneButton { focus = nil }
                            .accessibilityIdentifier("sheet.item.price")
                    }
                    if quantity > 1, let lineTotalCents {
                        Text(.sheetLineTotal(MoneyFormatter(locale: locale).string(cents: lineTotalCents)))
                            .espText(.footnote)
                            .foregroundStyle(Color.esp.inkSecondary)
                    }
                }

                Button("sheet.save", action: save)
                    .buttonStyle(.espPrimary)
                    .accessibilityIdentifier("sheet.save")

                HStack(spacing: Spacing.xs) {
                    if let itemID {
                        Button("sheet.delete") {
                            model.deleteItem(id: itemID)
                            onClose()
                        }
                        .buttonStyle(.espWarn)
                        .accessibilityIdentifier("sheet.delete")
                    }
                    Button("sheet.cancel", action: onClose)
                        .buttonStyle(.espQuiet)
                        .accessibilityIdentifier("sheet.cancel")
                }
            }
        }
        .onChange(of: name) { error = error == .missingName ? nil : error }
        .onChange(of: priceText) { error = error == .invalidPrice ? nil : error }
        .onAppear { if itemID == nil { focus = .name } }
    }

    private func flagNote(_ cents: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.esp.warn)
                .accessibilityHidden(true)
            Text(.sheetFlagNote(MoneyFormatter(locale: locale).string(cents: cents)))
                .espText(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.sm)
        .background(Color.esp.warnBackground, in: shape)
        .overlay { shape.strokeBorder(Color.esp.warn, lineWidth: 1.5) }
        .accessibilityElement(children: .combine)
    }

    private func save() {
        let failure: ReceiptReviewModel.ItemInputError?
        if let itemID {
            failure = model.updateItem(id: itemID, name: name, priceText: priceText, quantity: quantity)
        } else {
            failure = model.addItem(name: name, priceText: priceText, quantity: quantity)
        }
        if let failure {
            error = failure
            focus = failure == .missingName ? .name : .price
        } else {
            onClose()
        }
    }
}

/// Edit one of the amounts printed on the receipt. An empty field means the receipt does not have that amount
/// (except the total, which it always has).
struct AmountEditorSheet: View {
    let model: ReceiptReviewModel
    let field: ReceiptField
    let onClose: () -> Void

    @State private var text: String
    @State private var hasError = false
    @FocusState private var focused: Bool

    init(model: ReceiptReviewModel, field: ReceiptField, onClose: @escaping () -> Void) {
        self.model = model
        self.field = field
        self.onClose = onClose
        _text = State(initialValue: model.amountCents(field).map(MoneyInput.editableText(cents:)) ?? "")
    }

    private var title: LocalizedStringKey {
        switch field {
        case .subtotal: "review.subtotal"
        case .tax: "review.tax"
        case .service: "review.service"
        case .total: "sheet.receiptTotal"
        }
    }

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SheetTitle(title)
                    Text("sheet.typeIt")
                        .espText(.subhead)
                        .foregroundStyle(Color.esp.inkSecondary)
                    if field.isOptional {
                        Text("sheet.leaveEmpty")
                            .espText(.subhead)
                            .foregroundStyle(Color.esp.inkSecondary)
                    }
                }

                SheetField("sheet.amount", error: hasError ? Text("sheet.errAmount") : nil) {
                    TextField(text: $text, prompt: Text(verbatim: "0.00").foregroundStyle(Color.esp.inkSecondary)) { Text("sheet.amount") }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                        .decimalPadDoneButton { focused = false }
                        .accessibilityIdentifier("sheet.amount.field")
                }

                Button("sheet.save") {
                    if model.setAmount(field, text: text) == nil {
                        onClose()
                    } else {
                        hasError = true
                        focused = true
                    }
                }
                .buttonStyle(.espPrimary)
                .accessibilityIdentifier("sheet.save")

                Button("sheet.cancel", action: onClose)
                    .buttonStyle(.espQuiet)
                    .accessibilityIdentifier("sheet.cancel")
            }
        }
        .onChange(of: text) { hasError = false }
        .onAppear { focused = true }
    }
}

/// The receipt does not add up (or has no printed total) and the user asked to continue: say what is off, and that
/// sharing stays blocked until it adds up. Continuing from here is the explicit confirmation.
struct MismatchConfirmationSheet: View {
    /// How far off the numbers are; `nil` when the receipt has no printed total to compare.
    let differenceCents: Int?
    let onFix: () -> Void
    let onContinue: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    ChavitoView(expression: .worried, size: 64, decorative: true, animated: false)
                    if differenceCents == nil {
                        SheetTitle("review.missingTotal.title", showsMark: false)
                    } else {
                        SheetTitle("review.bad.title", showsMark: false)
                    }
                }

                if let differenceCents {
                    Text(.reviewBadBody(MoneyFormatter(locale: locale).string(cents: differenceCents)))
                        .espText(.body)
                } else {
                    Text("review.bad.bodyMissing").espText(.body)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.sm) {
                        fix.frame(maxWidth: .infinity)
                        keepGoing.frame(maxWidth: .infinity)
                    }
                    VStack(spacing: Spacing.xs) {
                        fix
                        keepGoing
                    }
                }
            }
        }
    }

    private var fix: some View {
        Button("review.fixIt", action: onFix)
            .buttonStyle(.espPrimary)
            .accessibilityIdentifier("review.confirm.fix")
    }

    private var keepGoing: some View {
        Button("review.keepGoing", action: onContinue)
            .buttonStyle(.espSecondary)
            .accessibilityIdentifier("review.confirm.continue")
    }
}

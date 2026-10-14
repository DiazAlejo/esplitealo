import EsplitealoCore
import Foundation

enum ScanLabIssueMessages {
    static func describe(_ issue: ReceiptIssue) -> String {
        switch issue {
        case .itemsDoNotMatchSubtotal(let itemsSum, let printed):
            return "Item lines sum to \(ScanLabMoneyFormat.dollars(fromMinorUnits: itemsSum)) but printed subtotal is \(ScanLabMoneyFormat.dollars(fromMinorUnits: printed))."
        case .totalsDoNotAddUp(let expected, let printed):
            return "Subtotal + tax + tip should be \(ScanLabMoneyFormat.dollars(fromMinorUnits: expected)) but printed total is \(ScanLabMoneyFormat.dollars(fromMinorUnits: printed))."
        case .numberFormatGuessed(let format):
            return "Number format was guessed (decimal '\(format.decimalSeparator)', grouping '\(format.groupSeparator)')."
        case .noTotalFound:
            return "No total line was found."
        case .noItemsFound:
            return "No item lines were found."
        case .unparsedPriceRow(let text):
            return "Could not parse price row: \(text)"
        }
    }
}

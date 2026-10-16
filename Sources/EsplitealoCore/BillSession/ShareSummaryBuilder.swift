import Foundation

public enum ShareSummaryBuilder {
    /// `calendar` decides which day the bill's date falls on (the device calendar by default).
    public static func build(
        for session: BillSession,
        language: ShareLanguage,
        calendar: Calendar = .current
    ) -> String {
        let strings = ShareSummaryStrings.bundle(for: language)
        let date = ShareSummaryStrings.dateLabel(session.date, language: language, calendar: calendar)
        guard !session.hasUnallocatedAdjustments else { return "" }
        guard let printedTotal = session.printedReceiptTotalCents else { return "" }
        let bill = MoneyFormatting.usd(cents: printedTotal)
        let tipCents = session.sessionTipCents
        let tipLabel =
            switch session.tip {
            case let .percentage(percent, _): strings.tipPct(percent)
            case .custom: strings.tipFlat
            }
        let confirmed = MoneyFormatting.usd(cents: session.confirmedBillTotalCents)
        let service =
            session.serviceChargeCents > 0 ? MoneyFormatting.usd(cents: session.serviceChargeCents) : ""
        var text = strings.head(
            session.merchantName,
            date,
            bill,
            tipLabel,
            MoneyFormatting.usd(cents: tipCents),
            confirmed,
            service
        )
        let ordered = session.participants.sorted { $0.orderIndex < $1.orderIndex }
        let breakdowns = session.personBreakdowns
        for participant in ordered {
            guard let row = breakdowns.first(where: { $0.participantID == participant.id }) else { continue }
            // A tip printed on the receipt is shared like a service charge and named the same way, so the person's
            // lines add up to what they owe.
            let gratuityShare = row.serviceShareCents + row.receiptTipShareCents
            let servicePart = gratuityShare > 0 ? MoneyFormatting.usd(cents: gratuityShare) : ""
            text += strings.person(
                participant.name,
                MoneyFormatting.usd(cents: row.totalOwedCents),
                MoneyFormatting.usd(cents: row.itemSubtotalCents),
                MoneyFormatting.usd(cents: row.taxShareCents),
                servicePart,
                MoneyFormatting.usd(cents: row.tipShareCents)
            )
        }
        let sum = breakdowns.map(\.totalOwedCents).reduce(0, +)
        text += strings.close(MoneyFormatting.usd(cents: sum))
        return text
    }
}

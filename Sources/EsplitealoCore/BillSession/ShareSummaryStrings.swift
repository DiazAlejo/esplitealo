import Foundation

enum ShareSummaryStrings {
    struct Bundle {
        let head: (String, String, String, String, String, String, String) -> String
        let tipPct: (Int) -> String
        let tipFlat: String
        let person: (String, String, String, String, String, String) -> String
        let close: (String) -> String
    }

    private static let shortMonthsEs = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    private static let shortMonthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "13 oct" / "Oct 13". Fixed tables instead of `DateFormatter`, so the share text never
    /// depends on the device locale or on ICU details (and stays portable).
    static func dateLabel(_ date: Date?, language: ShareLanguage, calendar: Calendar) -> String {
        guard let date else { return "" }
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day, (1 ... 12).contains(month) else { return "" }
        switch language {
        case .es: return "\(day) \(shortMonthsEs[month - 1])"
        case .en: return "\(shortMonthsEn[month - 1]) \(day)"
        }
    }

    static func bundle(for language: ShareLanguage) -> Bundle {
        switch language {
        case .es:
            Bundle(
                head: { merchant, date, bill, tipLabel, tip, confirmed, service in
                    merchant + " · " + date + "\nCuenta " + bill
                        + (service.isEmpty ? "" : " (incluye servicio " + service + ")")
                        + " + " + tipLabel + " " + tip + " = " + confirmed + "\n"
                },
                tipPct: { p in "propina \(p)%" },
                tipFlat: "propina",
                person: { name, total, items, tax, service, tip in
                    "\n" + name + " debe " + total + "\n  artículos " + items + " · impuesto " + tax
                        + (service.isEmpty ? "" : " · servicio " + service) + " · propina " + tip + "\n"
                },
                close: { v in "\nTodo cuadra en " + v + ". Esplitéalo y listo 🦝\n" }
            )
        case .en:
            Bundle(
                head: { merchant, date, bill, tipLabel, tip, confirmed, service in
                    merchant + " · " + date + "\nBill " + bill
                        + (service.isEmpty ? "" : " (includes service " + service + ")")
                        + " + " + tipLabel + " " + tip + " = " + confirmed + "\n"
                },
                tipPct: { p in "\(p)% tip" },
                tipFlat: "tip",
                person: { name, total, items, tax, service, tip in
                    "\n" + name + " owes " + total + "\n  items " + items + " · tax " + tax
                        + (service.isEmpty ? "" : " · service " + service) + " · tip " + tip + "\n"
                },
                close: { v in "\nAdds up to " + v + ". Split with Esplitéalo\n" }
            )
        }
    }
}

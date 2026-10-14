import Foundation

enum ShareSummaryStrings {
    struct Bundle {
        let head: (String, String, String, String, String, String, String) -> String
        let tipPct: (Int) -> String
        let tipFlat: String
        let person: (String, String, String, String, String, String) -> String
        let close: (String) -> String
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

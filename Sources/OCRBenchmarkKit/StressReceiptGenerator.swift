import EsplitealoCore
import Foundation

/// Generates Puerto Rico style fake receipts with exact ground truth for the scanner stress test.
///
/// A receipt is a pure function of `(seed, index)`. The corpus cycles venues and degradations so every combination is
/// covered, and picks layout features at random with venue-specific odds. Features are recorded from the rows that were
/// actually printed, so the failure report groups by what the receipt really contains.
public enum StressReceiptGenerator {
    public static let defaultSeed: UInt64 = 2026

    public static func corpus(count: Int, seed: UInt64 = defaultSeed) -> [StressReceipt] {
        (0..<max(0, count)).map { receipt(index: $0, seed: seed) }
    }

    /// Venue by `index % 4`, degradation by `(index / 4) % 14`: every pair appears once every 56 receipts.
    private static let degradationSchedule: [StressDegradation] = [
        .none, .rotation, .none, .perspective, .skew, .none, .blur,
        .noise, .none, .lowContrast, .shadow, .none, .crumple, .photo,
    ]

    public static func receipt(index: Int, seed: UInt64) -> StressReceipt {
        var rng = StressRNG(seed: seed &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(index + 1) &* 0xBF58_476D_1CE4_E5B9)
        let venue = StressVenue.allCases[index % StressVenue.allCases.count]
        let degradation = degradationSchedule[(index / StressVenue.allCases.count) % degradationSchedule.count]
        let language: StressLanguage = rng.chance(venue == .colmado ? 0.2 : 0.3) ? .english : .spanish
        let plan = FeaturePlan(venue: venue, kitchenSink: index % 24 == 7, rng: &rng)
        var builder = ReceiptBuilder(rng: rng, venue: venue, language: language, plan: plan)
        let built = builder.build()
        let id = "stress-\(seed)-\(StressDates.pad(index, 4))-\(venue.rawValue)-\(degradation.rawValue)"
        return StressReceipt(
            id: id,
            seed: seed,
            index: index,
            venue: venue,
            language: language,
            features: built.features,
            degradation: degradation,
            columns: built.columns,
            rows: built.rows,
            truth: built.truth
        )
    }
}

// MARK: - Plan

/// Which features to try to put on a receipt. A request, not a promise: `ReceiptBuilder` reports what it printed.
private struct FeaturePlan {
    enum DiscountPlan { case none, beforeSubtotal, afterSubtotal }

    var wrappedName = false
    var quantityRow = false
    var leadingQuantity = false
    var inlineUnitPrice = false
    var pricedAddOn = false
    var multiTax = false
    var noTax = false
    var serviceCharge = false
    var discount = DiscountPlan.none
    var negativeLine = false
    var columnHeader = false
    var headerTotal = false
    var cardBlock = false
    var cashPayment = false
    var tipSuggestions = false
    var itemCountLine = false
    var long = false

    init(venue: StressVenue, kitchenSink: Bool, rng: inout StressRNG) {
        // Odds in the order restaurant, colmado, fast food, bar.
        func odds(_ values: [Double]) -> Double {
            values[StressVenue.allCases.firstIndex(of: venue) ?? 0]
        }
        wrappedName = rng.chance(odds([0.45, 0.2, 0.5, 0.3]))
        quantityRow = rng.chance(odds([0.3, 0.25, 0.15, 0.45]))
        leadingQuantity = rng.chance(odds([0.25, 0.3, 0.4, 0.2]))
        inlineUnitPrice = rng.chance(odds([0.1, 0.15, 0.05, 0.1]))
        pricedAddOn = rng.chance(odds([0.15, 0, 0.3, 0.1]))
        multiTax = rng.chance(0.6)
        noTax = !multiTax && rng.chance(0.1)
        serviceCharge = rng.chance(odds([0.5, 0, 0.05, 0.4]))
        let discountRoll = rng.double(0...1)
        let discountOdds = odds([0.2, 0.25, 0.2, 0.1])
        if discountRoll < discountOdds / 2 {
            discount = .beforeSubtotal
        } else if discountRoll < discountOdds {
            discount = .afterSubtotal
        }
        negativeLine = rng.chance(odds([0.08, 0.12, 0.08, 0.05]))
        columnHeader = rng.chance(odds([0.4, 0.3, 0.35, 0.2]))
        headerTotal = rng.chance(odds([0.2, 0.1, 0.3, 0.15]))
        cardBlock = rng.chance(odds([0.6, 0.35, 0.6, 0.6]))
        cashPayment = rng.chance(cardBlock ? 0.1 : 0.6)
        tipSuggestions = rng.chance(odds([0.2, 0, 0, 0.25]))
        itemCountLine = rng.chance(odds([0.1, 0.35, 0.25, 0]))
        long = rng.chance(odds([0.08, 0.3, 0.05, 0.05]))

        if kitchenSink {
            wrappedName = true
            quantityRow = true
            leadingQuantity = true
            inlineUnitPrice = true
            pricedAddOn = venue != .colmado
            multiTax = true
            noTax = false
            serviceCharge = venue == .restaurant || venue == .bar
            discount = .beforeSubtotal
            negativeLine = true
            columnHeader = true
            headerTotal = true
            cardBlock = true
            cashPayment = false
            tipSuggestions = false
            itemCountLine = true
            long = false
        }
        // A mandatory service charge and a tip suggestion table never print together.
        if serviceCharge { tipSuggestions = false }
    }
}

// MARK: - Catalogs

private struct Catalog {
    var items: [String]
    var modifiers: [String]
    var addOns: [(String, Int)]
    var priceRange: ClosedRange<Int>
    var names: [String]
    var streets: [String]
    var metadata: (inout StressRNG) -> String

    static func make(venue: StressVenue, language: StressLanguage) -> Catalog {
        let es = language == .spanish
        let streets = ["Calle Luna 123", "Ave. Central 45", "Carr. 2 Km 14", "Calle del Sol 7", "Plaza Las Flores Local 12"]
        let modifiers = es
            ? ["Término medio", "Sin cebolla", "Extra queso", "Grande", "Pequeño", "Negro", "Marrón", "Con hielo",
               "Sin hielo", "Bien cocido", "Salsa aparte", "Sin sal"]
            : ["Medium rare", "No onions", "Extra cheese", "Large", "Small", "Black", "Brown", "On the rocks",
               "No ice", "Well done", "Sauce on side", "No salt"]
        let addOns: [(String, Int)] = es
            ? [("Extra queso", 150), ("Aguacate", 200), ("Tocino", 175), ("Huevo", 125), ("Salsa de ajo", 75)]
            : [("Extra cheese", 150), ("Avocado", 200), ("Bacon", 175), ("Egg", 125), ("Garlic sauce", 75)]
        let staff = ["Ana", "Luis", "Carmen", "José", "María", "Carlos"]

        switch venue {
        case .restaurant:
            return Catalog(
                items: es
                    ? ["Mofongo de camarones", "Pollo al horno", "Churrasco", "Arroz con gandules", "Tostones",
                       "Ensalada de la casa", "Flan de queso", "Tres leches", "Café con leche", "Piña colada",
                       "Medalla Light", "Agua mineral", "Sopa de pollo", "Pernil asado", "Chuletas kan kan",
                       "Salmón a la plancha", "Pulpo guisado", "Camarones al ajillo con tostones", "Tembleque",
                       "Amarillos", "Pastelón de plátano"]
                    : ["Grilled Chicken", "Caesar Salad", "Fish Tacos", "Cheeseburger", "Fries", "Iced Tea",
                       "Lemonade", "Key Lime Pie", "Ribeye Steak", "Mahi Mahi", "Coffee", "Sparkling Water",
                       "Pasta Alfredo", "Chicken Wings", "Mojito"],
                modifiers: modifiers,
                addOns: addOns,
                priceRange: 600...4200,
                names: ["Restaurante La Ceiba", "El Fogón Boricua", "Casa Coquí Grill", "Bistro del Mar", "La Marina Cantina"],
                streets: streets,
                metadata: { rng in
                    "Mesa \(rng.int(1...40))   \(es ? "Mesero" : "Server"): \(rng.pick(staff))"
                }
            )
        case .colmado:
            return Catalog(
                items: es
                    ? ["Leche Rica 1/2 gal", "Pan sobao", "Arroz Goya 5 lb", "Habichuelas rosadas", "Sazón Goya",
                       "Huevos docena", "Plátanos verdes", "Café Yaucono", "Malta India", "Jugo de naranja",
                       "Queso de papa", "Jamón de cocinar", "Medalla 6 pack", "Hielo 10 lb", "Bacalao",
                       "Pollo entero", "Aceite de oliva", "Azúcar 4 lb", "Papel higiénico", "Detergente",
                       "Galletas Maria", "Yogurt fresa", "Salchichas", "Mantequilla", "Pan de agua"]
                    : ["Milk 1/2 gal", "White Bread", "Rice 5 lb", "Eggs dozen", "Coffee 10 oz", "Orange Juice",
                       "Cheese Slices", "Paper Towels", "Dish Soap", "Bottled Water 24pk", "Chips", "Cereal",
                       "Butter", "Ham", "Soda 2L"],
                modifiers: [],
                addOns: [],
                priceRange: 99...1299,
                names: ["Colmado Los Pinos", "Supermercado Verde", "Minimarket El Paraíso", "Colmado La Esquina"],
                streets: streets,
                metadata: { rng in
                    "Caja \(rng.int(1...6))   \(es ? "Cajero" : "Cashier"): \(rng.pick(staff))"
                }
            )
        case .fastFood:
            return Catalog(
                items: es
                    ? ["Combo #1", "Hamburguesa doble", "Papas fritas", "Pastelillo de carne", "Pastelillo de queso",
                       "Alcapurria", "Bacalaíto", "Refresco 20 oz", "Nuggets 10 pcs", "Batido de vainilla",
                       "Sandwich de pollo", "Tostones", "Sorullitos", "Jugo de parcha", "Empanadilla de pizza",
                       "Café pequeño"]
                    : ["Chicken Sandwich", "Double Burger", "Large Fries", "Nuggets 10 pc", "Milkshake",
                       "Soda 20 oz", "Apple Pie", "Onion Rings", "Wrap Combo", "Iced Coffee"],
                modifiers: modifiers,
                addOns: addOns,
                priceRange: 199...1099,
                names: ["Pastelillos Doña Lola", "Burger Isla", "Frituras El Kiosko", "Pollo Rico Express"],
                streets: streets,
                metadata: { rng in
                    "\(es ? "Orden" : "Order") #\(rng.int(100...999))   \(es ? "Para llevar" : "To go")"
                }
            )
        case .bar:
            return Catalog(
                items: es
                    ? ["Medalla Light", "Presidente", "Ron Don Q & Coca-Cola", "Mojito", "Piña colada",
                       "Tequila shot", "Alitas BBQ", "Nachos", "Tostones con salsa", "Margarita", "Cerveza Corona",
                       "Vodka tonic", "Hielo", "Papas fritas", "Sangría", "Quesadilla"]
                    : ["Draft Beer", "Gin & Tonic", "Whiskey Sour", "Old Fashioned", "Buffalo Wings",
                       "Loaded Nachos", "Margarita", "Rum & Coke", "Pitcher", "Mozzarella Sticks"],
                modifiers: modifiers,
                addOns: addOns,
                priceRange: 400...1600,
                names: ["Bar Luna Llena", "La Taberna del Puerto", "Sports Bar Gol", "Lounge Palmas"],
                streets: streets,
                metadata: { rng in
                    "Tab #\(rng.int(10...99))   \(es ? "Barra" : "Bar") \(rng.int(1...4))"
                }
            )
        }
    }
}

// MARK: - Builder

private enum QuantityStyle {
    case none, prefixX, prefixSpace, quantityRow, inline
}

private struct PlannedItem {
    var name: String
    var modifiers: [String] = []
    var quantity = 1
    var unit: Int
    var style = QuantityStyle.none
    var addOns: [(String, Int)] = []
    var line: Int { quantity * unit }
}

private struct BuiltReceipt {
    var rows: [StressRow]
    var truth: StressBillTruth
    var features: Set<StressFeature>
    var columns: Int
}

private struct ReceiptBuilder {
    var rng: StressRNG
    let venue: StressVenue
    let language: StressLanguage
    let plan: FeaturePlan

    private var es: Bool { language == .spanish }

    init(rng: StressRNG, venue: StressVenue, language: StressLanguage, plan: FeaturePlan) {
        self.rng = rng
        self.venue = venue
        self.language = language
        self.plan = plan
    }

    mutating func build() -> BuiltReceipt {
        let catalog = Catalog.make(venue: venue, language: language)
        let columns = plan.long ? rng.pick([38, 40, 42]) : venue == .fastFood ? rng.pick([32, 34, 36]) : rng.pick([34, 36, 38, 40, 42])
        let itemsDollar = rng.chance(0.4)
        let totalsDollar = rng.chance(0.6)

        // MARK: Plan items

        let itemCount = plan.long ? rng.int(14...24) : rng.int(2...8)
        var planned: [PlannedItem] = []
        let pool = rng.shuffled(catalog.items)
        for index in 0..<itemCount {
            let name = pool[index % pool.count]
            var price = rng.int(catalog.priceRange)
            if rng.chance(0.5) { price = price / 5 * 5 }
            planned.append(PlannedItem(name: name, unit: max(25, price)))
        }
        assignQuantityStyles(&planned, catalog: catalog)

        // MARK: Numbers

        var truthItems: [GroundTruthItem] = []
        var adjustments: [Int] = []
        var itemGroups: [[StressRow]] = []
        let priceWidth = 9
        func money(_ minor: Int, dollar: Bool) -> String {
            StressMoney.format(minor, dollar: dollar)
        }

        let nameMax = columns - priceWidth - 3
        let qtyRowFormat = rng.int(0...3)
        let wrapPriceOnLast = rng.chance(0.3)

        for var item in planned {
            var rows: [StressRow] = []
            let right = money(item.line, dollar: itemsDollar)
            var lead = ""
            switch item.style {
            case .prefixX: lead = "\(item.quantity) x "
            case .prefixSpace: lead = "\(item.quantity) "
            default: break
            }
            var inlineTail = ""
            if item.style == .inline {
                inlineTail = "  \(item.quantity) @ \(StressMoney.format(item.unit, dollar: false))"
                let room = max(6, nameMax - lead.count - inlineTail.count)
                if item.name.count > room {
                    item.name = String(item.name.prefix(room)).trimmingCharacters(in: .whitespaces)
                }
            }
            let left = lead + item.name + inlineTail
            let parts = left.count > nameMax ? StressWrap.split(left, maxLength: nameMax) : [left]

            if parts.count > 1, wrapPriceOnLast, item.modifiers.isEmpty {
                // The name wraps and the price sits on its last row.
                for (offset, part) in parts.enumerated() {
                    let last = offset == parts.count - 1
                    rows.append(StressRow(last ? .item : .modifier, part, right: last ? right : nil))
                }
            } else {
                rows.append(StressRow(.item, parts[0], right: right))
                for part in parts.dropFirst() {
                    rows.append(StressRow(.modifier, part))
                }
                for modifier in item.modifiers {
                    rows.append(StressRow(.modifier, modifier, indent: rng.chance(0.5) ? 0 : 2))
                }
            }
            if item.style == .quantityRow {
                let unit = StressMoney.format(item.unit, dollar: true)
                let plain = StressMoney.format(item.unit, dollar: false)
                let text: String
                switch qtyRowFormat {
                case 0: text = "(\(item.quantity) x \(unit))"
                case 1: text = "\(item.quantity) x \(unit)"
                case 2: text = "\(item.quantity) @ \(plain)"
                default: text = "(\(item.quantity) x \(plain))"
                }
                rows.append(StressRow(.quantityRow, text, indent: rng.chance(0.5) ? 0 : 2))
            }
            truthItems.append(
                GroundTruthItem(
                    name: ([item.name] + item.modifiers).joined(separator: " "),
                    quantity: item.quantity,
                    lineTotalMinor: item.line
                )
            )
            for addOn in item.addOns {
                rows.append(StressRow(.addOn, "+ \(addOn.0)", right: money(addOn.1, dollar: itemsDollar), indent: 2))
                truthItems.append(GroundTruthItem(name: addOn.0, quantity: 1, lineTotalMinor: addOn.1))
            }
            itemGroups.append(rows)
        }

        // A returned or voided line sits between two items, with a negative price.
        var hasNegativeLine = false
        if plan.negativeLine, planned.count >= 2, let basis = planned.randomElementUsing(&rng) {
            let label = (es ? ["Devolución", "Anulado"] : ["Return", "Void"])[rng.int(0...1)]
            let formatted = StressMoney.negative(basis.unit, style: rng.int(0...3), dollar: itemsDollar)
            let position = rng.int(1...itemGroups.count)
            let room = max(6, nameMax - label.count - 1)
            let name = basis.name.count > room ? String(basis.name.prefix(room)) : basis.name
            itemGroups.insert([StressRow(.item, "\(label) \(name)", right: formatted)], at: position)
            adjustments.append(-basis.unit)
            hasNegativeLine = true
        }
        let itemRowsOut = itemGroups.flatMap { $0 }

        let itemsSum = truthItems.reduce(0) { $0 + $1.lineTotalMinor }
        let grossAfterNegatives = itemsSum + adjustments.reduce(0, +)

        // MARK: Discount

        var discountRow: StressRow?
        var discountMinor = 0
        var discountBefore = false
        if plan.discount != .none, grossAfterNegatives >= 600 {
            let percent = rng.chance(0.4)
            let label: String
            if percent {
                discountMinor = (grossAfterNegatives * 10 + 50) / 100
                label = es ? "Descuento 10%" : "Discount 10%"
            } else {
                discountMinor = rng.int(1...4) * 100 + (rng.chance(0.5) ? 50 : 0)
                label = (es ? ["Descuento", "Cupón", "Descuento empleado"] : ["Discount", "Coupon", "Promo"])[rng.int(0...2)]
            }
            discountMinor = min(discountMinor, grossAfterNegatives / 2)
            discountRow = StressRow(
                .discount,
                label,
                right: StressMoney.negative(discountMinor, style: rng.int(0...3), dollar: totalsDollar)
            )
            adjustments.append(-discountMinor)
            discountBefore = plan.discount == .beforeSubtotal
        }

        let base = grossAfterNegatives - discountMinor
        let subtotalPrinted = discountBefore ? base : grossAfterNegatives

        // MARK: Taxes and service charge

        var taxRows: [StressRow] = []
        var taxLines: [Int] = []
        if plan.multiTax {
            let pair = taxLabelPair(columns: columns)
            let state = (base * 105 + 500) / 1000
            let municipal = (base + 50) / 100
            taxLines = [state, municipal]
            taxRows = [
                StressRow(.tax, pair.0, right: money(state, dollar: totalsDollar)),
                StressRow(.tax, pair.1, right: money(municipal, dollar: totalsDollar)),
            ]
        } else if !plan.noTax {
            let combined = (base * 115 + 500) / 1000
            taxLines = [combined]
            let label = es ? rng.pick(["IVU 11.5%", "Impuesto 11.5%", "IVU (11.5%)"]) : rng.pick(["Sales Tax 11.5%", "Tax 11.5%"])
            taxRows = [StressRow(.tax, label, right: money(combined, dollar: totalsDollar))]
        }

        var serviceRow: StressRow?
        var serviceMinor = 0
        if plan.serviceCharge {
            let percent = rng.pick([15, 18, 20])
            serviceMinor = (base * percent + 50) / 100
            let labels = es
                ? ["Cargo por servicio \(percent)%", "Servicio \(percent)%", "Propina \(percent)%", "Propina incluida \(percent)%"]
                : ["Service Charge \(percent)%", "Gratuity \(percent)%", "Service \(percent)%", "Auto Gratuity \(percent)%"]
            serviceRow = StressRow(.tip, rng.pick(labels), right: money(serviceMinor, dollar: totalsDollar))
        }

        let taxSum = taxLines.reduce(0, +)
        let total = base + taxSum + serviceMinor

        // MARK: Layout

        var rows: [StressRow] = []
        rows += headerRows(catalog: catalog, columns: columns, total: total, totalsDollar: totalsDollar)

        var hasColumnHeader = false
        if plan.columnHeader {
            let headers = es
                ? [("Artículo", "Precio"), ("Cant  Descripción", "Importe"), ("Items", "Price")]
                : [("Items", "Price"), ("Qty Item", "Amount"), ("Description", "Price")]
            let header = rng.pick(headers)
            rows.append(StressRow(.columnHeader, header.0, right: header.1))
            hasColumnHeader = true
        }
        rows += itemRowsOut

        var hasItemCount = false
        if plan.itemCountLine {
            let count = planned.count
            let label = es ? rng.pick(["Artículos: \(count)", "Total de artículos: \(count)", "Items: \(count)"])
                           : rng.pick(["Items: \(count)", "Total items: \(count)", "Item count: \(count)"])
            rows.append(StressRow(.itemCount, label))
            hasItemCount = true
        }

        let subtotalLabel = es ? rng.pick(["Subtotal", "SUBTOTAL", "Sub-Total"]) : rng.pick(["Subtotal", "SUBTOTAL", "Sub Total"])
        if discountBefore, let discountRow { rows.append(discountRow) }
        rows.append(StressRow(.subtotal, subtotalLabel, right: money(subtotalPrinted, dollar: totalsDollar)))
        if !discountBefore, let discountRow { rows.append(discountRow) }
        if let serviceRow, rng.chance(0.4) {
            rows.append(serviceRow)
            rows += taxRows
        } else {
            rows += taxRows
            if let serviceRow { rows.append(serviceRow) }
        }
        let totalLabel = es ? rng.pick(["Total", "TOTAL", "Total a pagar"]) : rng.pick(["Total", "TOTAL", "Total Due"])
        rows.append(
            StressRow(.total, totalLabel, right: money(total, dollar: totalsDollar), style: rng.chance(0.3) ? .bold : .normal)
        )

        var hasTipSuggestions = false
        if plan.tipSuggestions {
            hasTipSuggestions = true
            rows += tipSuggestionRows(base: base, dollar: totalsDollar)
        }

        var hasCard = false
        var hasCash = false
        if plan.cardBlock {
            hasCard = true
            rows.append(StressRow(.blank))
            rows += cardRows(total: total, dollar: totalsDollar)
        } else if plan.cashPayment {
            hasCash = true
            rows.append(StressRow(.blank))
            rows += cashRows(total: total)
        }
        rows += footerRows()

        // MARK: Truth and features

        let truth = StressBillTruth(
            items: truthItems,
            adjustmentsMinor: adjustments,
            subtotalMinor: subtotalPrinted,
            taxLinesMinor: taxLines,
            tipMinor: serviceMinor,
            totalMinor: total
        )

        var features: Set<StressFeature> = []
        if rows.contains(where: { $0.role == .modifier }) { features.insert(.wrappedName) }
        if rows.contains(where: { $0.role == .quantityRow }) { features.insert(.quantityRow) }
        if planned.contains(where: { $0.style == .prefixX || $0.style == .prefixSpace }) { features.insert(.leadingQuantity) }
        if planned.contains(where: { $0.style == .inline }) { features.insert(.inlineUnitPrice) }
        if rows.contains(where: { $0.role == .addOn }) { features.insert(.pricedAddOn) }
        if taxLines.count >= 2 { features.insert(.multiTax) }
        if taxLines.count == 1 { features.insert(.singleTax) }
        if serviceRow != nil { features.insert(.serviceCharge) }
        if discountRow != nil { features.insert(.discount) }
        if hasNegativeLine { features.insert(.negativeLine) }
        if hasColumnHeader { features.insert(.columnHeader) }
        if rows.contains(where: { $0.role == .headerTotal }) { features.insert(.headerTotal) }
        if hasCard { features.insert(.cardBlock) }
        if hasCash { features.insert(.cashPayment) }
        if hasTipSuggestions { features.insert(.tipSuggestions) }
        if hasItemCount { features.insert(.itemCountLine) }
        if planned.count >= 14 { features.insert(.longReceipt) }
        if language == .english { features.insert(.englishLabels) }

        return BuiltReceipt(rows: rows, truth: truth, features: features, columns: columns)
    }

    // MARK: Item styles

    private mutating func assignQuantityStyles(_ items: inout [PlannedItem], catalog: Catalog) {
        var wanted: [QuantityStyle] = []
        if plan.quantityRow { wanted.append(.quantityRow) }
        if plan.leadingQuantity { wanted.append(rng.chance(0.5) ? .prefixX : .prefixSpace) }
        if plan.inlineUnitPrice { wanted.append(.inline) }
        let indices = rng.shuffled(Array(items.indices))
        for (offset, style) in wanted.enumerated() where offset < indices.count {
            items[indices[offset]].style = style
            items[indices[offset]].quantity = rng.int(2...4)
        }
        // Other items sometimes have a quantity too, in the styles this receipt already uses.
        if !wanted.isEmpty {
            for index in indices.dropFirst(wanted.count) where rng.chance(0.2) {
                items[index].style = rng.pick(wanted)
                items[index].quantity = rng.int(2...3)
            }
        }
        if plan.wrappedName, !catalog.modifiers.isEmpty {
            let forced = indices.last ?? 0
            for index in items.indices where index == forced || rng.chance(0.2) {
                let count = rng.chance(0.25) ? 2 : 1
                items[index].modifiers = Array(rng.shuffled(catalog.modifiers).prefix(count))
            }
        }
        if plan.pricedAddOn, !catalog.addOns.isEmpty, let first = indices.first {
            for index in items.indices where index == first || rng.chance(0.15) {
                items[index].addOns = [rng.pick(catalog.addOns)]
            }
        }
    }

    // MARK: Header

    private mutating func headerRows(catalog: Catalog, columns: Int, total: Int, totalsDollar: Bool) -> [StressRow] {
        var rows: [StressRow] = []
        rows.append(StressRow(.header, rng.pick(catalog.names), centered: true, style: rng.chance(0.5) ? .bold : .normal))
        rows.append(StressRow(.header, rng.pick(catalog.streets), centered: true))
        let city = rng.pick(["San Juan, PR 00901", "Bayamón, PR 00956", "Ponce, PR 00717", "Carolina, PR 00979",
                             "Mayagüez, PR 00680", "Caguas, PR 00725", "San Juan PR"])
        rows.append(StressRow(.header, city, centered: true))
        let phone = rng.chance(0.5) ? "Tel. 787-555-01\(rng.int(10...99))" : "Tel: (787) 555-01\(rng.int(10...99))"
        rows.append(StressRow(.header, phone, centered: true))
        if plan.headerTotal {
            let amount = StressMoney.format(total, dollar: true)
            if rng.chance(0.5) {
                rows.append(StressRow(.headerTotal, "TOTAL", centered: true, style: .large))
                rows.append(StressRow(.headerTotal, amount, centered: true, style: .large))
            } else {
                rows.append(StressRow(.headerTotal, "TOTAL \(amount)", centered: true, style: .large))
            }
        }
        rows.append(StressRow(.blank))
        rows.append(StressRow(.metadata, catalog.metadata(&rng)))
        rows.append(StressRow(.metadata, StressDates.line(&rng)))
        rows.append(StressRow(.blank))
        return rows
    }

    // MARK: Taxes

    private mutating func taxLabelPair(columns: Int) -> (String, String) {
        let pairs = es
            ? [("IVU Estatal 10.5%", "IVU Municipal 1%"), ("Impuesto Estatal (10.5%)", "Impuesto Municipal (1%)"),
               ("IVU estatal 10.5%", "IVU municipal 1.0%")]
            : [("State Tax (10.5%)", "Municipal Tax (1%)"), ("PUERTO RICO STATE TAX (10.5%)", "CITY TAX (1%)"),
               ("Sales Tax 10.5%", "Municipal Tax 1%")]
        // A label must leave room for the price column.
        let fitting = pairs.filter { max($0.0.count, $0.1.count) + 11 <= columns }
        return rng.pick(fitting.isEmpty ? pairs.suffix(1).map { $0 } : fitting)
    }

    // MARK: Payment blocks

    private mutating func tipSuggestionRows(base: Int, dollar: Bool) -> [StressRow] {
        let percents = [15, 18, 20]
        let amounts = percents.map { (base * $0 + 50) / 100 }
        var rows: [StressRow] = [StressRow(.blank)]
        if rng.chance(0.5) {
            rows.append(StressRow(.tipTable, es ? "Propina sugerida" : "Suggested Tip", centered: true))
            for (percent, amount) in zip(percents, amounts) {
                rows.append(StressRow(.tipTable, "\(percent)%", right: StressMoney.format(amount, dollar: dollar)))
            }
        } else {
            for (percent, amount) in zip(percents, amounts) {
                let label = es ? "Propina sugerida \(percent)%:" : "Suggested tip \(percent)%:"
                rows.append(StressRow(.tipTable, label, right: StressMoney.format(amount, dollar: dollar)))
            }
        }
        return rows
    }

    private mutating func cardRows(total: Int, dollar: Bool) -> [StressRow] {
        let amount = StressMoney.format(total, dollar: true)
        var rows: [StressRow] = [StressRow(.card, es ? "Récord de transacción" : "Transaction Record", centered: true)]
        let brand = rng.pick(["Visa", "Mastercard", "Visa Debit"])
        rows.append(StressRow(.card, "\(brand) ****\(rng.int(1000...9999))", right: amount))
        rows.append(StressRow(.card, "AUTHORIZED"))
        rows.append(StressRow(.card, StressDates.line(&rng)))
        rows.append(StressRow(.card, "AID: A0000000031010"))
        rows.append(StressRow(.card, "MID: 0000\(rng.int(100000...999999))  TID: \(rng.int(10000000...99999999))"))
        rows.append(StressRow(.card, "TSI: 0000  TVR: 0000000000"))
        rows.append(StressRow(.card, "Auth: \(rng.int(100000...999999))  Ref: \(rng.int(1000...9999))"))
        if rng.chance(0.5) { rows.append(StressRow(.card, "AMOUNT", right: amount)) }
        if rng.chance(0.3) { rows.append(StressRow(.card, "Verification not required")) }
        if venue == .restaurant || venue == .bar, rng.chance(0.4) {
            rows.append(StressRow(.card, es ? "Propina: ________" : "Tip: ________"))
            rows.append(StressRow(.card, "Total: ________"))
        }
        rows.append(StressRow(.card, "Receipt: #\(rng.int(1...9))-\(StressDates.pad(rng.int(1...99999), 5))"))
        return rows
    }

    private mutating func cashRows(total: Int) -> [StressRow] {
        let tendered = (total / 500 + 1) * 500 + (rng.chance(0.4) ? 500 : 0)
        let cash = es ? "Efectivo" : "Cash"
        let change = es ? "Cambio" : "Change"
        return [
            StressRow(.payment, cash, right: StressMoney.format(tendered, dollar: true)),
            StressRow(.payment, change, right: StressMoney.format(tendered - total, dollar: true)),
        ]
    }

    private mutating func footerRows() -> [StressRow] {
        let lines = es
            ? ["¡Gracias por su visita!", "Vuelva pronto", "No se aceptan devoluciones", "¡Muchas gracias!"]
            : ["Thank you!", "Please come again", "No returns without receipt"]
        var rows: [StressRow] = [StressRow(.blank)]
        rows.append(StressRow(.footer, rng.pick(lines), centered: true))
        return rows
    }
}

// MARK: - Helpers

enum StressMoney {
    static func format(_ minor: Int, dollar: Bool) -> String {
        let value = abs(minor)
        let text = "\(value / 100)." + StressDates.pad(value % 100, 2)
        return (minor < 0 ? "-" : "") + (dollar ? "$" : "") + text
    }

    /// A negative amount, printed one of four ways: `-2.00`, `-$2.00`, `(2.00)`, `2.00-`.
    static func negative(_ minor: Int, style: Int, dollar: Bool) -> String {
        let magnitude = format(abs(minor), dollar: dollar)
        switch style {
        case 0: return "-" + magnitude
        case 1: return "-" + format(abs(minor), dollar: true)
        case 2: return "(" + magnitude + ")"
        default: return magnitude + "-"
        }
    }
}

enum StressWrap {
    /// Greedy word wrap; a single word longer than the limit stays on one row.
    static func split(_ text: String, maxLength: Int) -> [String] {
        var rows: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            if current.isEmpty {
                current = String(word)
            } else if current.count + 1 + word.count <= maxLength {
                current += " " + word
            } else {
                rows.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}

enum StressDates {
    static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }

    static func line(_ rng: inout StressRNG) -> String {
        let day = rng.int(1...28)
        let month = rng.int(1...12)
        let hour = rng.int(8...21)
        let minute = rng.int(0...59)
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        let meridiem = hour < 12 ? "AM" : "PM"
        switch rng.int(0...3) {
        case 0: return "\(pad(day, 2))/\(pad(month, 2))/2026 \(pad(hour, 2)):\(pad(minute, 2))"
        case 1: return "\(names[month - 1]) \(day), 2026 \(pad(twelve, 2)):\(pad(minute, 2))\(meridiem)"
        case 2: return "2026-\(pad(month, 2))-\(pad(day, 2)) \(pad(hour, 2)):\(pad(minute, 2))"
        default: return "\(pad(month, 2))/\(pad(day, 2))/2026 \(twelve):\(pad(minute, 2)) \(meridiem)"
        }
    }
}

private extension Array {
    func randomElementUsing(_ rng: inout StressRNG) -> Element? {
        isEmpty ? nil : self[rng.int(0...(count - 1))]
    }
}

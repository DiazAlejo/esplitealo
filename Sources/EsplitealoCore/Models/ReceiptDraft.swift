import Foundation

public struct DraftAmount: Equatable, Sendable, Codable {
    public var minorUnits: Int
    public var sourceRect: PixelRect?
    public var needsAttention: Bool

    public init(minorUnits: Int, sourceRect: PixelRect? = nil, needsAttention: Bool = false) {
        self.minorUnits = minorUnits
        self.sourceRect = sourceRect
        self.needsAttention = needsAttention
    }
}

public enum ItemFlag: String, Equatable, Sendable, Codable {
    case priceOnNextRow
    case priceOnPreviousRow
    case quantityMismatch
    case zeroPrice
    case formatGuessed
    case needsReview
}

public struct DraftItem: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var quantity: Int
    public var lineTotal: DraftAmount
    public var unitPrice: DraftAmount?
    public var notes: [String]
    public var flags: Set<ItemFlag>
    public var sourceRect: PixelRect?

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        lineTotal: DraftAmount,
        unitPrice: DraftAmount? = nil,
        notes: [String] = [],
        flags: Set<ItemFlag> = [],
        sourceRect: PixelRect? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = max(1, quantity)
        self.lineTotal = lineTotal
        self.unitPrice = unitPrice
        self.notes = notes
        self.flags = flags
        self.sourceRect = sourceRect
    }
}

public struct NumberFormat: Equatable, Sendable, Codable {
    public var decimalSeparator: Character
    public var groupSeparator: Character
    public var fractionDigits: Int
    public var isGuessed: Bool

    public init(
        decimalSeparator: Character = ".",
        groupSeparator: Character = ",",
        fractionDigits: Int = 2,
        isGuessed: Bool = false
    ) {
        self.decimalSeparator = decimalSeparator
        self.groupSeparator = groupSeparator
        self.fractionDigits = fractionDigits
        self.isGuessed = isGuessed
    }

    /// US dollars with cents (Puerto Rico default).
    public static let usdCents = NumberFormat(decimalSeparator: ".", groupSeparator: ",", fractionDigits: 2)

    private enum CodingKeys: String, CodingKey {
        case decimalSeparator, groupSeparator, fractionDigits, isGuessed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decimal = try container.decode(String.self, forKey: .decimalSeparator)
        let group = try container.decode(String.self, forKey: .groupSeparator)
        guard let d = decimal.first, let g = group.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "separator"))
        }
        decimalSeparator = d
        groupSeparator = g
        fractionDigits = try container.decode(Int.self, forKey: .fractionDigits)
        isGuessed = try container.decode(Bool.self, forKey: .isGuessed)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(decimalSeparator), forKey: .decimalSeparator)
        try container.encode(String(groupSeparator), forKey: .groupSeparator)
        try container.encode(fractionDigits, forKey: .fractionDigits)
        try container.encode(isGuessed, forKey: .isGuessed)
    }
}

public struct DraftAdjustment: Equatable, Sendable, Codable {
    public var label: String
    public var amount: DraftAmount

    public init(label: String, amount: DraftAmount) {
        self.label = label
        self.amount = amount
    }
}

public enum ReceiptIssue: Equatable, Sendable, Codable {
    case itemsDoNotMatchSubtotal(itemsSum: Int, printed: Int)
    case totalsDoNotAddUp(expected: Int, printed: Int)
    case numberFormatGuessed(NumberFormat)
    case noTotalFound
    case noItemsFound
    case unparsedPriceRow(String)
}

public struct ReceiptDraft: Equatable, Sendable, Codable {
    public var items: [DraftItem]
    public var subtotal: DraftAmount?
    public var tax: DraftAmount?
    public var tip: DraftAmount?
    public var total: DraftAmount?
    public var adjustments: [DraftAdjustment]
    public var numberFormat: NumberFormat
    /// What the parser was unsure about, for the Review screen. Dismissed ones are kept; see `activeWarnings`.
    public var warnings: [ReceiptWarning]
    public var issues: [ReceiptIssue]
    public var reconciles: Bool

    /// The warnings the user has not yet fixed or accepted.
    public var activeWarnings: [ReceiptWarning] { warnings.filter { !$0.isDismissed } }

    public init(
        items: [DraftItem] = [],
        subtotal: DraftAmount? = nil,
        tax: DraftAmount? = nil,
        tip: DraftAmount? = nil,
        total: DraftAmount? = nil,
        adjustments: [DraftAdjustment] = [],
        numberFormat: NumberFormat = .usdCents,
        warnings: [ReceiptWarning] = [],
        issues: [ReceiptIssue] = [],
        reconciles: Bool = false
    ) {
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.total = total
        self.adjustments = adjustments
        self.numberFormat = numberFormat
        self.warnings = warnings
        self.issues = issues
        self.reconciles = reconciles
    }

    private enum CodingKeys: String, CodingKey {
        case items, subtotal, tax, tip, total, adjustments, numberFormat, warnings, issues, reconciles
    }

    /// `warnings` arrived with bill schema 2; a draft written before has none.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([DraftItem].self, forKey: .items)
        subtotal = try container.decodeIfPresent(DraftAmount.self, forKey: .subtotal)
        tax = try container.decodeIfPresent(DraftAmount.self, forKey: .tax)
        tip = try container.decodeIfPresent(DraftAmount.self, forKey: .tip)
        total = try container.decodeIfPresent(DraftAmount.self, forKey: .total)
        adjustments = try container.decode([DraftAdjustment].self, forKey: .adjustments)
        numberFormat = try container.decode(NumberFormat.self, forKey: .numberFormat)
        warnings = try container.decodeIfPresent([ReceiptWarning].self, forKey: .warnings) ?? []
        issues = try container.decode([ReceiptIssue].self, forKey: .issues)
        reconciles = try container.decode(Bool.self, forKey: .reconciles)
    }
}

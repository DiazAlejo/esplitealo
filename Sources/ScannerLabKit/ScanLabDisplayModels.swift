import Foundation

public struct ScanLabRecognizedLineDisplay: Equatable, Sendable {
    public var text: String
    public var confidenceLabel: String

    public init(text: String, confidenceLabel: String) {
        self.text = text
        self.confidenceLabel = confidenceLabel
    }
}

public struct ScanLabItemDisplay: Equatable, Sendable {
    public var description: String
    public var quantity: Int
    public var priceLabel: String
    public var flags: [String]

    public init(description: String, quantity: Int, priceLabel: String, flags: [String]) {
        self.description = description
        self.quantity = quantity
        self.priceLabel = priceLabel
        self.flags = flags
    }
}

public struct ScanLabAmountDisplay: Equatable, Sendable {
    public var label: String
    public var needsAttention: Bool

    public init(label: String, needsAttention: Bool) {
        self.label = label
        self.needsAttention = needsAttention
    }
}

public struct ScanLabDisplayResult: Equatable, Sendable {
    public var recognizedLines: [ScanLabRecognizedLineDisplay]
    public var rebuiltRows: [String]
    public var items: [ScanLabItemDisplay]
    public var subtotal: ScanLabAmountDisplay?
    public var tax: ScanLabAmountDisplay?
    public var tip: ScanLabAmountDisplay?
    public var total: ScanLabAmountDisplay?
    public var reconciles: Bool
    public var reconciliationSummary: String
    public var issues: [String]
    public var flaggedRows: [String]
    public var ocrDurationMilliseconds: Int?

    public init(
        recognizedLines: [ScanLabRecognizedLineDisplay],
        rebuiltRows: [String],
        items: [ScanLabItemDisplay],
        subtotal: ScanLabAmountDisplay?,
        tax: ScanLabAmountDisplay?,
        tip: ScanLabAmountDisplay?,
        total: ScanLabAmountDisplay?,
        reconciles: Bool,
        reconciliationSummary: String,
        issues: [String],
        flaggedRows: [String],
        ocrDurationMilliseconds: Int?
    ) {
        self.recognizedLines = recognizedLines
        self.rebuiltRows = rebuiltRows
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.total = total
        self.reconciles = reconciles
        self.reconciliationSummary = reconciliationSummary
        self.issues = issues
        self.flaggedRows = flaggedRows
        self.ocrDurationMilliseconds = ocrDurationMilliseconds
    }
}

import EsplitealoCore
import Foundation

/// The kind of business a stress receipt imitates; picks menu, header and footer vocabulary.
public enum StressVenue: String, CaseIterable, Codable, Sendable {
    case restaurant
    case colmado
    case fastFood
    case bar
}

public enum StressLanguage: String, Codable, Sendable {
    case spanish
    case english
}

/// A layout feature a receipt actually exercises. Features are derived from the printed rows, so they are also the
/// grouping keys of the failure report.
public enum StressFeature: String, CaseIterable, Codable, Sendable {
    /// An item name over several rows: variant or modifier rows, or a long name that wraps.
    case wrappedName
    /// A `(N x $price)` row under an item.
    case quantityRow
    /// `2 x Name` or `2 Name` before the item name.
    case leadingQuantity
    /// `Name  3 @ 3.50  10.50` on one row.
    case inlineUnitPrice
    /// `+ Extra queso 1.50` add-on rows with their own price.
    case pricedAddOn
    /// State and municipal tax on separate lines.
    case multiTax
    /// One tax line for the combined rate (or none).
    case singleTax
    /// Mandatory service charge or tip included in the total.
    case serviceCharge
    /// A discount row between the items and the totals.
    case discount
    /// A negative line (return, void) among the items.
    case negativeLine
    /// `Items  Price` style column headings.
    case columnHeader
    /// The total printed large at the top of the receipt.
    case headerTotal
    /// Card terminal block (AID, MID, TSI, authorization, receipt number) after the total.
    case cardBlock
    case cashPayment
    case tipSuggestions
    /// `Items: 5` count line before the subtotal.
    case itemCountLine
    case longReceipt
    case englishLabels
}

/// How the receipt image is degraded after rendering.
public enum StressDegradation: String, CaseIterable, Codable, Sendable {
    case none
    case rotation
    case skew
    case perspective
    case blur
    case noise
    case lowContrast
    case shadow
    case crumple
    /// A handheld photo: mild rotation, perspective, shadow and sensor noise together.
    case photo
}

/// One printed row. `left` and `right` are laid out on a monospace grid; `right` is the price column.
public struct StressRow: Equatable, Codable, Sendable {
    public enum Role: String, Codable, Sendable {
        case header, metadata, blank, headerTotal, columnHeader
        case item, modifier, quantityRow, addOn, itemCount
        case subtotal, discount, tax, tip, total, tipTable
        case payment, card, footer
    }

    public enum Style: String, Codable, Sendable {
        case normal, bold, large
    }

    public var role: Role
    public var left: String
    public var right: String?
    public var centered: Bool
    public var style: Style
    public var indent: Int

    public init(
        _ role: Role,
        _ left: String = "",
        right: String? = nil,
        centered: Bool = false,
        style: Style = .normal,
        indent: Int = 0
    ) {
        self.role = role
        self.left = left
        self.right = right
        self.centered = centered
        self.style = style
        self.indent = indent
    }

    /// Large rows are drawn 1.5x wider, so they have fewer character columns.
    public func effectiveColumns(_ columns: Int) -> Int {
        style == .large ? max(8, Int(Double(columns) / 1.5)) : columns
    }

    /// The row as one monospace line, padded so `right` ends at the last column.
    public func text(columns: Int) -> String {
        let width = effectiveColumns(columns)
        let leftText = String(repeating: " ", count: indent) + left
        if let right {
            let gap = max(2, width - leftText.count - right.count)
            return leftText + String(repeating: " ", count: gap) + right
        }
        if centered {
            return String(repeating: " ", count: max(0, (width - leftText.count) / 2)) + leftText
        }
        return leftText
    }
}

/// Exact answers for a stress receipt, in minor units (USD cents).
public struct StressBillTruth: Codable, Equatable, Sendable {
    public var items: [GroundTruthItem]
    /// Discounts and other negative lines (negative cents), kept as manual adjustments.
    public var adjustmentsMinor: [Int]
    /// The printed subtotal (net of a discount printed before it).
    public var subtotalMinor: Int
    public var taxLinesMinor: [Int]
    public var tipMinor: Int
    public var totalMinor: Int

    public var taxMinor: Int { taxLinesMinor.reduce(0, +) }
    public var itemsSumMinor: Int { items.reduce(0) { $0 + $1.lineTotalMinor } }
    public var adjustmentsSumMinor: Int { adjustmentsMinor.reduce(0, +) }

    public init(
        items: [GroundTruthItem],
        adjustmentsMinor: [Int] = [],
        subtotalMinor: Int,
        taxLinesMinor: [Int] = [],
        tipMinor: Int = 0,
        totalMinor: Int
    ) {
        self.items = items
        self.adjustmentsMinor = adjustmentsMinor
        self.subtotalMinor = subtotalMinor
        self.taxLinesMinor = taxLinesMinor
        self.tipMinor = tipMinor
        self.totalMinor = totalMinor
    }
}

public struct StressReceipt: Codable, Equatable, Sendable {
    public var id: String
    public var seed: UInt64
    public var index: Int
    public var venue: StressVenue
    public var language: StressLanguage
    public var features: Set<StressFeature>
    public var degradation: StressDegradation
    /// Character columns of the monospace grid.
    public var columns: Int
    public var rows: [StressRow]
    public var truth: StressBillTruth

    /// Report grouping keys: venue, degradation and every feature, sorted.
    public var tags: [String] {
        (["venue:\(venue.rawValue)", "degradation:\(degradation.rawValue)"] + features.map { "feature:\($0.rawValue)" })
            .sorted()
    }

    /// Each row as the single monospace line it is drawn as.
    public var plainRows: [String] {
        rows.map { $0.text(columns: columns) }
    }

    /// Truth in the shape the existing benchmark scorer reads.
    public var groundTruth: ReceiptGroundTruth {
        ReceiptGroundTruth(
            id: id,
            items: truth.items,
            subtotalMinor: truth.subtotalMinor,
            taxMinor: truth.taxLinesMinor.isEmpty ? nil : truth.taxMinor,
            tipMinor: truth.tipMinor == 0 ? nil : truth.tipMinor,
            totalMinor: truth.totalMinor,
            expectsReconciles: truth.itemsSumMinor + truth.adjustmentsSumMinor == truth.subtotalMinor
        )
    }
}

/// Small deterministic generator (SplitMix64) so a seed always gives the same corpus.
struct StressRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func double(_ range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func chance(_ probability: Double) -> Bool {
        double(0...1) < probability
    }

    mutating func pick<T>(_ values: [T]) -> T {
        values[int(0...(values.count - 1))]
    }

    mutating func shuffled<T>(_ values: [T]) -> [T] {
        var result = values
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            result.swapAt(index, int(0...index))
        }
        return result
    }
}

import Foundation

public enum BenchmarkFailureReason: String, Codable, Equatable, Sendable {
    case missedItems
    case extraItems
    case wrongItemPrices
    case wrongDescriptions
    case wrongQuantities
    case subtotalMismatch
    case taxMismatch
    case tipMismatch
    case totalMismatch
    case reconciliationMismatch
    case noItemsParsed
}

public struct ReceiptPerReceiptScore: Codable, Equatable, Sendable {
    public var receiptID: String
    public var itemRecall: Double
    public var itemPrecision: Double
    public var itemPriceAccuracy: Double
    public var itemDescriptionAccuracy: Double
    public var quantityAccuracy: Double
    public var subtotalCorrect: Bool
    public var taxCorrect: Bool
    public var totalCorrect: Bool
    public var reconciliationAgrees: Bool
    public var failureReasons: [BenchmarkFailureReason]
}

public struct BenchmarkAggregateMetrics: Codable, Equatable, Sendable {
    public var receiptCount: Int
    public var itemRecall: Double
    public var itemPrecision: Double
    public var itemPriceAccuracy: Double
    public var itemDescriptionAccuracy: Double
    public var quantityAccuracy: Double
    public var subtotalIdentificationRate: Double
    public var taxIdentificationRate: Double
    public var totalIdentificationRate: Double
    public var reconciliationAgreementRate: Double
}

public struct ReceiptBenchmarkScorer: Sendable {
    public static let descriptionSimilarityThreshold = 0.7

    public init() {}

    public func score(draft: ReceiptDraft, groundTruth: ReceiptGroundTruth) -> ReceiptPerReceiptScore {
        if draft.items.isEmpty, !groundTruth.items.isEmpty {
            return ReceiptPerReceiptScore(
                receiptID: groundTruth.id,
                itemRecall: 0,
                itemPrecision: 0,
                itemPriceAccuracy: 0,
                itemDescriptionAccuracy: 0,
                quantityAccuracy: 0,
                subtotalCorrect: fieldMatches(expected: groundTruth.subtotalMinor, actual: draft.subtotal?.minorUnits),
                taxCorrect: fieldMatches(expected: groundTruth.taxMinor, actual: draft.tax?.minorUnits),
                totalCorrect: fieldMatches(expected: groundTruth.totalMinor, actual: draft.total?.minorUnits),
                reconciliationAgrees: reconciliationMatches(draft: draft, groundTruth: groundTruth),
                failureReasons: [.noItemsParsed, .missedItems]
            )
        }

        let pairs = matchItems(parsed: draft.items, truth: groundTruth.items)
        let matchedTruth = pairs.filter { $0.truth != nil }.count
        let recall = groundTruth.items.isEmpty ? 1.0 : Double(matchedTruth) / Double(groundTruth.items.count)
        let precision = draft.items.isEmpty ? (groundTruth.items.isEmpty ? 1.0 : 0.0) : Double(matchedTruth) / Double(draft.items.count)

        var priceHits = 0
        var descHits = 0
        var qtyHits = 0
        for pair in pairs {
            guard let truth = pair.truth else { continue }
            priceHits += 1
            if StringSimilarity.normalized(pair.parsed.name, truth.name) >= Self.descriptionSimilarityThreshold {
                descHits += 1
            }
            if pair.parsed.quantity == truth.quantity {
                qtyHits += 1
            }
        }
        let priceAcc = matchedTruth == 0 ? 0.0 : Double(priceHits) / Double(matchedTruth)
        let descAcc = matchedTruth == 0 ? 0.0 : Double(descHits) / Double(matchedTruth)
        let qtyAcc = matchedTruth == 0 ? 0.0 : Double(qtyHits) / Double(matchedTruth)

        var reasons: [BenchmarkFailureReason] = []
        if recall < 1.0 { reasons.append(.missedItems) }
        if precision < 1.0 { reasons.append(.extraItems) }
        if matchedTruth > 0, descHits < matchedTruth { reasons.append(.wrongDescriptions) }
        if matchedTruth > 0, qtyHits < matchedTruth { reasons.append(.wrongQuantities) }
        if matchedTruth < groundTruth.items.count, draft.items.contains(where: { parsed in
            !groundTruth.items.contains(where: { $0.lineTotalMinor == parsed.lineTotal.minorUnits })
        }) {
            reasons.append(.wrongItemPrices)
        }

        let subtotalOK = fieldMatches(expected: groundTruth.subtotalMinor, actual: draft.subtotal?.minorUnits)
        let taxOK = fieldMatches(expected: groundTruth.taxMinor, actual: draft.tax?.minorUnits)
        let totalOK = fieldMatches(expected: groundTruth.totalMinor, actual: draft.total?.minorUnits)
        if !subtotalOK { reasons.append(.subtotalMismatch) }
        if !taxOK { reasons.append(.taxMismatch) }
        if !totalOK { reasons.append(.totalMismatch) }

        let reconOK = reconciliationMatches(draft: draft, groundTruth: groundTruth)
        if !reconOK { reasons.append(.reconciliationMismatch) }

        return ReceiptPerReceiptScore(
            receiptID: groundTruth.id,
            itemRecall: recall,
            itemPrecision: precision,
            itemPriceAccuracy: priceAcc,
            itemDescriptionAccuracy: descAcc,
            quantityAccuracy: qtyAcc,
            subtotalCorrect: subtotalOK,
            taxCorrect: taxOK,
            totalCorrect: totalOK,
            reconciliationAgrees: reconOK,
            failureReasons: reasons
        )
    }

    public static func aggregate(_ scores: [ReceiptPerReceiptScore]) -> BenchmarkAggregateMetrics {
        guard !scores.isEmpty else {
            return BenchmarkAggregateMetrics(
                receiptCount: 0,
                itemRecall: 0,
                itemPrecision: 0,
                itemPriceAccuracy: 0,
                itemDescriptionAccuracy: 0,
                quantityAccuracy: 0,
                subtotalIdentificationRate: 0,
                taxIdentificationRate: 0,
                totalIdentificationRate: 0,
                reconciliationAgreementRate: 0
            )
        }
        let n = Double(scores.count)
        func avg(_ pick: (ReceiptPerReceiptScore) -> Double) -> Double {
            scores.reduce(0.0) { $0 + pick($1) } / n
        }
        func rate(_ pick: (ReceiptPerReceiptScore) -> Bool) -> Double {
            Double(scores.filter(pick).count) / n
        }
        return BenchmarkAggregateMetrics(
            receiptCount: scores.count,
            itemRecall: avg(\.itemRecall),
            itemPrecision: avg(\.itemPrecision),
            itemPriceAccuracy: avg(\.itemPriceAccuracy),
            itemDescriptionAccuracy: avg(\.itemDescriptionAccuracy),
            quantityAccuracy: avg(\.quantityAccuracy),
            subtotalIdentificationRate: rate(\.subtotalCorrect),
            taxIdentificationRate: rate(\.taxCorrect),
            totalIdentificationRate: rate(\.totalCorrect),
            reconciliationAgreementRate: rate(\.reconciliationAgrees)
        )
    }

    private struct ItemPair {
        var parsed: DraftItem
        var truth: GroundTruthItem?
    }

    private func matchItems(parsed: [DraftItem], truth: [GroundTruthItem]) -> [ItemPair] {
        var remaining = truth
        var pairs: [ItemPair] = []
        for item in parsed {
            if let idx = remaining.firstIndex(where: { $0.lineTotalMinor == item.lineTotal.minorUnits }) {
                let gt = remaining.remove(at: idx)
                pairs.append(ItemPair(parsed: item, truth: gt))
            } else {
                pairs.append(ItemPair(parsed: item, truth: nil))
            }
        }
        return pairs
    }

    private func fieldMatches(expected: Int?, actual: Int?) -> Bool {
        switch (expected, actual) {
        case (nil, _): return true
        case (let e?, let a?): return e == a
        case (_?, nil): return false
        }
    }

    private func reconciliationMatches(draft: ReceiptDraft, groundTruth: ReceiptGroundTruth) -> Bool {
        if let expected = groundTruth.expectsReconciles {
            return draft.reconciles == expected
        }
        return true
    }
}

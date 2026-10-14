import Foundation

/// Proportional cent allocation for receipt-level pools not modeled in `BillCalculator` (e.g. service charge).
enum SessionPoolAllocator {
    static func allocate(
        amount: Int,
        participants: [Participant],
        weights: [Int]
    ) -> [Int] {
        BillCalculator.allocate(
            amount: amount,
            recipients: participants,
            weights: weights,
            pool: .tax
        ).shares
    }
}

import Foundation

/// Proportional cent allocation for the receipt-level pools `BillSession` shares on top of `BillCalculator`'s
/// (the service charge and a printed tip). Same largest-remainder rule; the leftover cents come back as adjustments.
enum SessionPoolAllocator {
    static func allocate(
        amount: Int,
        participants: [Participant],
        weights: [Int],
        pool: RoundingAdjustment.Pool
    ) -> (shares: [Int], adjustments: [RoundingAdjustment]) {
        BillCalculator.allocate(
            amount: amount,
            recipients: participants,
            weights: weights,
            pool: pool
        )
    }
}

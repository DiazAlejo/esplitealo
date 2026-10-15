import Foundation
@testable import EsplitealoCore

// Deterministic bill generator for the calculator proof tests.
//
// Everything here is a pure function of a 64-bit seed: the same seed gives the same bill and so the
// same split, on any machine. A failing property prints its seed; replay it with
// `ESPLITEALO_PROOF_SEED=<seed> swift test --filter CalculatorProof` (see docs/CALCULATOR_PROOF.md).

/// SplitMix64: a fixed, tiny algorithm, so generated bills never depend on the Swift version.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Integer in `0 ..< n`.
    mutating func below(_ n: Int) -> Int {
        Int(next() % UInt64(n))
    }

    /// Integer in `low ... high`.
    mutating func between(_ low: Int, _ high: Int) -> Int {
        low + below(high - low + 1)
    }

    mutating func chance(_ percent: Int) -> Bool {
        below(100) < percent
    }

    mutating func pick<T>(_ options: [T]) -> T {
        options[below(options.count)]
    }

    mutating func weighted<T>(_ pairs: [(T, Int)]) -> T {
        var roll = below(pairs.reduce(0) { $0 + $1.1 })
        for (value, weight) in pairs {
            if roll < weight { return value }
            roll -= weight
        }
        return pairs[pairs.count - 1].0
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var items = items
        guard items.count > 1 else { return items }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            items.swapAt(i, below(i + 1))
        }
        return items
    }

    /// An independent stream for the nth thing derived from `seed` (bill i of a batch, say).
    static func derive(_ seed: UInt64, _ index: UInt64) -> UInt64 {
        var mixer = SplitMix64(seed: seed &* 0x2545_F491_4F6C_DD1D &+ index &* 0x9E37_79B9_7F4A_7C15 &+ 1)
        return mixer.next()
    }
}

/// How the receipt-level numbers are printed.
enum PrintedAmounts {
    /// Printed subtotal and total always add up to the items, tax and printed tip.
    case consistent
    /// Sometimes broken or missing, the way a scan can be.
    case anything
}

/// How people are assigned to units.
enum ClaimStyle {
    /// Every unit is claimed by at least one real person.
    case full
    /// Some units may be left unclaimed, or claimed only by people who are not on the bill.
    case any
}

/// One bill, as plain numbers. The same shape is used by the committed reference corpus
/// (`Tests/Fixtures/CalculatorProof`), so generated and reference bills go through one code path.
struct GeneratedBill: Equatable, Sendable, Decodable {
    struct Item: Equatable, Sendable, Decodable {
        var quantity: Int
        var lineTotalCents: Int
    }

    /// People are positions in `orderIndices`. A position `>= participantCount` is someone who is
    /// not on the bill (the engine must ignore them).
    struct Claim: Equatable, Sendable, Decodable {
        var item: Int
        var unit: Int
        var participants: [Int]
    }

    struct SessionTip: Equatable, Sendable, Decodable {
        var kind: String
        var percent: Int?
        var basis: String?
        var cents: Int?

        var configuration: TipConfiguration {
            if kind == "custom" { return .custom(cents: cents ?? 0) }
            return .percentage(percent: percent ?? 0, basis: basis == "postTax" ? .postTaxTotal : .preTaxSubtotal)
        }

        init(_ configuration: TipConfiguration) {
            switch configuration {
            case let .custom(cents):
                kind = "custom"
                self.cents = cents
            case let .percentage(percent, basis):
                kind = "percent"
                self.percent = percent
                self.basis = basis == .postTaxTotal ? "postTax" : "preTax"
            }
        }
    }

    struct Person: Equatable, Sendable, Decodable {
        var orderIndex: Int
    }

    var seed: String
    var participants: [Person]
    var items: [Item]
    var assignments: [Claim]
    var taxLinesCents: [Int]
    var printedTipCents: Int?
    var serviceChargeCents: Int
    var sessionTip: SessionTip
    var printedSubtotalCents: Int?
    var printedTotalCents: Int?

    var participantCount: Int { participants.count }
    var taxCents: Int { taxLinesCents.reduce(0, +) }
    var itemsSubtotalCents: Int { items.reduce(0) { $0 + $1.lineTotalCents } }

    // MARK: - Deterministic identities

    static func participantID(_ position: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", position))!
    }

    static func itemID(_ position: Int) -> UUID {
        UUID(uuidString: String(format: "10000000-0000-0000-0000-%012X", position))!
    }

    /// Someone who is not on the bill (positions `>= participantCount`).
    static func strangerID(_ position: Int) -> UUID {
        UUID(uuidString: String(format: "FFFFFFFF-0000-0000-0000-%012X", position))!
    }

    // MARK: - Engine inputs

    func participantModels() -> [Participant] {
        participants.enumerated().map { position, person in
            Participant(id: Self.participantID(position), name: "P\(position)", orderIndex: person.orderIndex)
        }
    }

    func assignmentModels() -> [ItemAssignment] {
        assignments.map { claim in
            ItemAssignment(
                itemID: Self.itemID(claim.item),
                unitIndex: claim.unit,
                participantIDs: claim.participants.map {
                    $0 < participantCount ? Self.participantID($0) : Self.strangerID($0)
                }
            )
        }
    }

    /// Every taxed line is summed into the single receipt tax, as the receipt parser does.
    func draft() -> ReceiptDraft {
        ReceiptDraft(
            items: items.enumerated().map { position, item in
                DraftItem(
                    id: Self.itemID(position),
                    name: "Item \(position)",
                    quantity: item.quantity,
                    lineTotal: DraftAmount(minorUnits: item.lineTotalCents)
                )
            },
            subtotal: printedSubtotalCents.map { DraftAmount(minorUnits: $0) },
            tax: taxLinesCents.isEmpty ? nil : DraftAmount(minorUnits: taxCents),
            tip: printedTipCents.map { DraftAmount(minorUnits: $0) },
            total: printedTotalCents.map { DraftAmount(minorUnits: $0) }
        )
    }

    func session() -> BillSession {
        BillSession(
            draft: draft(),
            serviceChargeCents: serviceChargeCents,
            participants: participantModels(),
            assignments: assignmentModels(),
            tip: sessionTip.configuration
        )
    }

    /// The calculator's input, with the confirmed total the session would derive.
    func receipt() -> Receipt {
        Receipt(
            items: items.enumerated().map { position, item in
                ReceiptItem(
                    id: Self.itemID(position),
                    description: "Item \(position)",
                    quantity: item.quantity,
                    totalPriceCents: item.lineTotalCents
                )
            },
            taxCents: taxCents,
            tip: sessionTip.configuration,
            confirmedTotalCents: session().confirmedBillTotalCents,
            participants: participantModels(),
            assignments: assignmentModels()
        )
    }
}

// MARK: - Random generation

extension GeneratedBill {
    static func random(seed: UInt64, claims: ClaimStyle = .any, printed: PrintedAmounts = .anything) -> GeneratedBill {
        var rng = SplitMix64(seed: seed)
        let participants = drawParticipants(&rng)
        let items = drawItems(&rng)
        let assignments = drawAssignments(&rng, people: participants.count, items: items, style: claims)
        let itemsSubtotal = items.reduce(0) { $0 + $1.lineTotalCents }

        var taxLines: [Int] = []
        for _ in 0 ..< rng.weighted([(0, 20), (1, 50), (2, 22), (3, 8)]) {
            if rng.chance(35) {
                taxLines.append(rng.between(0, max(1, itemsSubtotal / 8)))
            } else {
                taxLines.append(itemsSubtotal * rng.pick([100, 450, 700, 1000, 1050, 1150]) / 10000)
            }
        }
        let tax = taxLines.reduce(0, +)

        var serviceCharge = 0
        var printedTip: Int?
        switch rng.weighted([("plain", 58), ("tip", 24), ("service", 18)]) {
        case "tip":
            printedTip = rng.chance(50) ? rng.between(0, max(1, itemsSubtotal / 4)) : itemsSubtotal * 18 / 100
        case "service":
            serviceCharge = max(1, itemsSubtotal * rng.pick([10, 15, 18]) / 100 + rng.between(0, 2))
            printedTip = serviceCharge
        default:
            break
        }

        let tip: SessionTip
        if rng.chance(22) {
            tip = SessionTip(.custom(cents: rng.pick([0, 1, 99, 500, 1500, 2575, 10000])))
        } else {
            let percent = rng.weighted([(0, 8), (10, 8), (15, 15), (18, 20), (20, 25), (25, 10), (7, 4), (13, 4), (30, 6)])
            let basis: TipBasis = rng.chance(30) ? .postTaxTotal : .preTaxSubtotal
            tip = SessionTip(.percentage(percent: percent, basis: basis))
        }

        var printedSubtotal: Int? = itemsSubtotal
        var printedTotal: Int? = itemsSubtotal + tax + (printedTip ?? 0)
        if printed == .anything {
            switch rng.weighted([
                ("consistent", 70), ("noSubtotal", 7), ("noTotal", 5), ("subtotalOff", 6),
                ("totalOff", 7), ("neither", 3), ("bothOff", 2),
            ]) {
            case "noSubtotal": printedSubtotal = nil
            case "noTotal": printedTotal = nil
            case "subtotalOff": printedSubtotal = itemsSubtotal + rng.pick([-250, -1, 1, 2, 700])
            case "totalOff": printedTotal = (printedTotal ?? 0) + rng.pick([-400, -1, 1, 3, 1200])
            case "neither": (printedSubtotal, printedTotal) = (nil, nil)
            case "bothOff": (printedSubtotal, printedTotal) = (itemsSubtotal + 1, (printedTotal ?? 0) + 1)
            default: break
            }
        }

        return GeneratedBill(
            seed: String(seed),
            participants: participants,
            items: items,
            assignments: assignments,
            taxLinesCents: taxLines,
            printedTipCents: printedTip,
            serviceChargeCents: serviceCharge,
            sessionTip: tip,
            printedSubtotalCents: printedSubtotal,
            printedTotalCents: printedTotal
        )
    }

    private static func drawParticipants(_ rng: inout SplitMix64) -> [Person] {
        let count = rng.weighted([(1, 7), (2, 24), (3, 22), (4, 17), (5, 10), (6, 8), (7, 6), (9, 6)])
        let orders: [Int]
        switch rng.weighted([("contiguous", 68), ("gaps", 16), ("shuffled", 16)]) {
        case "gaps":
            var next = rng.between(0, 3)
            orders = (0 ..< count).map { _ in
                defer { next += rng.between(1, 4) }
                return next
            }
        case "shuffled":
            orders = rng.shuffled(Array(0 ..< count))
        default:
            orders = Array(0 ..< count)
        }
        return orders.map { Person(orderIndex: $0) }
    }

    private static func drawItems(_ rng: inout SplitMix64) -> [Item] {
        let upper = rng.weighted([(0, 1), (1, 10), (2, 16), (3, 18), (4, 16), (6, 14), (8, 10), (12, 8), (16, 7)])
        let count = upper > 1 ? rng.between(max(1, upper / 2), upper) : upper
        return (0 ..< count).map { _ in
            let quantity = rng.weighted([(1, 60), (2, 18), (3, 9), (4, 5), (6, 4), (12, 4)])
            let unit: Int = switch rng.weighted([("round", 24), ("typical", 44), ("odd", 22), ("tiny", 6), ("big", 4)]) {
            case "round": rng.pick([100, 250, 500, 800, 1000, 1200, 1500, 2000])
            case "typical": rng.between(150, 4500)
            case "odd": rng.between(1, 9999)
            case "tiny": rng.between(0, 7)
            default: rng.between(20000, 250_000)
            }
            var total = unit * quantity
            if quantity > 1, rng.chance(35) { total += rng.between(1, quantity - 1) }
            return Item(quantity: quantity, lineTotalCents: total)
        }
    }

    private static func drawAssignments(
        _ rng: inout SplitMix64, people: Int, items: [Item], style: ClaimStyle
    ) -> [Claim] {
        let leaveGaps = style == .any && rng.chance(35)
        var claims: [Claim] = []
        for (itemIndex, item) in items.enumerated() {
            for unit in 0 ..< item.quantity {
                if leaveGaps, rng.chance(30) { continue }
                var who: [Int]
                switch rng.weighted([("solo", 55), ("pair", 20), ("group", 13), ("everyone", 9), ("junk", style == .any ? 3 : 0)]) {
                case "pair" where people >= 2:
                    who = Array(rng.shuffled(Array(0 ..< people)).prefix(2))
                case "group" where people >= 3:
                    who = Array(rng.shuffled(Array(0 ..< people)).prefix(rng.between(3, people)))
                case "everyone":
                    who = rng.shuffled(Array(0 ..< people))
                case "junk":
                    // Strangers (not on the bill), alone or beside a real person, sometimes duplicated.
                    who = rng.chance(50) ? [people] : [rng.below(people), people, people + 1]
                    if rng.chance(40) { who.append(who[0]) }
                default:
                    who = [rng.below(people)]
                }
                // Repeating a real person must never change anything.
                if style == .full, rng.chance(4) { who.append(who[0]) }
                claims.append(Claim(item: itemIndex, unit: unit, participants: who))
            }
        }
        return claims
    }
}

// MARK: - Seeds for the property tests

enum PropertySeeds {
    /// Number of generated bills each property checks (override with `ESPLITEALO_PROOF_BILLS`).
    static let billsPerProperty: Int = {
        ProcessInfo.processInfo.environment["ESPLITEALO_PROOF_BILLS"].flatMap(Int.init) ?? 1000
    }()

    static let batchSize = 25

    /// One test case per batch keeps Swift Testing output readable; each bill still has its own seed.
    static let batches: [Int] = {
        if ProcessInfo.processInfo.environment["ESPLITEALO_PROOF_SEED"] != nil { return [0] }
        return Array(0 ..< max(1, billsPerProperty / batchSize))
    }()

    /// Seeds of the bills in one batch. `ESPLITEALO_PROOF_SEED=<seed>` replays exactly that bill.
    static func seeds(inBatch batch: Int) -> [UInt64] {
        if let raw = ProcessInfo.processInfo.environment["ESPLITEALO_PROOF_SEED"], let seed = UInt64(raw) {
            return [seed]
        }
        return (0 ..< batchSize).map { offset in
            SplitMix64.derive(0xE5_9117_EA10, UInt64(batch * batchSize + offset))
        }
    }
}

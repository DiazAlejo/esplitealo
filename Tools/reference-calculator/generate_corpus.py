#!/usr/bin/env python3
"""Emit a seeded corpus of bills with the reference calculator's results as JSON.

    python3 generate_corpus.py --count 300  --out ../../Tests/Fixtures/CalculatorProof/reference-corpus-300.json
    python3 generate_corpus.py --count 5000 --out /tmp/reference-corpus-5000.json
    python3 generate_corpus.py --count 300  --check ../../Tests/Fixtures/CalculatorProof/reference-corpus-300.json

The corpus is a pure function of (seed, count): every bill is drawn from its own SplitMix64 stream
(seeded from the master seed and the bill's index), so the same arguments always give byte-identical
output on any Python 3 and the first N bills of a larger corpus equal a smaller corpus.
"""

import argparse
import json
import sys

from reference_calculator import calculate, largest_remainder

DEFAULT_SEED = 20261015
FORMAT_VERSION = 1
MASK = (1 << 64) - 1


class SplitMix64:
    """Tiny deterministic generator; the algorithm is fixed, so output never depends on the Python version."""

    def __init__(self, seed):
        self.state = seed & MASK

    def next_u64(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return z ^ (z >> 31)

    def below(self, n):
        """Uniform-ish integer in [0, n)."""
        return self.next_u64() % n

    def between(self, low, high):
        """Integer in [low, high], inclusive."""
        return low + self.below(high - low + 1)

    def chance(self, percent):
        return self.below(100) < percent

    def pick(self, options):
        return options[self.below(len(options))]

    def weighted(self, pairs):
        """pairs: [(value, weight)]."""
        total = sum(weight for _, weight in pairs)
        roll = self.below(total)
        for value, weight in pairs:
            if roll < weight:
                return value
            roll -= weight
        raise AssertionError("unreachable")

    def shuffle(self, items):
        items = list(items)
        for i in range(len(items) - 1, 0, -1):
            j = self.below(i + 1)
            items[i], items[j] = items[j], items[i]
        return items


def bill_seed(master_seed, index):
    return SplitMix64((master_seed * 0x2545F4914F6CDD1D + index * 0x9E3779B97F4A7C15 + 1) & MASK).next_u64()


def draw_participants(rng):
    count = rng.weighted([(1, 6), (2, 26), (3, 24), (4, 18), (5, 10), (6, 7), (7, 5), (8, 4)])
    layout = rng.weighted([("contiguous", 70), ("gaps", 15), ("shuffled", 15)])
    if layout == "contiguous":
        orders = list(range(count))
    elif layout == "gaps":
        # As if earlier people were removed: ascending order indices with holes.
        orders, next_order = [], rng.between(0, 3)
        for _ in range(count):
            orders.append(next_order)
            next_order += rng.between(1, 3)
    else:
        # Array order differs from the order people were added.
        orders = rng.shuffle(range(count))
    return [{"orderIndex": order} for order in orders]


def draw_unit_price(rng):
    style = rng.weighted([("round", 25), ("typical", 45), ("odd", 20), ("tiny", 6), ("big", 4)])
    if style == "round":
        return rng.pick([100, 250, 500, 800, 1000, 1200, 1500, 2000])
    if style == "typical":
        return rng.between(150, 4500)
    if style == "odd":
        return rng.between(1, 9999)
    if style == "tiny":
        return rng.between(0, 7)
    return rng.between(20000, 250000)


def draw_items(rng):
    count = rng.weighted([(0, 1), (1, 12), (2, 18), (3, 20), (4, 16), (5, 12), (6, 9), (8, 7), (12, 5)])
    count = rng.between(max(1, count - 1), count) if count > 1 else count
    items = []
    for _ in range(count):
        quantity = rng.weighted([(1, 62), (2, 18), (3, 8), (4, 5), (6, 4), (12, 3)])
        unit = draw_unit_price(rng)
        total = unit * quantity
        if quantity > 1 and rng.chance(35):
            # Receipt line total that is not a multiple of the quantity (exercises the +1 cent units).
            total += rng.between(1, quantity - 1)
        items.append({"quantity": quantity, "lineTotalCents": total})
    return items


def draw_assignments(rng, participants, items):
    people = len(participants)
    mode = rng.weighted([("all", 62), ("partial", 28), ("none", 3), ("rest-evenly-ready", 7)])
    claims = []
    for item_index, item in enumerate(items):
        for unit in range(item["quantity"]):
            if mode == "none" or (mode == "partial" and rng.chance(30)):
                continue
            kind = rng.weighted([("solo", 55), ("pair", 20), ("group", 12), ("everyone", 10), ("junk", 3)])
            if kind == "solo":
                who = [rng.below(people)]
            elif kind == "pair" and people >= 2:
                who = rng.shuffle(range(people))[:2]
            elif kind == "group" and people >= 3:
                who = rng.shuffle(range(people))[: rng.between(3, people)]
            elif kind == "everyone":
                who = rng.shuffle(range(people))
            elif kind == "junk":
                # A person who is not on the bill, sometimes next to a real one, sometimes a duplicate.
                who = [people] if rng.chance(50) else [rng.below(people), people, people + 1]
                if rng.chance(40):
                    who.append(who[0])
            else:
                who = [rng.below(people)]
            claims.append({"item": item_index, "unit": unit, "participants": who})
    return claims


def draw_session_tip(rng):
    kind = rng.weighted([("percent", 80), ("custom", 20)])
    if kind == "custom":
        return {"kind": "custom", "cents": rng.pick([0, 1, 99, 500, 1500, 2575, 10000])}
    return {
        "kind": "percent",
        "percent": rng.weighted([(0, 10), (10, 8), (15, 15), (18, 20), (20, 25), (25, 10), (13, 4), (7, 4), (30, 4)]),
        "basis": rng.weighted([("preTax", 70), ("postTax", 30)]),
    }


def draw_money_lines(rng, items_subtotal):
    """Tax lines (zero, one or several) and the other receipt-level amounts."""
    line_count = rng.weighted([(0, 18), (1, 52), (2, 22), (3, 8)])
    lines = []
    for _ in range(line_count):
        rate_basis_points = rng.pick([100, 350, 450, 700, 1000, 1050, 1150, 1250])
        amount = items_subtotal * rate_basis_points // 10000
        if rng.chance(40):
            amount = rng.between(0, max(1, items_subtotal // 8))
        lines.append(amount)
    return lines


def draw_bill(master_seed, index):
    seed = bill_seed(master_seed, index)
    rng = SplitMix64(seed)
    participants = draw_participants(rng)
    items = draw_items(rng)
    claims = draw_assignments(rng, participants, items)
    items_subtotal = sum(item["lineTotalCents"] for item in items)

    tax_lines = draw_money_lines(rng, items_subtotal)
    tax = sum(tax_lines)
    service_charge = 0
    printed_tip = None
    receipt_style = rng.weighted([("plain", 60), ("printed-tip", 22), ("service-charge", 18)])
    if receipt_style == "printed-tip":
        printed_tip = rng.between(0, max(1, items_subtotal // 4)) if rng.chance(50) else items_subtotal * 18 // 100
    elif receipt_style == "service-charge":
        service_charge = max(1, items_subtotal * rng.pick([10, 15, 18]) // 100 + rng.between(0, 2))
        printed_tip = service_charge

    # Printed amounts: consistent most of the time, otherwise broken in one of the ways a scan can be.
    printed_subtotal = items_subtotal
    printed_total = items_subtotal + tax + (printed_tip or 0)
    printed_style = rng.weighted([
        ("consistent", 74), ("no-subtotal", 6), ("no-total", 5), ("subtotal-off", 5),
        ("total-off", 6), ("neither", 2), ("both-off", 2),
    ])
    if printed_style == "no-subtotal":
        printed_subtotal = None
    elif printed_style == "no-total":
        printed_total = None
    elif printed_style == "subtotal-off":
        printed_subtotal += rng.pick([-100, -1, 1, 2, 500])
    elif printed_style == "total-off":
        printed_total += rng.pick([-500, -1, 1, 3, 1000])
    elif printed_style == "neither":
        printed_subtotal = printed_total = None
    elif printed_style == "both-off":
        printed_subtotal += 1
        printed_total += 1

    bill = {
        "id": "bill-%05d" % index,
        "seed": str(seed),  # a string: JSON readers that go through doubles would corrupt a 64-bit number
        "participants": participants,
        "items": items,
        "assignments": claims,
        "taxLinesCents": tax_lines,
        "printedTipCents": printed_tip,
        "serviceChargeCents": service_charge,
        "sessionTip": draw_session_tip(rng),
        "printedSubtotalCents": printed_subtotal,
        "printedTotalCents": printed_total,
    }
    bill["expected"] = calculate(bill)
    return bill


def draw_allocation(master_seed, index):
    """A bare largest-remainder case: the allocation rule alone, without bill structure."""
    rng = SplitMix64(bill_seed(master_seed ^ 0xA110C, index))
    count = rng.between(1, 9)
    amount_range = rng.weighted([((0, 0), 5), ((1, 1), 8), ((2, 99), 20), ((100, 99999), 50), ((100000, 9999999), 17)])
    amount = rng.between(*amount_range)
    weights = []
    for _ in range(count):
        weight_range = rng.weighted([((0, 0), 20), ((1, 3), 20), ((1, 5000), 50), ((1, 900000), 10)])
        weights.append(rng.between(*weight_range))
    if rng.chance(25):
        weights = [weights[0]] * count  # a full tie, decided only by participant order
    orders = rng.shuffle(range(count)) if rng.chance(30) else list(range(count))
    shares, adjusted = largest_remainder(amount, weights, orders)
    return {"amountCents": amount, "weights": weights, "orderIndices": orders, "shares": shares, "adjusted": adjusted}


def build_corpus(seed, count):
    return {
        "format": FORMAT_VERSION,
        "generator": {"script": "Tools/reference-calculator/generate_corpus.py", "seed": seed, "count": count},
        "bills": [draw_bill(seed, i) for i in range(count)],
        "allocations": [draw_allocation(seed, i) for i in range(min(count, 600))],
    }


def render(corpus):
    """Stable text: one bill / allocation per line so diffs and `git blame` stay readable."""
    dump = lambda value: json.dumps(value, sort_keys=True, separators=(",", ":"))
    lines = ["{", '"format":%d,' % corpus["format"], '"generator":%s,' % dump(corpus["generator"]), '"bills":[']
    lines += [dump(bill) + ("," if i < len(corpus["bills"]) - 1 else "") for i, bill in enumerate(corpus["bills"])]
    lines += ["],", '"allocations":[']
    lines += [dump(a) + ("," if i < len(corpus["allocations"]) - 1 else "") for i, a in enumerate(corpus["allocations"])]
    lines += ["]", "}", ""]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--count", type=int, default=300)
    parser.add_argument("--out", help="write the corpus here")
    parser.add_argument("--check", metavar="FILE", help="exit 1 unless FILE equals the regenerated corpus")
    args = parser.parse_args(argv)

    text = render(build_corpus(args.seed, args.count))
    if args.check:
        with open(args.check, encoding="utf-8") as handle:
            if handle.read() != text:
                sys.stderr.write("%s is not the corpus for seed=%d count=%d; regenerate it\n" % (args.check, args.seed, args.count))
                return 1
        print("ok: %s matches seed=%d count=%d" % (args.check, args.seed, args.count))
        return 0
    if not args.out:
        parser.error("pass --out FILE or --check FILE")
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("wrote %d bills to %s" % (args.count, args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())

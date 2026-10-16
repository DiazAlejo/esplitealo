"""Independent reference implementation of docs/CALCULATION_RULES.md and docs/BILL_SESSION.md.

Written from the documents, not ported from the Swift code. It uses only the Python standard
library and exact rational arithmetic (fractions.Fraction), so it does not share the Swift engine's
integer-division formulation: shares are the exact rational split, floored, with the leftover cents
handed out by the largest fractional part.

A bill is a plain JSON-able dict (see README.md):

    participants        [{"orderIndex": int}]        array order is the input order; ties and
                                                     leftover cents follow orderIndex
    items               [{"quantity": int, "lineTotalCents": int}]
    assignments         [{"item": i, "unit": u, "participants": [positions]}]
                        a position >= len(participants) stands for a person who is not on the bill
    taxLinesCents       [int]                        summed into the single receipt tax
    printedTipCents     int | None                   tip/gratuity line printed on the receipt
    serviceChargeCents  int
    sessionTip          {"kind": "percent", "percent": int, "basis": "preTax" | "postTax"}
                        | {"kind": "custom", "cents": int}      a negative amount or percent is a tip of 0
    printedSubtotalCents, printedTotalCents          int | None
"""

from fractions import Fraction
from math import floor


def largest_remainder(amount, weights, order_ranks):
    """Split `amount` cents by non-negative integer `weights`.

    Returns (shares, adjusted): `shares` parallel to `weights`; `adjusted` the sorted positions
    that received a leftover cent. Ties on the fractional part go to the lower order rank.
    A person with weight 0 gets 0 and never a leftover cent; all-zero weights allocate nothing.
    """
    total_weight = sum(weights)
    shares = [0] * len(weights)
    if total_weight == 0 or amount == 0:
        return shares, []

    exact = {i: Fraction(amount * w, total_weight) for i, w in enumerate(weights) if w > 0}
    for i, value in exact.items():
        shares[i] = floor(value)

    leftover = amount - sum(shares)
    assert 0 <= leftover < len(exact), "leftover must be fewer cents than people with weight"

    ranked = sorted(exact, key=lambda i: (-(exact[i] - shares[i]), order_ranks[i]))
    adjusted = sorted(ranked[:leftover])
    for i in adjusted:
        shares[i] += 1
    return shares, adjusted


def unit_prices(line_total, quantity):
    """Unit prices summing to the line total; the first `extra` units cost one cent more."""
    base, extra = divmod(line_total, quantity)
    return [base + 1 if unit < extra else base for unit in range(quantity)]


def session_tip_cents(tip, items_subtotal, tax_cents):
    """Tip in cents: custom as entered, or a percentage of the basis rounded half up. A negative tip or percentage is 0."""
    if tip["kind"] == "custom":
        return max(0, tip["cents"])
    basis = items_subtotal + tax_cents if tip["basis"] == "postTax" else items_subtotal
    return floor(Fraction(basis * max(0, tip["percent"]), 100) + Fraction(1, 2))


def _reconciles(items_sum, subtotal, total, tax, printed_tip):
    """Receipt reconciliation (RECEIPT_PARSING.md rule 9 plus the totalsDoNotAddUp check)."""
    reconciles = False
    if subtotal is not None:
        reconciles = items_sum == subtotal
    elif total is not None:
        reconciles = items_sum == total - tax - (printed_tip or 0)
    if subtotal is not None and total is not None and subtotal + tax + (printed_tip or 0) != total:
        reconciles = False
    return reconciles


def calculate(bill):
    participants = bill["participants"]
    count = len(participants)
    ranks = [p["orderIndex"] for p in participants]

    claims = {}
    for row in bill["assignments"]:
        claims[(row["item"], row["unit"])] = row["participants"]

    item_subtotals = [0] * count
    unit_adjustments = [[] for _ in range(count)]
    unassigned = 0
    line_total_sum = 0

    for item_index, item in enumerate(bill["items"]):
        line_total_sum += item["lineTotalCents"]
        prices = unit_prices(item["lineTotalCents"], item["quantity"])
        for unit, price in enumerate(prices):
            assignees = sorted({p for p in claims.get((item_index, unit), []) if 0 <= p < count})
            if not assignees:
                unassigned += 1
                continue
            weights = [1 if i in assignees else 0 for i in range(count)]
            shares, adjusted = largest_remainder(price, weights, ranks)
            for i in range(count):
                item_subtotals[i] += shares[i]
            for i in adjusted:
                unit_adjustments[i].append([item_index, unit])

    tax = sum(bill["taxLinesCents"])
    tip = session_tip_cents(bill["sessionTip"], line_total_sum, tax)
    service = bill["serviceChargeCents"]
    printed_tip = bill["printedTipCents"]
    receipt_tip = 0 if service > 0 else (printed_tip or 0)

    tax_shares, tax_adjusted = largest_remainder(tax, item_subtotals, ranks)
    tip_shares, tip_adjusted = largest_remainder(tip, item_subtotals, ranks)
    service_shares, service_adjusted = largest_remainder(service, item_subtotals, ranks)
    receipt_tip_shares, receipt_tip_adjusted = largest_remainder(receipt_tip, item_subtotals, ranks)

    people = []
    for i in range(count):
        owed = item_subtotals[i] + tax_shares[i] + service_shares[i] + receipt_tip_shares[i] + tip_shares[i]
        people.append({
            "itemSubtotalCents": item_subtotals[i],
            "taxShareCents": tax_shares[i],
            "serviceShareCents": service_shares[i],
            "receiptTipShareCents": receipt_tip_shares[i],
            "tipShareCents": tip_shares[i],
            "totalOwedCents": owed,
            "itemUnitAdjustments": sorted(unit_adjustments[i]),
            "taxAdjustments": 1 if i in tax_adjusted else 0,
            "tipAdjustments": 1 if i in tip_adjusted else 0,
            "serviceAdjustments": 1 if i in service_adjusted else 0,
            "printedTipAdjustments": 1 if i in receipt_tip_adjusted else 0,
        })

    derived = line_total_sum + tax + service + receipt_tip + tip
    settled = unassigned == 0
    subtotal = bill["printedSubtotalCents"]
    total = bill["printedTotalCents"]
    reconciles = _reconciles(line_total_sum, subtotal, total, tax, printed_tip)
    # Tax, tip or a service charge to share and nobody with an item that costs anything to share it by: every pool is
    # allocated by item subtotal, so nothing is allocated and the bill stays blocked. A receipt that does not add up
    # (or has no total) is reported as that first.
    nobody_carries_charges = (
        total is not None
        and settled
        and reconciles
        and sum(item_subtotals) == 0
        and tax + tip + service + receipt_tip > 0
    )
    can_share = (
        total is not None
        and reconciles
        and settled
        and sum(p["totalOwedCents"] for p in people) == derived
        and derived == total + tip
    )

    return {
        "itemsSubtotalCents": line_total_sum,
        "taxCents": tax,
        "sessionTipCents": tip,
        "receiptTipOnBillCents": receipt_tip,
        "derivedTotalCents": derived,
        "isSettled": settled,
        "unassignedUnits": unassigned,
        "reconciles": reconciles,
        "canShare": can_share,
        "nobodyCarriesCharges": nobody_carries_charges,
        "people": people,
    }

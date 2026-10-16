"""Checks the reference calculator against the worked examples in docs/CALCULATION_RULES.md.

Run from this directory:  python3 -m unittest -v

The expected numbers below are copied from the document, not from the Swift code.
"""

import unittest

from reference_calculator import largest_remainder, session_tip_cents, unit_prices, calculate


def bill(**overrides):
    base = {
        "participants": [{"orderIndex": 0}, {"orderIndex": 1}],
        "items": [],
        "assignments": [],
        "taxLinesCents": [],
        "printedTipCents": None,
        "serviceChargeCents": 0,
        "sessionTip": {"kind": "percent", "percent": 0, "basis": "preTax"},
        "printedSubtotalCents": None,
        "printedTotalCents": None,
    }
    base.update(overrides)
    return base


def claim(item, unit, *people):
    return {"item": item, "unit": unit, "participants": list(people)}


class LargestRemainderTests(unittest.TestCase):
    def test_three_fifty_shared_by_three_gives_earliest_the_extra_cents(self):
        # "Unit price 350 cents, equal weights ... A 117, B 117, C 116."
        shares, adjusted = largest_remainder(350, [1, 1, 1], [0, 1, 2])
        self.assertEqual(shares, [117, 117, 116])
        self.assertEqual(adjusted, [0, 1])

    def test_twelve_dollar_appetizer_shared_by_three_has_no_remainder(self):
        shares, adjusted = largest_remainder(1200, [1, 1, 1], [0, 1, 2])
        self.assertEqual(shares, [400, 400, 400])
        self.assertEqual(adjusted, [])

    def test_tax_100_across_three_equal_subtotals(self):
        shares, adjusted = largest_remainder(100, [500, 500, 500], [0, 1, 2])
        self.assertEqual(shares, [34, 33, 33])
        self.assertEqual(adjusted, [0])

    def test_zero_total_weight_allocates_nothing(self):
        shares, adjusted = largest_remainder(500, [0, 0], [0, 1])
        self.assertEqual(shares, [0, 0])
        self.assertEqual(adjusted, [])

    def test_zero_weight_person_never_gets_a_leftover_cent(self):
        # Chris has weight 0: "0 cents tax, no leftover cents".
        shares, adjusted = largest_remainder(101, [1, 1, 0], [0, 1, 2])
        self.assertEqual(shares, [51, 50, 0])
        self.assertEqual(adjusted, [0])

    def test_larger_remainder_beats_earlier_order(self):
        # 10 cents over weights 1:1:1 -> floors 3,3,3, one cent left, all tie -> person 0.
        # 10 cents over weights 5:3:2 is exact.  Use 7 over 2:3:2 (W=7): exact -> 2,3,2.
        # 5 over 1:1:3 (W=5): exact shares 1,1,3.  Use 8 over 1:1:3 (W=5): 1.6, 1.6, 4.8
        # floors 1,1,4 (sum 6), 2 left; remainders (3/5, 3/5, 4/5) -> third first, then first.
        shares, adjusted = largest_remainder(8, [1, 1, 3], [0, 1, 2])
        self.assertEqual(shares, [2, 1, 5])
        self.assertEqual(adjusted, [0, 2])

    def test_order_ranks_decide_ties_not_list_position(self):
        # Same weights, but person at position 1 was added first.
        shares, adjusted = largest_remainder(350, [1, 1, 1], [2, 0, 1])
        self.assertEqual(shares, [116, 117, 117])
        self.assertEqual(adjusted, [1, 2])


class UnitPriceTests(unittest.TestCase):
    def test_extra_cents_go_to_the_first_units(self):
        self.assertEqual(unit_prices(1003, 4), [251, 251, 251, 250])

    def test_exact_division(self):
        self.assertEqual(unit_prices(2400, 2), [1200, 1200])


class TipTests(unittest.TestCase):
    def test_post_tax_basis_example(self):
        # Items 10000, tax 1000, 20% post-tax: basis 11000 -> tip 2200.
        self.assertEqual(session_tip_cents({"kind": "percent", "percent": 20, "basis": "postTax"}, 10000, 1000), 2200)

    def test_half_cent_rounds_up(self):
        # 15% of 10 cents = 1.5 -> 2;  15% of 30 cents = 4.5 -> 5;  12% of 4 = 0.48 -> 0.
        tip = {"kind": "percent", "percent": 15, "basis": "preTax"}
        self.assertEqual(session_tip_cents(tip, 10, 0), 2)
        self.assertEqual(session_tip_cents(tip, 30, 0), 5)
        self.assertEqual(session_tip_cents({"kind": "percent", "percent": 12, "basis": "preTax"}, 4, 0), 0)

    def test_custom_tip_ignores_basis_and_percent(self):
        self.assertEqual(session_tip_cents({"kind": "custom", "cents": 1500}, 10000, 1000), 1500)


class WorkedExampleTests(unittest.TestCase):
    def test_captain_example_100_10_20(self):
        b = bill(
            items=[{"quantity": 1, "lineTotalCents": 6000}, {"quantity": 1, "lineTotalCents": 4000}],
            assignments=[claim(0, 0, 0), claim(1, 0, 1)],
            taxLinesCents=[1000],
            sessionTip={"kind": "percent", "percent": 20, "basis": "preTax"},
        )
        result = calculate(b)
        alex, sam = result["people"]
        self.assertEqual((alex["itemSubtotalCents"], alex["taxShareCents"], alex["tipShareCents"], alex["totalOwedCents"]),
                         (6000, 600, 1200, 7800))
        self.assertEqual((sam["itemSubtotalCents"], sam["taxShareCents"], sam["tipShareCents"], sam["totalOwedCents"]),
                         (4000, 400, 800, 5200))
        self.assertEqual(result["derivedTotalCents"], 13000)
        self.assertTrue(result["isSettled"])

    def test_quantity_line_one_unit_to_alex_one_unit_split_by_b_and_c(self):
        b = bill(
            participants=[{"orderIndex": 0}, {"orderIndex": 1}, {"orderIndex": 2}],
            items=[{"quantity": 2, "lineTotalCents": 2400}],
            assignments=[claim(0, 0, 0), claim(0, 1, 1, 2)],
        )
        result = calculate(b)
        self.assertEqual([p["itemSubtotalCents"] for p in result["people"]], [1200, 600, 600])

    def test_zero_item_person_owes_nothing(self):
        b = bill(
            participants=[{"orderIndex": 0}, {"orderIndex": 1}, {"orderIndex": 2}],
            items=[{"quantity": 1, "lineTotalCents": 3333}],
            assignments=[claim(0, 0, 0, 1)],
            taxLinesCents=[301],
            sessionTip={"kind": "custom", "cents": 777},
        )
        chris = calculate(b)["people"][2]
        self.assertEqual(chris["totalOwedCents"], 0)
        self.assertEqual(chris["taxAdjustments"], 0)
        self.assertEqual(chris["tipAdjustments"], 0)

    def test_one_person_bill_owes_everything(self):
        b = bill(
            participants=[{"orderIndex": 0}],
            items=[{"quantity": 3, "lineTotalCents": 1001}, {"quantity": 1, "lineTotalCents": 99}],
            assignments=[claim(0, 0, 0), claim(0, 1, 0), claim(0, 2, 0), claim(1, 0, 0)],
            taxLinesCents=[77, 33],
            sessionTip={"kind": "percent", "percent": 18, "basis": "postTax"},
        )
        result = calculate(b)
        self.assertEqual(result["people"][0]["totalOwedCents"], result["derivedTotalCents"])

    def test_unclaimed_unit_is_not_settled_and_cannot_share(self):
        b = bill(
            items=[{"quantity": 2, "lineTotalCents": 1000}],
            assignments=[claim(0, 0, 0)],
            printedSubtotalCents=1000,
            printedTotalCents=1000,
        )
        result = calculate(b)
        self.assertFalse(result["isSettled"])
        self.assertEqual(result["unassignedUnits"], 1)
        self.assertFalse(result["canShare"])

    def test_unknown_and_duplicate_assignees_are_ignored(self):
        # Participant index 2 does not exist; person 0 listed twice counts once.
        b = bill(
            items=[{"quantity": 1, "lineTotalCents": 900}],
            assignments=[claim(0, 0, 0, 0, 2)],
        )
        result = calculate(b)
        self.assertEqual([p["itemSubtotalCents"] for p in result["people"]], [900, 0])

    def test_reconciled_bill_can_share(self):
        b = bill(
            items=[{"quantity": 1, "lineTotalCents": 6000}, {"quantity": 1, "lineTotalCents": 4000}],
            assignments=[claim(0, 0, 0), claim(1, 0, 1)],
            taxLinesCents=[1000],
            printedSubtotalCents=10000,
            printedTotalCents=11000,
            sessionTip={"kind": "percent", "percent": 20, "basis": "preTax"},
        )
        self.assertTrue(calculate(b)["canShare"])

    def test_service_charge_is_allocated_by_item_subtotals(self):
        b = bill(
            items=[{"quantity": 1, "lineTotalCents": 7000}, {"quantity": 1, "lineTotalCents": 3000}],
            assignments=[claim(0, 0, 0), claim(1, 0, 1)],
            serviceChargeCents=1001,
            printedTipCents=1001,
        )
        result = calculate(b)
        self.assertEqual([p["serviceShareCents"] for p in result["people"]], [701, 300])
        # With a service charge the printed tip is not allocated a second time.
        self.assertEqual([p["receiptTipShareCents"] for p in result["people"]], [0, 0])


class SurfacedPoolRoundingTests(unittest.TestCase):
    """Invariant 5: every leftover cent of every pool is an adjustment, service charge and printed tip included."""

    def three_equal_diners(self, **overrides):
        return bill(
            participants=[{"orderIndex": 0}, {"orderIndex": 1}, {"orderIndex": 2}],
            items=[{"quantity": 1, "lineTotalCents": 1000}] * 3,
            assignments=[claim(0, 0, 0), claim(1, 0, 1), claim(2, 0, 2)],
            **overrides,
        )

    def test_service_charge_leftover_cents_are_adjustments(self):
        # 100 cents over three equal subtotals: 34, 33, 33, the extra cent to the earliest person.
        result = calculate(self.three_equal_diners(serviceChargeCents=100))
        self.assertEqual([p["serviceShareCents"] for p in result["people"]], [34, 33, 33])
        self.assertEqual([p["serviceAdjustments"] for p in result["people"]], [1, 0, 0])
        self.assertEqual([p["printedTipAdjustments"] for p in result["people"]], [0, 0, 0])

    def test_printed_tip_leftover_cents_are_adjustments(self):
        result = calculate(self.three_equal_diners(printedTipCents=200))
        self.assertEqual([p["receiptTipShareCents"] for p in result["people"]], [67, 67, 66])
        self.assertEqual([p["printedTipAdjustments"] for p in result["people"]], [1, 1, 0])
        self.assertEqual([p["serviceAdjustments"] for p in result["people"]], [0, 0, 0])

    def test_printed_tip_under_a_service_charge_is_not_allocated_so_it_has_no_adjustments(self):
        result = calculate(self.three_equal_diners(serviceChargeCents=100, printedTipCents=200))
        self.assertEqual([p["printedTipAdjustments"] for p in result["people"]], [0, 0, 0])

    def test_pools_that_divide_exactly_have_no_adjustments(self):
        result = calculate(self.three_equal_diners(serviceChargeCents=300, printedTipCents=None))
        self.assertEqual([p["serviceAdjustments"] for p in result["people"]], [0, 0, 0])

    def test_a_person_without_items_gets_no_service_adjustment(self):
        b = bill(
            participants=[{"orderIndex": 0}, {"orderIndex": 1}, {"orderIndex": 2}],
            items=[{"quantity": 1, "lineTotalCents": 1000}],
            assignments=[claim(0, 0, 0, 1)],
            serviceChargeCents=101,
        )
        result = calculate(b)
        self.assertEqual([p["serviceShareCents"] for p in result["people"]], [51, 50, 0])
        self.assertEqual([p["serviceAdjustments"] for p in result["people"]], [1, 0, 0])


class NobodyCarriesChargesTests(unittest.TestCase):
    """A bill whose people all owe nothing for items but that has tax, tip or a service charge stays blocked."""

    def free_items(self, **overrides):
        return bill(
            items=[{"quantity": 2, "lineTotalCents": 0}],
            assignments=[claim(0, 0, 0), claim(0, 1, 1)],
            **overrides,
        )

    def test_free_items_with_tax_are_blocked_and_flagged(self):
        result = calculate(self.free_items(taxLinesCents=[100], printedSubtotalCents=0, printedTotalCents=100))
        self.assertTrue(result["nobodyCarriesCharges"])
        self.assertFalse(result["canShare"])
        self.assertEqual([p["totalOwedCents"] for p in result["people"]], [0, 0])

    def test_free_items_with_a_service_charge_or_a_custom_tip_are_flagged(self):
        service = calculate(self.free_items(serviceChargeCents=50, printedSubtotalCents=0, printedTotalCents=50))
        tip = calculate(self.free_items(sessionTip={"kind": "custom", "cents": 300}, printedSubtotalCents=0, printedTotalCents=0))
        self.assertTrue(service["nobodyCarriesCharges"])
        self.assertTrue(tip["nobodyCarriesCharges"])
        self.assertFalse(tip["canShare"])

    def test_no_items_at_all_with_a_charge_is_flagged(self):
        result = calculate(bill(taxLinesCents=[100], printedSubtotalCents=0, printedTotalCents=100))
        self.assertTrue(result["nobodyCarriesCharges"])
        self.assertFalse(result["canShare"])

    def test_free_items_with_nothing_to_carry_are_not_flagged_and_can_share(self):
        result = calculate(self.free_items(printedSubtotalCents=0, printedTotalCents=0))
        self.assertFalse(result["nobodyCarriesCharges"])
        self.assertTrue(result["canShare"])

    def test_someone_with_items_carries_the_charges(self):
        b = bill(
            items=[{"quantity": 1, "lineTotalCents": 1000}],
            assignments=[claim(0, 0, 0)],
            taxLinesCents=[100],
        )
        self.assertFalse(calculate(b)["nobodyCarriesCharges"])

    def test_an_unsettled_bill_is_not_flagged(self):
        # An unclaimed unit is the reason sharing is blocked, not the missing weight.
        b = self.free_items(taxLinesCents=[100], printedSubtotalCents=0, printedTotalCents=100)
        b["assignments"] = [claim(0, 0, 0)]
        self.assertFalse(calculate(b)["nobodyCarriesCharges"])

    def test_a_receipt_that_does_not_add_up_is_a_mismatch_first(self):
        result = calculate(self.free_items(taxLinesCents=[100], printedSubtotalCents=0, printedTotalCents=999))
        self.assertFalse(result["nobodyCarriesCharges"])

    def test_a_missing_printed_total_is_reported_first(self):
        result = calculate(self.free_items(taxLinesCents=[100], printedSubtotalCents=0))
        self.assertFalse(result["nobodyCarriesCharges"])


class NegativeTipTests(unittest.TestCase):
    def test_a_negative_custom_tip_is_zero(self):
        self.assertEqual(session_tip_cents({"kind": "custom", "cents": -500}, 10000, 1000), 0)

    def test_a_negative_percentage_is_zero(self):
        for basis in ("preTax", "postTax"):
            self.assertEqual(session_tip_cents({"kind": "percent", "percent": -10, "basis": basis}, 10000, 1000), 0)


if __name__ == "__main__":
    unittest.main()

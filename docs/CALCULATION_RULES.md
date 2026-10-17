# Calculation rules

This is the most important part to get right before polishing the UI. The rules live in a pure `BillCalculator` with unit tests, independent of the interface.

## Worked example (project owner)

Receipt: $100.00 item subtotal, $10.00 tax, $20.00 tip. Confirmed total: $130.00.

Assignments: Alex $60.00 of items, Sam $40.00 of items (proportional tax and tip).

| Person | Items | Tax share | Tip share | Owes |
| ------ | ----- | --------- | --------- | ---- |
| Alex   | $60   | $6        | $12       | $78  |
| Sam    | $40   | $4        | $8        | $52  |
| Total  | $100  | $10       | $20       | $130 |

## Money and types

- All amounts are **integer cents** (`Int`). Never use `Double` or `Decimal` for money in the engine.
- Tip percentages are stored as a whole-number percent (for example `20` means 20%).
- Intermediate products use `Int`; division uses integer floor unless this document specifies rounding.

## Participants and order

- Each participant has a stable **participant order** (the order they were added to the bill, index `0` first).
- Every tie-break in this document uses that order: **earlier participant wins**.
- Order indices are **unique** within a bill. This is an invariant of the session (`BillSession` hands out one past the highest index in use, so removing someone never makes an index repeat), not something the calculator repairs: two people with the same index would tie on both remainder and order, and the result would depend on the sort.

## Receipt lines and quantity

- Each line has a **quantity** `Q ≥ 1` and a **line total** in cents (the price on the receipt for that row).
- The line total is split into **unit prices** that sum exactly to the line total:
  - `base = lineTotal ÷ Q` (integer division)
  - `extra = lineTotal mod Q`
  - Unit indices `0 ..< extra` cost `base + 1` cent; unit indices `extra ..< Q` cost `base` cents.
- **Assignment is per unit.** For quantity `1`, there is a single unit index `0`. A unit has **one** assignment row: assigning a unit again replaces its row (`BillSession` never keeps two), and the calculator reads the first row it finds for a unit.
- An **item assignment** lists one or more participants for one unit. Multiple participants on the same unit split that unit’s price **equally** (equal weights).

## Assignment model (item-first)

- The UI is item-first: tap a line (or unit), pick people. The engine only needs, per unit, the set of assigned participant ids.
- A unit with **no valid** assigned participants is **unclaimed**. Assignee ids that match no participant are ignored, and duplicate ids and duplicate participants are collapsed, so each person counts once.
- A bill with any unclaimed unit is **not settled**. Settlement and sharing require every unit to be claimed.
- **Split the rest evenly** (product action): for each still-unclaimed unit, assign **all** participants with equal split on that unit. After this action, those units are claimed.

## Core allocation: largest remainder

To split an integer amount `A` (cents) across participants with non-negative integer **weights** `wᵢ` (one per participant, same order as the participant list):

1. Let `W = Σ wᵢ`. If `W = 0`, every share is `0` and no leftover cents are distributed.
2. For each participant `i` with `wᵢ > 0`:
   - `quotientᵢ = (A × wᵢ) ÷ W` (integer division)
   - `remainderᵢ = (A × wᵢ) mod W`
   - Initial share `sᵢ = quotientᵢ`.
3. Let `R = A − Σ sᵢ` (so `0 ≤ R <` count of positive weights).
4. Sort participants with `wᵢ > 0` by **descending** `remainderᵢ`, breaking ties by **ascending participant order**.
5. Give one cent to each of the first `R` participants in that sorted list (increment `sᵢ`).
6. Participants with `wᵢ = 0` keep share `0` and are **never** given a leftover cent.

**Surfacing adjustments:** **every** leftover cent given in step 5 is a **rounding adjustment**: one adjustment of one cent for that participant and pool, so the number of adjustments in a pool equals its leftover cents `R`, and a person's share is their floor plus the cents they were adjusted. The pools are an item unit, tax, tip, the service charge and a tip printed on the receipt. The UI shows every adjustment; nothing is silent.

This rule is used for:

- Splitting a unit price among that unit’s assignees (equal weights).
- Allocating tax across participants (weight = each person’s assigned item subtotal).
- Allocating tip across participants (weight = each person’s assigned item subtotal).
- Allocating the receipt’s service charge, or a tip printed on it, across participants (same weights). These two pools are shared by `BillSession` (see [BILL_SESSION.md](BILL_SESSION.md)) rather than `BillCalculator`, with the same function, and their adjustments appear in each person’s `adjustments` beside the calculator’s. The amounts do not depend on whether the cents are surfaced.

## Tax

- **Tax amount** is a single receipt-level cents value (user-confirmed).
- Each participant’s weight is their **assigned item subtotal** (sum of all unit shares they received).
- Tax shares are computed with largest remainder on the tax amount and those weights.
- A participant with **zero** assigned item subtotal receives **zero** tax, is excluded from leftover tax cents, and receives no tax rounding adjustment.

## Tip

### Tip amount

Exactly one of:

1. **Percentage tip** — compute tip cents from a basis, then round **half up** to the nearest cent:
   - `tipCents = (basis × percent + 50) ÷ 100` (integer arithmetic).
2. **Custom tip** — use the user-entered tip cents directly.

**A negative custom tip or percentage is treated as zero** (`tipCents = 0`, never a discount). The Totals screen does not accept a negative amount in the tip field, and its − button stops at $0.00, so a negative tip can only come from a saved bill or from code; the engine still returns 0 for it.

### Tip basis (per bill)

- **Default:** pre-tax **assigned-items subtotal** for the whole receipt (sum of all line totals), not including tax. *(Captain decision.)*
- **Optional:** post-tax basis = that items subtotal **plus** tax cents. *(Captain decision.)*
- Custom tip ignores basis.

### Tip shares

- After `tipCents` is known, allocate it with largest remainder using each participant’s assigned item subtotal as weight (same rules as tax for zero subtotal).

## Person totals

For each participant:

`amountOwed = itemSubtotal + taxShare + tipShare`

## Confirmed total and reconciliation

- **Calculated bill total** = sum of all line totals + tax cents + tip cents (using the computed or custom tip).
- Compare to the user’s **confirmed receipt total** in cents.
- If they differ, the split is **not shareable** until inputs are corrected (invariant for the product; the engine exposes the mismatch).
- When assignments and confirmed components are consistent, the sum of every person’s `amountOwed` equals the confirmed total **exactly**.
- **Nobody to carry the charges.** Tax, tip and the service charge are shared by item subtotal, so when every claimed item is free (or the bill has no items) there is no weight: nothing is allocated and the people owe less than the bill. If that bill has tax, tip or a service charge to share, it stays **blocked from sharing** and the session says why with its own reason, `noItemsToCarryCharges` (the app: “nobody has items to carry the tax or tip”), not a generic mismatch. A receipt that does not add up, a missing printed total and unclaimed units are reported first. A free-items bill with nothing to share is not blocked.

## Discounts and service charges

Manual adjustments in version one; the engine does not model discount pools yet. *(Existing product rule; unchanged.)*

## Invariants

The test suite must enforce these:

1. The sum of every person’s final amount equals the confirmed bill total, exactly, in cents (when the bill is settled and components reconcile).
2. For each unit, the sum of participant shares equals that unit’s price, exactly.
3. The sum of tax shares equals the tax, and the sum of tip shares equals the tip.
4. The same inputs always produce the same output, including which person receives a leftover cent.
5. Every leftover cent from largest remainder is an adjustment, in every pool (item units, tax, tip, service charge, printed tip), and is surfaced, never hidden.
6. A bill with any unclaimed unit is not treated as settled.
7. Participants have unique order indices, and a unit has one assignment row. The session keeps both; the calculator assumes them.
8. A negative custom tip or percentage is a tip of zero.
9. A bill with charges to share and no item that costs anything is never shareable, and is reported as such.

## Additional worked examples

### $3.50 shared by three (equal split, participant order A, B, C)

Unit price 350¢, equal weights. Floors 116¢ each; 2¢ remain. Remainders tie; earliest participants win: **A 117¢, B 117¢, C 116¢**.

### $12.00 appetizer shared by three

400¢ each; no remainder.

### Quantity line: 2× entrée $24.00 total, one unit to Alex, one unit split B+C

Unit prices 1200¢ + 1200¢. Alex 1200¢. B and C 600¢ each on the second unit.

### Zero-item person

Chris has no assigned items. Tax and tip weights are 0 → **0¢** tax, **0¢** tip, no leftover cents.

### Post-tax tip basis

Items subtotal 10000¢, tax 1000¢, 20% tip, post-tax basis: basis = 11000¢ → tip = (11000×20+50)/100 = 2200¢, then allocated by item subtotals.

### Custom tip

Fixed tip 1500¢ regardless of percent; allocated by item subtotals.

### One-person bill

All units assigned to the sole participant; that person owes the full confirmed total.

### All items shared

Every unit assigned to the same set of people; each pool splits equally across that set per unit, then tax/tip by subtotal weights.

### Many people, tax with leftover cents

Tax 100¢ split across three equal subtotals: shares 34¢, 33¢, 33¢ with adjustments on the two 33¢→34¢ steps per participant order among tied remainders.

## Proposals (not product decisions)

These are engine conventions chosen for v1 unless the project owner overrides later:

- **Unit price split within a line** uses “first `extra` units get the +1¢” (standard integer division spread), not largest remainder across units.
- **Split the rest evenly** assigns every participant to each unclaimed unit (equal split), not only participants with no items yet.
- **Pre-tax tip basis** uses the sum of **line totals on the receipt** (full items subtotal), even if some units are unclaimed; settlement still blocks until all units are claimed, but tip/tax weights use only **assigned** subtotals.

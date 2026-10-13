# Calculation rules

This is the most important part to get right before polishing the UI. The rules live in a pure `BillCalculator` with unit tests, independent of the interface.

## Worked example

Receipt: $100 item subtotal, $10 tax, $20 tip. Confirmed total: $130.

| Person | Items | Tax share | Tip share | Owes |
| ------ | ----- | --------- | --------- | ---- |
| Alex   | $60   | $6        | $12       | $78  |
| Sam    | $40   | $4        | $8        | $52  |
| Total  | $100  | $10       | $20       | $130 |

## Rules

- **Money:** all calculations use integer cents. Never floating point.
- **Shared items:** an item's price is split equally among the selected participants by default. A $12 item shared by three people is $4 each.
- **Tax:** allocated proportionally by each person's assigned item subtotal.
- **Tip:** the default is a percentage of the pre-tax subtotal, with a custom amount also available. Calculate the actual tip amount first, then allocate it proportionally by assigned item subtotal.
- **Rounding:** resolve any one-cent differences deterministically and display the adjustment to the user.
- **Receipt total:** compare the calculated total with the user's confirmed receipt total. If they differ, flag the discrepancy and let the user correct the inputs before sharing.
- **Discounts and service charges:** manual adjustments in version one. The app does not try to infer every receipt format automatically.

## Invariants

The test suite must enforce these:

1. The sum of every person's final amount equals the confirmed bill total, exactly, in cents.
2. The sum of item shares for an item equals that item's price, exactly.
3. The sum of tax shares equals the tax, and the sum of tip shares equals the tip.
4. The same inputs always produce the same output, including which person receives a leftover cent.
5. Every rounding adjustment is surfaced, never hidden.
6. A bill with unassigned items is not treated as settled.

## Principles

The app never claims recognition is perfect, and never silently produces a final split when the numbers do not reconcile.

## Decisions to make before implementation

- The deterministic rule for distributing leftover cents (for example, largest remainder, with ties broken by participant order).
- How a tip percentage is rounded to whole cents.
- How a person with a zero item subtotal is handled (they receive no tax or tip share).

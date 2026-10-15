# Reference calculator

An independent implementation of the bill-splitting rules in [`docs/CALCULATION_RULES.md`](../../docs/CALCULATION_RULES.md) and [`docs/BILL_SESSION.md`](../../docs/BILL_SESSION.md), used to check the Swift engine. Python 3, standard library only; nothing here is needed to build or test the app.

It was written from the documents, not ported from `BillCalculator.swift`. It uses exact rational arithmetic (`fractions.Fraction`): each share is the exact fraction, floored, and the leftover cents go to the largest fractional parts, ties to the earlier participant. The Swift engine reaches the same numbers with integer division and remainders, so a shared mistake would have to be a shared misreading of the document.

| File | Purpose |
| ---- | ------- |
| `reference_calculator.py` | `calculate(bill)`: per-person items, tax, service charge, printed tip, session tip, total and rounding adjustments, plus settlement and `canShare` |
| `test_reference_calculator.py` | Checks the reference against the worked examples in the documents |
| `generate_corpus.py` | Writes a seeded corpus of bills with the reference results as JSON |

## Commands

Run from this directory.

```bash
python3 -m unittest -v                                    # the reference against the document's examples

# The committed fixture (about 300 bills, read by the normal `swift test`)
python3 generate_corpus.py --count 300 --out ../../Tests/Fixtures/CalculatorProof/reference-corpus-300.json
python3 generate_corpus.py --count 300 --check ../../Tests/Fixtures/CalculatorProof/reference-corpus-300.json

# A large corpus, not committed
python3 generate_corpus.py --count 5000 --out /tmp/reference-corpus-5000.json
```

`Scripts/prove-calculator.sh` runs all of it, then compares 5,000 freshly generated bills with the Swift engine. See [`docs/CALCULATOR_PROOF.md`](../../docs/CALCULATOR_PROOF.md).

The corpus is a pure function of `(seed, count)`: each bill has its own SplitMix64 stream derived from the master seed and its index, so output is byte-identical on every Python 3, and the first 300 bills of a 5,000-bill corpus are the committed 300.

## Bill format

```jsonc
{
  "id": "bill-00042", "seed": "…",            // seed of this bill's stream (a string: 64-bit)
  "participants": [{"orderIndex": 0}, …],      // array order is input order; ties follow orderIndex
  "items": [{"quantity": 2, "lineTotalCents": 2401}],
  "assignments": [{"item": 0, "unit": 1, "participants": [0, 2]}],
  //   positions into "participants"; a position >= the participant count is someone who is
  //   not on the bill and must be ignored; repeated positions count once
  "taxLinesCents": [105, 30],                  // summed into the single receipt tax
  "printedTipCents": null,                     // tip line printed on the receipt
  "serviceChargeCents": 0,
  "sessionTip": {"kind": "percent", "percent": 18, "basis": "preTax"},  // or "postTax", or {"kind": "custom", "cents": 500}
  "printedSubtotalCents": 2401, "printedTotalCents": 2536,
  "expected": { … }                            // the reference results
}
```

A corpus file also has `allocations`: bare largest-remainder cases (`amountCents`, `weights`, `orderIndices`, `shares`, `adjusted`) that check the allocation rule without a bill around it.

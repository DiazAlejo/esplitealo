# Calculator proof

Evidence that every split the app shows matches an independent calculation to the cent. Nothing here adds a feature: the engine is [`BillCalculator`](CALCULATION_RULES.md) plus the session layer in [BILL_SESSION.md](BILL_SESSION.md), and this page says how far its correctness is established and what is left unproven.

Two kinds of evidence, both deterministic (every bill comes from a seed):

1. **Property tests** state rules that must hold for *every* bill, then check them on thousands of generated bills.
2. **A reference calculator** in Python, written from the documents and not from the Swift code, computes the expected result of thousands of bills. The Swift engine must match it per person, per field, exactly.

## What is proven

### Properties (27 generated properties, 1,000 bills each)

Swift Testing, in `Tests/EsplitealoCoreTests/CalculatorProof/`. Run names start with `CalculatorProof`. Bills vary people (1–9), items (0–16 lines), quantities up to 12, line totals that are not multiples of the quantity, assignments (solo, pairs, groups, everyone, unclaimed, people who are not on the bill, repeated people), tax from none to three lines, printed tip, service charge, tip as a percentage (pre- or post-tax) or a custom amount, printed subtotal and total (consistent, missing or off), and participant order (contiguous, with gaps, shuffled).

**`BillCalculator`**

| Property | Statement |
| -------- | --------- |
| Conservation | Item subtotals add up to the claimed units; tax shares add up to the tax; tip shares add up to the tip; on a settled bill everyone together owes exactly items + tax + tip, in integer cents |
| Surfaced rounding | For every pool, the number of adjustments equals the leftover cents (amount − Σ floors); each share is its floor plus one cent exactly when the person is adjusted; nobody is adjusted twice; adjustments are one cent each; shared units give their leftover cents to the earliest assignees |
| No negatives | No subtotal, tax, tip or amount owed is negative |
| Zero-item person | A person with no items owes zero tax, zero tip and receives no leftover cent |
| Array order | Shuffling the participant array and the assignment rows changes nothing: only `orderIndex` decides |
| Reordering | Re-assigning order indices keeps the total owed by everyone together. If no leftover cent exists anywhere, no share changes. Otherwise each person's total moves by at most a bound derived below |
| Tie-break | Between two people with equal item subtotals, the earlier one never gets less tax or tip, and never more than one cent more |
| Largest remainder | A person who received a leftover cent has a larger remainder than anyone who did not, or an equal one and an earlier order |
| Single owner | One person owning every unit owes exactly the bill, with no tax/tip rounding; everyone else owes zero |
| Quantity lines | A quantity line splits exactly like separate single lines at the documented unit prices |
| Tip | The tip is the unique integer with −50 < 100·tip − basis·percent ≤ 50 (nearest cent, halves up) on the pre-tax or post-tax basis; post-tax ≥ pre-tax; monotone in the percentage; a custom tip is returned as entered |
| Settlement | `isSettled` is true exactly when every unit has a real assignee; unclaimed units never leak into anyone's items |
| Split the rest | `splitRestEvenly` claims every unclaimed unit for everyone, leaves claimed units untouched, and is idempotent |
| Reproducibility | The same seed gives the same bill and the same result |

**Largest-remainder allocation** (the rule alone, random amounts and weights, with full ties): shares add up to the amount, each is its floor or floor + 1, people with no weight get nothing, and results follow the person rather than their list position.

**`BillSession`**

| Property | Statement |
| -------- | --------- |
| Totals | `derivedBillTotalCents` = items + tax + service charge + printed tip (never on top of a service charge) + session tip; each person's total is the sum of their parts; service, printed-tip, tax and tip shares each add up to their pool; a settled bill is owed exactly in full |
| Layers agree | The session's items, tax, tip and rounding adjustments are the calculator's |
| Zero-item person | Owes nothing in any pool |
| Unclaimed units | Any unclaimed unit means no `canShare`, no `.ready` or `.totals` phase, and an unsettled split. `canShare` implies settled, reconciled, people owing the derived total, and derived = printed + session tip |
| Shareable | A fully claimed bill whose printed amounts add up can be shared; changing the printed total by any amount, or removing it, blocks sharing |
| Finishing | `splitRestEvenly` on such a bill makes it shareable and leaves claimed units alone |
| Array order | Shuffling `participants` and `assignments` changes no breakdown |
| Edit sequences | After each of 40 random operations (add or remove people, assign, clear, split the rest, change tip, edit the draft) the order, assignments, unclaimed count, totals and phase stay consistent |
| Persistence | Encoding and decoding a session keeps every amount |
| Reproducibility | The same seed gives the same session |
| Participant order | `orderIndex` follows the order people were added through any add/remove sequence (this found the bug below) |

**Reorder bound.** Reordering moves a leftover cent from one person to another and nothing else. Let *s* be the number of units a person shares with others and *W* the sum of claimed line totals. Their item subtotal moves by at most *s* cents, and a tax or tip share is a floor of an exact quotient plus at most one cent, so tax moves by at most ⌈tax·s/W⌉ + 1 and tip by at most ⌈tip·s/W⌉ + 1. The test checks the sum of these three bounds for every person.

### Reference comparison

`Tools/reference-calculator/` computes, for each bill, every person's item subtotal, tax share, service share, printed-tip share, tip share, total, and the exact item units where they got a leftover cent, plus the bill's tip, derived total, settlement, reconciliation and `canShare`. It also checks 600 bare allocation cases. It uses exact fractions, not integer division, and was checked first against the worked examples in the documents (`test_reference_calculator.py`).

| Corpus | Bills | Allocation cases | Where it runs | Result |
| ------ | ----- | ---------------- | ------------- | ------ |
| `Tests/Fixtures/CalculatorProof/reference-corpus-300.json` | 300 | 300 | every `swift test` (about 0.15 s) | 0 differences |
| Generated, seed 20261015 | 5,000 | 600 | `Scripts/prove-calculator.sh` | 0 differences |

The sample deliberately includes bills the app must refuse: fully claimed bills whose printed total is off, bills with a missing subtotal or total, and bills with unclaimed units.

### Do the tests have teeth?

The tests were run against 18 deliberately broken copies of the engine (one change each: reversed tie-break, tip rounding down or half-down, leftover cents to the smallest remainder, extra unit cents on the last units, post-tax basis without tax, tip adjustments not surfaced, unclaimed units not unsettling, tax split evenly, duplicate assignees counted twice, zero-weight people eligible for leftover cents, custom tip clamped, service charge split evenly, printed tip allocated on top of a service charge, `canShare` ignoring settlement, the old participant-order bug, session tip basis without tax, `splitRestEvenly` ignoring unknown assignees). All 18 were caught by the full run (properties plus the 5,000-bill comparison). Two deserve a note:

- *Zero-weight people eligible for leftover cents* was caught only by the 5,000-bill comparison; the 300-bill fixture and the properties let it through. That case needs a rare tie, which is why the larger run exists.
- *`canShare` ignoring settlement* is caught only by the 5,000-bill comparison and is in practice an equivalent change: `canShare` also requires the people's totals to add up to the bill, which an unsettled split cannot satisfy.

The mutation harness is not part of the repository; each change is one line in `BillCalculator.swift` or `BillSession.swift` and the check is `swift test --filter CalculatorProof` with `ESPLITEALO_REFERENCE_CORPUS` set.

## What it found

- **Fixed: a person added after a removal could win a tie they should lose.** `BillSession.addParticipant` gave the new person `orderIndex = participants.count`. After removing someone, that repeats an index still in use (`[C2, D3]` + E → 2, + F → 3), so E ranked before D and took leftover cents that belong to the person added earlier. It now uses one past the highest index. Test: `CalculatorProofParticipantOrder`, which failed before the fix.
- **No discrepancy** between the Swift engine and the reference on 5,300 bills and 900 allocation cases, and none of the 27 properties failed on the calculator.

## Open questions for the owner

The documents do not settle these, so the tests do not decide them and no behaviour was changed. For each: what the Swift engine does today, how the reference reads the document, and a recommendation for the owner to accept or overrule.

1. **Service charge and printed-tip leftover cents are not surfaced.** Invariant 5 says every largest-remainder adjustment is surfaced and "nothing is silent", but only item-unit, tax and tip pools are listed.
   - *Engine:* `BillSession` splits a service charge and a printed tip by largest remainder through `SessionPoolAllocator`, then drops their adjustments, so `PersonBreakdown.adjustments` never shows them. In the 5,000-bill sample, 1,490 bills (30%) hand out at least one such cent.
   - *Reference:* allocates both pools by the same rule (the amounts match the engine exactly) and does not record adjustments for them, mirroring the pool list in the document.
   - *Recommendation:* treat service charge and printed tip as pools under invariant 5 and surface their cents in the UI; the amounts do not change.
2. **A bill whose items are all free but has tax, tip or a service charge** (or has no items at all).
   - *Engine:* with total weight zero nothing is allocated, so people owe less than the bill, and `canShare` is false. 250 of 5,000 sample bills are like this.
   - *Reference:* the same: weight zero allocates nothing, the people's totals fall short, `canShare` is false.
   - *Recommendation:* keep it blocked, and have the UI say why (nobody has items to carry the tax or tip) rather than showing a generic mismatch.
3. **Two people with the same `orderIndex`, or two assignment rows for the same unit.**
   - *Engine:* `BillSession` can no longer create either. Given directly, `BillCalculator` depends on sort stability for equal indices and uses the first of several rows for a unit.
   - *Reference:* assumes unique order indices and one row per unit, as the document says ("stable participant order", "one set per unit").
   - *Recommendation:* state in the rules that both are invariants of the session; no engine change needed.
4. **A negative custom tip or percentage.**
   - *Engine:* treated as zero.
   - *Reference:* does not generate negative tips; the document does not say.
   - *Recommendation:* document "negative tip = 0" (the UI should not allow it anyway).
5. **Wording of "surfacing adjustments"** ("whenever step 5 gives a cent to someone whose initial quotient was not already the maximum possible").
   - *Engine:* records an adjustment for every leftover cent.
   - *Reference:* the same, which makes the quoted condition always true.
   - *Recommendation:* reword to "every leftover cent is an adjustment".

## What is not covered

- **Discounts and proportional discount allocation**: out of scope (R-29). Generated bills have no adjustment rows.
- **Receipt parsing and OCR**: only what happens after a draft exists. Tax lines are summed into one tax before the engine sees them, as the parser does; allocating each tax line separately could differ by a cent and is not what the rules say.
- **UI, share text and formatting**: money is checked as integer cents, not as displayed.
- **Negative amounts, amounts above about 10⁷ cents per line, more than nine people**: not generated.
- **Arithmetic overflow**: not provoked; amounts stay far below `Int.max`.
- **Phase and `shareBlockReason` precedence**: the documents list the reasons but not their order, so only `canShare`, the unclaimed-unit rule and the missing-total reason are checked.
- **Both implementations read one document.** Where the document is ambiguous (see above) the two can agree on the same misreading; the questions above are exactly the places to look.
- **The Swift test harness mirrors the corpus format**, and the reference shares the same bill format. A bill that cannot be expressed in the format is not tested.

## Running it

```bash
swift test --filter CalculatorProof                  # all properties + the 300-bill fixture, a few seconds
Scripts/prove-calculator.sh                          # also the reference's own tests, fixture check, and 5,000 fresh bills
BILLS=20000 SEED=7 Scripts/prove-calculator.sh       # a different, larger corpus
```

`swift test` needs no Python. The 5,000-bill comparison runs only when `ESPLITEALO_REFERENCE_CORPUS` points at a corpus file; `Scripts/prove-calculator.sh` generates one in a temporary directory and sets it.

### Reproducing a failure

A failing property prints its seed and the replay command:

```
seed 15018734274149711: step 31: orderIndex [4, 7, 6, 4] is not strictly increasing
  (replay: ESPLITEALO_PROOF_SEED=15018734274149711 swift test --filter CalculatorProof)
```

`ESPLITEALO_PROOF_SEED=<seed>` makes every property run exactly that one bill. `ESPLITEALO_PROOF_BILLS=<n>` changes how many bills each property checks (default 1,000, in batches of 25).

For a reference mismatch, the report names the bill (`bill-00042`, with its seed) and the first differing fields. Find it in the JSON by `id`.

### Regenerating the committed fixture

Only needed if the generator or the reference changes.

```bash
cd Tools/reference-calculator
python3 generate_corpus.py --count 300 --out ../../Tests/Fixtures/CalculatorProof/reference-corpus-300.json
python3 generate_corpus.py --count 300 --check ../../Tests/Fixtures/CalculatorProof/reference-corpus-300.json
```

The corpus is a pure function of `(seed, count)`; `--check` fails if the committed file is not what the generator writes. Changing a rule in [CALCULATION_RULES.md](CALCULATION_RULES.md) means changing `reference_calculator.py` from the document, regenerating, and seeing the Swift tests fail until the engine follows.

CI runs the fixture comparison and the properties in the required macOS job. The reference's unit tests and the fixture check run in a separate Linux job that does not block merging (see [CI.md](CI.md)).

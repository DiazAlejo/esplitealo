# Tab analysis

Research notes on Tab, an existing iPhone bill-splitting app, written to inform the calculation engine, the receipt parser, and the review flow.

This is research, not specification. Nothing here changes a requirement or a rule. Every item under [Candidate rules for Esplitealo](#candidate-rules-for-esplitealo) is a **proposal** for the captain to accept, change, or reject.

## Summary

- Tab is a free, US-only iPhone app. Its differentiator is multi-device: friends join one bill with a short code and claim their own items, synced through the developer's servers. It also has accounts, Venmo and cash-app payments, and many analytics SDKs. Esplitealo deliberately has none of these.
- Tab does money math in floating point and rounds to cents only at allocation points. It never re-rounds the final per-person total, never checks the calculated total against the receipt total, and never shows a rounding adjustment. Esplitealo's integer cents, receipt-total check, and visible adjustments are an improvement, not a copy.
- The leftover cent in a shared item does not go to a fixed person. Tab orders the sharers by internal id, ascending or descending depending on the parity of the amount, so the result is deterministic but looks arbitrary.
- Tax, included tip, and discounts form one pool; the tip the user chooses is a second pool. Both are allocated by each person's share of the item subtotal.
- Tab computes the tip as a percentage of the item subtotal before tax and before discounts. This is its most-cited calculation complaint.
- Receipt reading is mostly server-side. The device scales and compresses the photo, then either uploads it or runs Apple Vision and uploads the recognized text with its geometry. A server builds the bill. There is no on-device parser to learn from, so Esplitealo's parser has to be built from scratch.
- The most useful lessons are Tab's failure modes: totals and tip lines read as items, quantity lines, dropped items on long receipts, wrong tax, and weak import quality. The parser and review screen need to absorb all of them.

## How the research was done

Two read-only passes over Tab 3.128.0 (iOS, arm64), plus public material. The app was never run, signed in, or contacted, and nothing was decrypted.

| Pass | Method | What it gave |
| ---- | ------ | ------------ |
| Teardown | Metadata, string tables, bundled sample data, and shipped screenshots of the installed app, plus the public listing, FAQ, privacy policy, and 400 recent App Store reviews. No disassembly. | Feature inventory, user complaints, receipt failure modes, adopt / adapt / avoid list. |
| Native analysis | Decompiled and disassembled the installed binary with a headless reverse-engineering tool. A scratch reimplementation of the recovered algorithm reproduced every worked example and was fuzz-checked on 3000 random bills. | The actual calculation, divide, birthday, and receipt-upload behaviour. |

**Precedence.** Where the two passes disagree, the native analysis wins, because it read the code. Differences are called out in [Where the two passes disagree](#where-the-two-passes-disagree).

**Confidence.**

- High: what ships in the app (features, strings, settings, data fields) and anything read directly in decompiled code, such as rounding mode, allocation pools, divide, and the receipt pipeline structure.
- Medium: numbering of the server-chosen receipt routes, the exact tip and tax behaviour in rare ties, and review-derived counts. Review counts are keyword tallies over a 400-review sample and are order-of-magnitude only.
- Low: anything about Tab's server, including how it parses rows into items.
- Screenshots and public pages are older than the current version; reviews from 2026 describe the same structure.

**Limits.** One 4 KiB page of the executable is encrypted and was not read. It holds app-launch setup and some person-name validation. The calculation, divide, birthday, assignment, and receipt-upload code are outside it.

## Tab's feature inventory

The scope column is a suggestion for Esplitealo: **In scope** means it belongs in the MVP, possibly done differently; **Later** means roadmap or post-MVP; **Out of scope** means it contradicts the product principles or is not worth building.

| Area | What Tab does | Scope for Esplitealo |
| ---- | ------------- | -------------------- |
| Capture | Full-screen camera with a tilt warning, tap to focus, and a "skip photo" path to enter items by hand | In scope: tilt hint and manual path (R-3, R-9) |
| Import | Photo-library import; reviews report crashes, blurry results, and a button hidden under system UI | In scope (R-2), at full resolution |
| Denied camera | Explains how to enable it and offers manual entry | In scope (R-3) |
| Post-read warnings | Flags for "check the items", "no tax detected", "foreign currency detected", and "no items found" | In scope: maps onto R-13 and R-9 |
| Receipt photo | Saved locally but cannot be viewed while editing (7 reviews ask for it) | In scope: keep it visible during review and assignment (R-12) |
| Items | Edit, add, delete by swipe; deleting an item warns that owners will be removed | In scope (R-10) |
| Divide | Splits one line into N equal child items and discards the original and its claims | In scope as an idea (quantity-aware lines); do it non-destructively |
| People | Short-name strip; names limited to about 4–5 characters; unique names; deleting blocked in some cases | In scope (R-15) without the length cap |
| Assignment | Person-first: select a person, tap items to toggle claims; several claimants make an item shared; one accent colour for everyone | In scope (R-18, R-19), with per-person colours and undo |
| Live subtotal | Per-person subtotal updates as claims change | In scope (R-21) |
| Unclaimed items | Count shown before continuing, and an "unclaimed amount" row; does not block | In scope, stricter: unassigned is not settled (R-20) |
| Tax | Amount only, no percent entry; the top functional complaint (14 of 400 reviews) | In scope (R-11); also accept a percent converted to cents |
| Tip | Percent stepper or manual amount, applied to the pre-tax subtotal; default 18% from server config | In scope (R-24), with a stated basis |
| Included tip | Receipt gratuity shown as its own row, with an optional extra tip on top | In scope as a general extra charge |
| Discounts | Amount only, deducted proportionally | Later (R-29 keeps them manual in v1) |
| Per-person detail | Items with "shared with", items subtotal, pre-tip total, and tip with its basis | In scope (R-26) |
| Grand-total check | Only blocks a computed total below about one cent; no comparison with the receipt | In scope: Esplitealo's check is a differentiator (R-28) |
| Share text | Share sheet with a per-person summary; reviews say tax and tip lines are missing | In scope (R-30), with tax and tip lines |
| Birthday treat | Covers one person's cost by everyone else | Later |
| Share code and multi-device sync | Five-digit code, polling and push, join window | Out of scope |
| Payments | Venmo, a cash app, and a cash ledger; 82 of 400 reviews mention Venmo, mostly to say it will not connect | Out of scope |
| Accounts | Optional magic-link e-mail login; bills vanish after days without one | Out of scope (no accounts) |
| Bill history | Server-side list of past bills | Later, local only (R-32) |
| Settings | Dark mode, nickname, payment links, FAQ, cross-promotion | Dark mode only |
| Currency and locale | Currency symbol and locale come from the server; US storefront only | Later, but store minor units rather than dollars |
| Telemetry | About ten analytics, ad-attribution, and crash SDKs | Out of scope (private by default) |

## How Tab calculates

### Overview

- All amounts are `double` values, and amounts read back from the bill's summary fields pass through a 32-bit `float`. That is why sample payloads show values like 16.30 stored as 16.2999992.
- Cents are rounded only where an amount is allocated, using decimal rounding **half up to two decimals**.
- A person's final total is a plain sum and is never re-rounded. Display formatting rounds.
- The bill keeps seven summary amounts: subtotal, included tip, user tip, discounts, tax, total, and additional tip.

### Shared item

The people who claimed an item are ordered by internal id. The order is **ascending when the item price, rounded half up to a whole number, is even, and descending when it is odd**. Ad-hoc people get decreasing negative ids (−1, −2, …) in creation order, so the most recently added ad-hoc person has the smallest id.

```text
owners  = people who claimed the item
ordered = owners sorted by id, ascending if round_half_up(price) is even, else descending
parts   = split(price, count(owners))        # ascending list, zero parts dropped
share(p) = parts[position of p in ordered]   # 0 if the list is shorter than the group
```

### The split routine

Used for shared items, Divide, and the birthday treat.

```text
split(amount, n):
    if n < 1 or amount <= 0: return []
    parts = n copies of round_half_up_2(amount / n)
    reconcile(amount, parts, skip_zero = false)
    drop zero parts
    sort ascending
```

### Reconcile (±1 cent)

```text
target = round_half_up_2(total)
shares = each share rounded half up to 2 decimals
eligible = positions whose rounded share is nonzero   # fixed at the start; all positions if skip_zero is false
while sum(shares) != target:
    if sum(shares) < target: add 0.01 to the first smallest eligible share
    else:                    subtract 0.01 from the first largest eligible share
```

"First" follows the id-sorted allocation order. If every rounded share is zero (for example 0.01 of tax over several people), nobody is eligible and the cent disappears.

### Two allocation pools

```text
pool1 = tax + included_tip - discounts
pool2 = additional_tip if included_tip > 0 else user_tip

weight(q) = (items(q) + birthday_share(q)) / all_item_subtotal    # 0 for birthday people, 0 if subtotal <= 0

allocate(pool, weights):
    order people by id (same parity rule, using round_half_up(pool))
    share_q = pool * weight_q
    if no unclaimed items: reconcile(pool, shares, skip_zero = true)
    else:                  round each share half up, no reconcile

total(p) = items(p) + allocate(pool1)[p] + allocate(pool2)[p]
```

Reconcile runs **only when no item is unclaimed**. With unclaimed items the shares are rounded independently and can sum to less than the pool.

### Tip amount

- Tip = percent ÷ 100 × the sum of all item amounts. It is taken before tax and before discounts, with no rounding at that step.
- The percent is a derived, unrounded value: amount × 100 ÷ subtotal. When items change, both tip amounts are recomputed from the remembered percentages.
- An included tip on the receipt takes the place of the user's tip in the total; the user can then add an "additional tip" on top.

### No receipt-total check

The bill total is **overwritten** with the computed value: items + included tip + (user tip or additional tip) − discounts + tax. The only gate is that the computed total must be at least about one cent. Tab never compares against the printed receipt total.

### Divide

Divide on an item removes it and every person's claim on it, then adds N unclaimed items with the same name at the same row. Amounts come from the split routine, so zero parts are dropped and the list is ascending. There is no undo.

### Birthday treat

- The treated person's **item subtotal** is split among the others with the split routine and added to each recipient's subtotal.
- Each recipient's enlarged subtotal is then used as the weight for tax and tip.
- The treated person's weight is zero and their total is zero.
- The teardown described this as an equal split of the person's grand total; the native analysis shows it is an item-subtotal split before tax and tip.

### Other behaviour

- Payments recorded in the app are added into a person's total. Out of scope here.
- Person names must be unique with an exact, case-sensitive match. Other name rules were not recovered.
- Tab is server-synchronised for the whole editing session, and every change flags a push.

## Worked examples

Names are placeholders. Ann, Ben, and Cat were added in that order, so their ids are −1, −2, −3.

### Shared item, 3.50 among three

3.50 ÷ 3 is 1.1667, so each share rounds to 1.17 and the sum is 3.51, one cent over. One 1.17 drops to 1.16, giving the ascending list [1.16, 1.17, 1.17]. The price rounds to 4, which is even, so the order is ascending ids: Cat, Ben, Ann.

| Person | Share |
| ------ | ----- |
| Ann | 1.17 |
| Ben | 1.17 |
| Cat | 1.16 |

### Shared item, 3.40 among three

The parts are [1.13, 1.13, 1.14]. The price rounds to 3, which is odd, so the order is descending ids: Ann, Ben, Cat.

| Person | Share |
| ------ | ----- |
| Ann | 1.13 |
| Ben | 1.13 |
| Cat | 1.14 |

The same group therefore gets the short cent in a different seat depending only on the price.

### Tax split three ways

| Pool | Shares before reconcile | Order | Result |
| ---- | ----------------------- | ----- | ------ |
| Tax 1.00 | 0.33 × 3 = 0.99, one cent short | 1 is odd: descending ids, first minimum is Ann | Ann 0.34, Ben 0.33, Cat 0.33 |
| Tax 2.00 | 0.67 × 3 = 2.01, one cent over | 2 is even: ascending ids, first maximum is Cat | Cat 0.66, Ben 0.67, Ann 0.67 |

### Divide

| Item | Result |
| ---- | ------ |
| 7.00 ÷ 2 | 3.50, 3.50 |
| 1.00 ÷ 3 | 0.33, 0.33, 0.34 (children appear in this order) |
| 0.02 ÷ 3 | 0.01, 0.01 (zeros dropped, so the last sharer gets 0) |
| 0.01 ÷ 2 | 0.01 |

### A bill with one person's detail

Sample bill: items 81.50, tax 7.23, tip 20% = 16.30, total 105.03. One person's items are 4.25.

- Tax share: 7.23 × 4.25 ÷ 81.50 = 0.377, which rounds to 0.38.
- Pre-tip amount: 4.25 + 0.38 = 4.63.
- Tip share: 16.30 × 4.25 ÷ 81.50 = 0.85.
- Total: 4.25 + 0.38 + 0.85 = 5.48.

### Two-person bill

Ann has A 10.00 and half of a shared 20.00 pizza. Ben has the other half and B 5.00. Tax 3.33, tip 20% of 35.00 = 7.00.

| Person | Items | Tax | Tip | Total |
| ------ | ----- | --- | --- | ----- |
| Ann | 20.00 | 1.90 | 4.00 | 25.90 |
| Ben | 15.00 | 1.43 | 3.00 | 19.43 |
| Sum | 35.00 | 3.33 | 7.00 | 45.33 |

### Birthday treat

Ann is treated and had 10.00. Ben and Cat each had 20.00. Tax is 5.00, no tip.

- Ann's 10.00 is split 5.00 each to Ben and Cat, so their subtotals become 25.00.
- Weights are 50% each, so each pays 2.50 of tax.
- Ann 0.00, Ben 27.50, Cat 27.50. Sum 55.00.

### Checks from the scratch model

In 3000 random bills with 2–5 people and no unclaimed items, shared-item shares always summed to the price (for prices of 0.02 or more) and tax shares always summed to the tax, except five cases where the tax was 0.01 and every rounded share was zero.

## Receipt reading

### Tab's pipeline

1. The photo is scaled so its longest side fits a configured maximum (default 1650 px) and JPEG-compressed at a configured quality (default 0.5). Both can be overridden by the server.
2. A server-delivered weighted configuration picks a route by random draw. An empty list means "upload the image".
3. **Image route:** the JPEG is uploaded and the server reads it, possibly through an outside OCR vendor.
4. **Vision route:** Apple Vision recognizes text on the device, and the recognized text, boxes, and timings are uploaded as JSON. The photo is not uploaded on this route.
5. The server returns the whole bill: items, tax, tip, and discount amounts, people, currency symbol, and locale. The app only ingests it.

There is no on-device classification of rows into items, tax, tip, or total. Tab's server does that, so there is nothing to copy for Esplitealo's parser.

### Named failures

- Recognition failed: the on-device Vision request threw an error.
- Bill mismatch: the server answered for a bill that is no longer the open one. It is a session check, not a totals check.
- No items found: the response had no items, or an empty list.
- Zero tax and foreign currency are flagged from the server response. Nothing on the device compares the currency with the device locale.

### Failure modes seen in reviews and mitigations

| Failure | Mitigation for the on-device parser and review screen |
| ------- | ------------------------------------------------------ |
| Subtotal, tax, total, and tip lines read as items, causing double counting | Classify label rows (subtotal, tax, total, tip, service) and never emit them as items; show an "items sum vs subtotal" delta |
| Printed suggested-tip table captured | Ignore blocks after tip or gratuity headings; allow a region to be ignored |
| Items dropped on long receipts; multiple images unsupported | Show an item count and sum check; allow adding more items; stitched or multi-image capture later |
| Quantity and unit-price columns parsed as one lump | Detect `qty × unit = total` and a leading integer; offer explicit units |
| Wrong prices, misread tax, invented tip, lost minus signs on discounts | Everything editable; flag suspicious values (R-13); never change the receipt total silently (R-14) |
| Library import much worse than camera; screenshots blurry | Use full-resolution input; do not downscale the way Tab does |
| Several tax lines summed wrongly | One editable tax total, with detected tax lines shown |
| Negative lines (coupons, voids) and duplicate rows | Signed amounts in the model; flag duplicates |
| Timeouts and "no internet" errors after capture | Removed by design: recognition is on device |
| Non-US currency printed as US dollars | Decide a currency-detection rule explicitly; store minor units |

Consider a fast and an accurate Vision recognition setting, as Tab's configuration offers.

## Adopt, adapt, do differently

### Adopt

- Warning banners for suspicious reads: zero tax, foreign currency, no items found, and "check the items".
- Unclaimed-item count and an unclaimed-amount row in the summary.
- Camera guidance: tilt warning, shoot from above, tap to focus.
- Denied-camera message with a skip-to-manual option.
- Per-person expandable detail with items, who shares them, items subtotal, subtotal plus tax, and the tip with its basis.
- Light, dark, and system appearance.
- Proportional allocation of discounts, tax, and tip by item subtotal.

### Adapt

- Quantity handling: a quantity-aware item with quantity, unit price, and line total, assignable per unit, instead of Tab's destructive Divide. Add undo.
- Tip basis: pre-tax by default, with a labelled alternative; a one-tap no-tip option; cents in custom amounts.
- Tax entered as an amount or a percent, stored in cents.
- Per-person colours and a person-first claim mode alongside the item-first picker.
- Birthday treat as a later "cover someone's share" action on cents.
- Share text with a per-person block of items, tax, tip, total, and tip basis.
- Optional local bill history with editable names and saved names; the receipt photo visible beside the items.

### Do differently

- Integer cents, determinism, visible rounding adjustments, and a receipt-total check.
- On-device only: no accounts, no backend, no analytics, no payments in the MVP.
- No server-side bill lifetime; local history never expires.
- No short name cap and no default tip that applies to non-restaurant bills.
- Controls clear of the Dynamic Island and the home indicator.
- No multi-device live sync in the MVP.

## Candidate rules for Esplitealo

Everything in this section is a **PROPOSAL**. None of it is decided and none of it is in `docs/CALCULATION_RULES.md`. The proposals restate the native report's recommended rules 1 to 13.

Open decisions the captain has not yet made, referenced below: **tip basis**, **quantity-aware lines**, **assignment style**, **leftover-cent rule**, **unclaimed-items handling**, **tip rounding**, and **zero-item person**.

| # | PROPOSAL | Open decision it touches |
| - | -------- | ------------------------ |
| 1 | **Number type.** All amounts are integer minor units. Percentages are stored as integer basis points or exact rationals, never floats. Intermediate allocations use exact rational arithmetic and round once at the end of each allocation. | None (already N-3). |
| 2 | **Leftover cent.** To split amount A (cents) among weights wᵢ ≥ 0 with total W > 0, each person first gets floor(A × wᵢ ÷ W). The remaining cents, between 0 and N−1, go one each to the largest fractional remainders, ties broken by participant order (earliest added first). The result is deterministic and sums exactly to A. An optional variant rotates the tie-break start by item position instead of always favouring the earliest participant. | **Leftover-cent rule.** |
| 3 | **Item split.** A shared item of price P among N people uses rule 2 with equal weights, in participant order. Shares sum to P. Example: 3.50 ÷ 3 gives 1.17, 1.17, 1.16 with the order stated. | **Leftover-cent rule.** |
| 4 | **Tax and service pools.** Tax, included tip or service charge, and discounts are signed amounts allocated with rule 2, using each participant's share of the item subtotal as the weight. Discounts reduce the pool, not the tip base. The tip is allocated separately so the UI can show each line. | Touches **tip basis** (discounts and the tip base). |
| 5 | **Tip base and amount.** The tip is computed once from the percentage of the pre-tax, pre-discount items subtotal, rounded half up to whole cents. The percentage is stored as entered, not re-derived from the amount. | **Tip basis**, **tip rounding**. |
| 6 | **Included versus additional tip.** If the receipt already includes a gratuity, treat it as a charge allocated proportionally with tax, and let the user add an additional tip on top. Otherwise there is a single tip. | **Tip basis.** |
| 7 | **Zero-item person.** A person with zero weight receives zero tax, service, and tip, and never receives a leftover cent. | **Zero-item person.** |
| 8 | **Unassigned items.** Keep the existing Esplitealo rule: a bill with unassigned items is not settled. Do not copy Tab, where unclaimed items silently change the allocation. | **Unclaimed-items handling.** |
| 9 | **Totals gate.** Keep the existing rule that blocks sharing when the calculated total differs from the confirmed receipt total. Tab has no such check, so this is a differentiator and a risk: the user needs a clear way to confirm or correct the receipt total. | None (already R-28). |
| 10 | **Surface adjustments.** Keep showing every rounding adjustment. Tab shows none. | None (already R-27). |
| 11 | **Divide, if kept in scope.** Dividing an item of price P into N parts replaces it with N new unassigned items of the same name, amounts from rule 2 with equal weights, ordered either largest to smallest or in assignment order (pick one and document it). Tab discards claims on Divide and drops zero parts; whether claims carry over to the children is open. | **Quantity-aware lines**, **leftover-cent rule**; touches **assignment style** through claim handling. |
| 12 | **Birthday treat (stretch).** The treated person's item subtotal T is split among all other participants with rule 2 and equal weights, and added to each one's item subtotal before tax and tip are allocated. The treated person's tax, tip, and total are zero. If every participant is marked, reject the action. | **Leftover-cent rule.** |
| 13 | **Name rule.** Names are trimmed and must be unique, compared case-insensitively. | None. |

Two further points come from the teardown and are not in the native report's rules:

- **Assignment style.** Tab is person-first (select a person, tap items); `docs/SCREENS.md` is item-first (tap an item, pick people). The teardown suggests supporting both, with per-person colours. This is the **assignment style** decision.
- **Tip basis.** The teardown suggests a per-bill choice between pre-tax and post-tax. Rule 5 above keeps pre-tax; the choice remains open.

## Golden tests

These are the worked examples as a test table. The **Tab** column is behaviour Tab has. The **Esplitealo** column shows what proposal 2 would produce **if adopted**; it is not decided. Where the two differ, Esplitealo deliberately differs from Tab, and the Tab result should be kept only as a "behaviour we do not copy" fixture.

| # | Case | Tab result | Esplitealo (proposed) | Differs |
| - | ---- | ---------- | --------------------- | ------- |
| G1 | 3.50 shared by Ann, Ben, Cat (added in that order) | Ann 1.17, Ben 1.17, Cat 1.16 | Ann 1.17, Ben 1.17, Cat 1.16 | Same numbers here by coincidence of order; Tab's order depends on ids and price parity |
| G2 | 3.40 shared by Ann, Ben, Cat | Ann 1.13, Ben 1.13, Cat 1.14 | Ann 1.14, Ben 1.13, Cat 1.13 | Yes: Tab flips the order with the price parity |
| G3 | Tax 1.00 over three equal weights | Ann 0.34, Ben 0.33, Cat 0.33 | Ann 0.34, Ben 0.33, Cat 0.33 | No |
| G4 | Tax 2.00 over three equal weights | Cat 0.66, Ben 0.67, Ann 0.67 | Ann 0.67, Ben 0.67, Cat 0.66 | Yes: Tab gives the short cent to the newest person |
| G5 | Tax 0.01 over three equal weights | The cent disappears (allocated 0.00) | One person gets 0.01 by participant order | Yes: Tab bug, never copy |
| G6 | Divide 7.00 by 2 | 3.50, 3.50 | 3.50, 3.50 | No |
| G7 | Divide 1.00 by 3 | 0.33, 0.33, 0.34 (ascending) | 0.34, 0.33, 0.33 (participant order) or as ordered by rule 11 | Order depends on the open choice in rule 11 |
| G8 | Divide 0.02 by 3 | 0.01, 0.01 (zero part dropped) | 0.01, 0.01, 0.00 (decide whether a zero part is allowed) | Yes: Tab shortens the list |
| G9 | Sample bill, one person with items 4.25 (tax 7.23 on 81.50, tip 16.30) | Tax 0.38, tip 0.85, total 5.48 | Tax 0.38, tip 0.85, total 5.48 | No (single-person view) |
| G10 | Two-person bill: A 10.00 (Ann), pizza 20.00 (Ann and Ben), B 5.00 (Ben); tax 3.33; tip 7.00 | Ann 25.90, Ben 19.43 | Ann 25.90, Ben 19.43 | No |
| G11 | Birthday: Ann (treated) 10.00, Ben 20.00, Cat 20.00, tax 5.00 | Ann 0.00, Ben 27.50, Cat 27.50 | Same (later feature) | No |
| G12 | Unclaimed item exists | Pools are rounded per person with no reconcile, so shares can sum to less than the pool | Not allowed to settle (rule 8) | Yes |
| G13 | Printed receipt total differs from calculated total | Total silently overwritten, no block | Sharing blocked until corrected (rule 9) | Yes |

G1 to G4 and G7 use participant order Ann, Ben, Cat for the proposed column. The G10 and G11 figures are in whole cents and need no leftover-cent tie-break. Re-derive the proposed column from the rules when writing the tests, since the rules are not final.

## Where the two passes disagree

The native analysis wins in each case.

| Topic | Teardown | Native analysis |
| ----- | -------- | --------------- |
| Image upload | Unclear whether the live app uploads the image | The JPEG is uploaded on the default and some routes; on the Vision route only recognized text and boxes are uploaded |
| Bill mismatch | Guessed to mean line items not matching totals | A session check: the server answered for a bill that is no longer the open one |
| Recognition failure | Unknown | The on-device Vision request threw an error |
| Leftover cent | Guessed a float-based sequential allocation | Id order combined with amount parity, then a ±1 cent reconcile |
| Rounding mode | Unknown | Half up to two decimals at allocation |
| Per-person rounding | Each person rounded independently | Allocation is reconciled to the pool, but only when nothing is unclaimed |
| Tip percent | Whole-number only | Derived from the amount, unrounded; the UI shows an integer |
| Birthday | Equal split of the person's grand total | The person's item subtotal is split first, then tax and tip weights use the enlarged subtotals |
| Total check | No reconciliation found | Confirmed: the total is overwritten with the computed value |

## Still unknown

1. The server-delivered weights for the receipt routes today, and the numbering of the variants (the code only shows the mechanism and the default).
2. How Tab's server parses rows into items and detects tax, tip, discounts, zero tax, and foreign currency.
3. Person-name validation beyond uniqueness (inside the encrypted page).
4. How the server numbers ad-hoc people, and therefore the true on-screen order for the leftover-cent rule.
5. The result of `NSDecimalNumber` conversion for exact half-cent ties; the model may differ from Tab by one cent in rare cases.
6. Whether any screen lets the user edit the total row in a way that is later compared.
7. The rule that enables Divide and any limit on N.
8. Behaviour when every person is marked for the birthday treat.
9. Code in the encrypted page, including app-launch setup.
10. The random source and caching of the route draw (per photo or per user).
11. Ground truth for rounding from a manual run of probe bills (for example 10.00 shared by three, 0.01 shared by two) through Tab's manual-entry path.

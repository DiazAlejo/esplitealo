# Receipt parsing

Pure Foundation logic in `EsplitealoCore` that turns on-device OCR output into a conservative `ReceiptDraft` for the review screen. It does not call Vision, read images, or change confirmed totals.

## Input: `RecognizedText`

`ReceiptScanner` in `EsplitealoScanning` wraps Vision’s `RecognizeTextRequest` and produces a `RecognizedText` value (see `docs/SCANNING.md`):

- `imageSize` in pixels
- `lines` with full-line text, confidence, baseline angle, and per-word boxes
- Pixel coordinates use a **top-left origin** (converted from Vision’s bottom-left normalized boxes)

Parser tests replay committed JSON under `Tests/Fixtures/Receipts/` so CI does not need a camera.

## Pipeline

1. **Row reconstruction** (`RowBuilder`): collect all word boxes, de-skew by the median baseline angle of wide lines, cluster by *y* (within ~0.55× median line height), then split into cells by horizontal gaps (~1.6× line height). This pairs item names with prices when Vision emits them as separate observations.
2. **Word repair**: merge split decimals (`40.` + `000`), glued `@` prices, and drop standalone currency tokens.
3. **Line split**: trailing tokens become amounts (percent tokens like `7%` are never amounts); a small integer before other amounts on the same row is treated as quantity (`1 @20.00 20.00`).
4. **Locale vote** (`NumberFormatInference`): infer decimal vs thousands separators once per receipt; ambiguous zero-decimal shapes (e.g. `32.000`) and 4+ digit plain integers are flagged as guessed. USD cents (Puerto Rico) is the default when the vote is inconclusive.
5. **Classification**: fuzzy keyword match for subtotal, tax (including **IVU**), tip/gratuity/service, total, discount, payment, and suggested-tip tables (not items). Scope is Spanish/English keywords, Puerto Rico, USD only. Discount rows are always stored as negative adjustments, whether or not the receipt prints a sign.
6. **Items**: lines with both label and amount above the footer boundary; support `2 x` / `2 @` quantity prefixes; name/price on adjacent rows; optional modifier notes (`+ …`); ignore payment and tip-table rows after totals.
   - **Column headers**: a row made only of table-heading words (`Items Price`, `Artículo Precio`, `Qty`, `Description`, …) is skipped.
   - **Multi-row names**: the price is read from the right-hand column of the *first* row. Directly following rows that have letters but no amount (modifier/variant rows such as `Negro` or `Marrón`) are appended to the name, so `Sombrero Cowboy $34.50` / `Negro` is one item named `Sombrero Cowboy Negro`. A continuation row must sit one normal line below and roughly under the previous row’s left edge, must not start with `+`/`-` (those stay notes), and must not be a name whose price is on the next row.
   - **Quantity rows**: a standalone `(N x $price)` / `N x $price` / `N @ $price` row under an item sets the quantity to *N* and the unit price to *price*; the figure on the first row stays the line total and is never rewritten. If *N* × unit price does not equal the line total (or an explicit `2 x` prefix says something different), the item keeps the printed line total and is flagged `quantityMismatch` + `needsReview` instead of guessing. A quantity row with no item above it becomes an `unparsedPriceRow` issue.
   - **Identifiers are not prices**: a token that mixes letters with a long digit run (card AID `(A0000000031010)`, `MID`-style ids) is never an amount.
7. **Taxes**: every line classified as tax (`tax`, `impuesto`, `IVU`, `IVA`, `VAT`, including `STATE TAX (10.5%)` + `COUNTY TAX (1%)`) is summed into one `tax` amount. A tax line repeated *after* the total (a tax summary in the payment block) is ignored once a tax is already known, so it is not double counted. If one tax line equals the sum of the others (a combined `Total Tax` / `Tax Summary` line printed with the individual lines), only the individual lines are counted. If a line labelled total/summary tax does not match the sum of the others, the reading that reconciles with subtotal + tax + tip = total is kept when exactly one does; otherwise the tax is flagged `needsAttention` for review. The per-line breakdown is not stored in `ReceiptDraft`; adding an optional list of tax labels/amounts would change the persisted draft model and is left for a later change.
8. **Totals and payment blocks**: a `TOTAL $x` header at the top of the receipt is only a hint; the last `Total` row below the items wins (and `totalsDoNotAddUp` fires if it disagrees with subtotal + tax + tip). Everything after the first subtotal/total row — card terminal blocks (`Transaction Record`, `Visa`, `AUTHORIZED`, AID, `MID`, `TSI`, receipt number, dates) — is ignored for items and never produces price-row issues.
9. **Reconciliation**: never rewrite amounts. `reconciles` is true when net item line totals (including discounts) match the printed subtotal, or—if subtotal is missing—when they match `total − tax − tip`. Mismatches become `ReceiptIssue` entries for the review UI.

## Rules added by the receipt stress test

See [OCR_BENCHMARK.md](OCR_BENCHMARK.md#parser-changes-the-stress-test-drove) for the numbers behind each one.

- **Not prices:** a whole number above the first priced item when the receipt prints cents (street number, zip code, table number); a number glued to letters (`12A`, `B-2`); an item count (`Items: 5`, `Total de artículos: 5`); a `15%` tip-table row; a `Propina sugerida` row under the total.
- **Quantities:** `N x`, `N ×`, `N @` prefixes; a small number before a name is a quantity but flagged `needsReview`; a unit price next to a line total gives the quantity only when the total divides evenly by the unit price, otherwise the row is flagged; a `(N x $price)` row whose N does not multiply out is corrected by the line total and flagged.
- **Dropped or misread labels, recovered only when the arithmetic confirms:** a price row with no name becomes an unnamed item flagged `needsReview`; a price equal to the sum of the items is the subtotal; a lone price under the totals equal to subtotal + tax + tip is the total. Recovered subtotal and total are marked `needsAttention`.
- **Tips:** `Service Charge`, `Cargo por servicio`, `Charge` are tips. `Service Charge` is not read as `change`.

## Output: `ReceiptDraft`

Structured suggestions: `DraftItem` rows (quantity, line total in cents, flags such as `needsReview` / `priceOnNextRow`), optional subtotal/tax/tip/total, discount adjustments, `numberFormat`, `warnings`, `issues`, and `reconciles`.

### Warnings: what the scan was unsure about

The scanner never hides what it was unsure about. Besides `issues` (the parser's own list, unchanged), the draft carries `warnings: [ReceiptWarning]`, which is what the Review screen shows (see [SCREENS.md](SCREENS.md#4-review-receipt)). A `ReceiptWarning` is typed (`issue`, a `ReceiptIssue`) and says where it came from when the parser knew: the printed `rowLabel` (`Soda`, `IVU`), the `sourceRect` on the image, and the `itemID` when the unreadable price still produced a row. It has its own `id` and an `isDismissed` flag.

Only two kinds are warnings, because they are facts about the scan that an edit cannot make stale:

| Warning | When the parser raises it |
| ------- | ------------------------- |
| `unparsedPriceRow(text)` | A price it could not read (`3,5` on a receipt printed with `.`), a quantity row with no item above it, or a stray price with no name. The row is **not** turned into an item: the warning is the only trace of it, with the printed text. |
| `numberFormatGuessed(format)` | The separator vote was inconclusive and the format was guessed (`32.000`, `1500`). |

The other `ReceiptIssue`s (`itemsDoNotMatchSubtotal`, `totalsDoNotAddUp`, `noItemsFound`, `noTotalFound`) are not stored as warnings: they are recomputed from the receipt after every edit and the Review screen already shows them (the reconciliation banner, the empty state and the missing-total state).

Warnings only *surface* the parser's decisions: no item, amount or flag changes because of them, and every `unparsedPriceRow` in `issues` has a warning with the same text. `ReceiptDraftEditing.reconcile` recomputes `issues` from the receipt (that is how parser issues used to be lost when a draft became a `BillSession`) and leaves `warnings` alone. A warning is retired by the user (`ReceiptDraftEditing.dismissWarning`, or saving or deleting the row it names) and stays in the draft as `isDismissed`. Drafts saved before warnings existed decode with none (bill schema 2, see [BILL_SESSION.md](BILL_SESSION.md)).

Conversion to the bill-splitting `Receipt` model (participants, assignments, tip configuration) happens only after the user confirms on the review screen.

## Tests

- Unit tests in `ReceiptParserTests` and `AmountTokenTests` (synthetic geometry via `RecognizedTextTestBuilder`).
- Fixture tests load `*.recognized.json` + `*.expected.json` (includes macOS Vision recordings of synthetic receipts and hand-written adversarial geometry). `pr-party-store-wrapped-names` is the first real receipt scanned with Scanner Lab (store name, phone, card, terminal and transaction ids removed): wrapped item names, a `(3 x $11.50)` row, two tax lines, a header total and a card-terminal block. Its expected file also pins item names, unit prices, flagged-item count, issue count and warning count (none: its card-terminal block produces no warnings). `unparsed-price-row` is a hand-written receipt with one price the parser cannot read (`Soda 3,5` among `.` prices): it pins one warning, with the row label and the printed text. `ReceiptWarningTests` covers the rest (a guessed format, unreadable tax lines, a quantity row with no item, and that reconciliation issues are not warnings).

Regenerate Vision fixtures locally with the throwaway script in firstmate task data (`record_ocr.swift`); only JSON is committed.

## Accuracy benchmark

Scoring helpers live in `Sources/OCRBenchmarkKit/`. CI runs **metric unit tests only**; full Vision benchmarks use the `EsplitealoOCRBenchmark` executable (see [OCR_BENCHMARK.md](OCR_BENCHMARK.md)). Payment and footer lines (`change due`, card slip `No:`, `(Qty …)`) are classified out of the item list so totals are not double-counted.

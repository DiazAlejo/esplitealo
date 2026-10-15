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

## Output: `ReceiptDraft`

Structured suggestions: `DraftItem` rows (quantity, line total in cents, flags such as `needsReview` / `priceOnNextRow`), optional subtotal/tax/tip/total, discount adjustments, `numberFormat`, `issues`, and `reconciles`.

Conversion to the bill-splitting `Receipt` model (participants, assignments, tip configuration) happens only after the user confirms on the review screen.

## Tests

- Unit tests in `ReceiptParserTests` and `AmountTokenTests` (synthetic geometry via `RecognizedTextTestBuilder`).
- Fixture tests load `*.recognized.json` + `*.expected.json` (includes macOS Vision recordings of synthetic receipts and hand-written adversarial geometry). `pr-party-store-wrapped-names` is the first real receipt scanned with Scanner Lab (store name, phone, card, terminal and transaction ids removed): wrapped item names, a `(3 x $11.50)` row, two tax lines, a header total and a card-terminal block. Its expected file also pins item names, unit prices, flagged-item count and issue count.

Regenerate Vision fixtures locally with the throwaway script in firstmate task data (`record_ocr.swift`); only JSON is committed.

## Accuracy benchmark

Scoring helpers live in `Sources/OCRBenchmarkKit/`. CI runs **metric unit tests only**; full Vision benchmarks use the `EsplitealoOCRBenchmark` executable (see [OCR_BENCHMARK.md](OCR_BENCHMARK.md)). Payment and footer lines (`change due`, card slip `No:`, `(Qty …)`) are classified out of the item list so totals are not double-counted.

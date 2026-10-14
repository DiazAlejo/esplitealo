# Receipt parsing

Pure Foundation logic in `EsplitealoCore` that turns on-device OCR output into a conservative `ReceiptDraft` for the review screen. It does not call Vision, read images, or change confirmed totals.

## Input: `RecognizedText`

`ReceiptScanner` (later, in the app target) will wrap `VNRecognizeTextRequest` and produce a `RecognizedText` value:

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
7. **Reconciliation**: never rewrite amounts. `reconciles` is true when net item line totals (including discounts) match the printed subtotal, or—if subtotal is missing—when they match `total − tax − tip`. Mismatches become `ReceiptIssue` entries for the review UI.

## Output: `ReceiptDraft`

Structured suggestions: `DraftItem` rows (quantity, line total in cents, flags such as `needsReview` / `priceOnNextRow`), optional subtotal/tax/tip/total, discount adjustments, `numberFormat`, `issues`, and `reconciles`.

Conversion to the bill-splitting `Receipt` model (participants, assignments, tip configuration) happens only after the user confirms on the review screen.

## Tests

- Unit tests in `ReceiptParserTests` and `AmountTokenTests` (synthetic geometry via `RecognizedTextTestBuilder`).
- Fixture tests load `*.recognized.json` + `*.expected.json` (includes macOS Vision recordings of synthetic receipts and hand-written adversarial geometry).

Regenerate Vision fixtures locally with the throwaway script in firstmate task data (`record_ocr.swift`); only JSON is committed.

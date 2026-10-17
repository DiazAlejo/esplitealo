# OCR accuracy benchmark

Repeatable Vision + parser accuracy measurement for Esplitealo. **Not part of CI** (slow, network for CORD fetch, Vision variance).

## Quick start (macOS)

```sh
# Unit tests (metrics + harness) run in CI:
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test

# Receipt stress test: generated receipts with exact answers, real Vision scanner, bill-level exactness
# (runs on a macOS GitHub runner: see "Receipt stress test" below):
swift run -c release EsplitealoOCRBenchmark stress [--count 224] [--seed 2026] [--mode vision|ideal] \
  [--output report.json] [--markdown summary.md] [--failures-dir dir]

# Synthetic Puerto Rico–style receipts (Vision, local only):
swift run EsplitealoOCRBenchmark synthetic [--limit N] [--output path.json]

# CORD v2 real receipts (download once, then Vision):
python3 -m venv ~/Documents/firstmate/data/esplitealo-ocr-benchmark/.venv
~/Documents/firstmate/data/esplitealo-ocr-benchmark/.venv/bin/pip install datasets Pillow
~/Documents/firstmate/data/esplitealo-ocr-benchmark/.venv/bin/python Scripts/fetch-cord-benchmark.py --limit 100

swift run EsplitealoOCRBenchmark cord [--cache ~/Documents/firstmate/data/esplitealo-ocr-benchmark/cord-cache] [--limit 100]

# Compare two JSON reports:
swift run EsplitealoOCRBenchmark compare baseline.json candidate.json
```

Reports default to `~/Documents/firstmate/data/esplitealo-ocr-benchmark/reports/`. CORD JSON includes `scopeSplit` (PR/USD vs out-of-scope IDR).

## Receipt stress test

Generates fake Puerto Rico receipts whose every answer is known, scans them with the real Vision scanner and the parser, and scores the **parsed bill against the ground truth to the cent**. Code: `Sources/OCRBenchmarkKit/Stress*.swift` and `BillExactness.swift`; command: `EsplitealoOCRBenchmark stress`; workflow: [`receipt-stress.yml`](../.github/workflows/receipt-stress.yml) (manual or weekly, on `macos-26`, **not** part of the required check; it uploads `report.json`, `summary.md` and the failing cases as the `receipt-stress` artifact).

**Corpus** (`StressReceiptGenerator`, deterministic per seed): restaurant, colmado, fast food and bar receipts, Spanish and English, with items wrapped over several rows with modifier rows, `(N x $price)` rows, `2 x` / `2` prefixes and `3 @ 3.50` inline unit prices, priced add-ons, state 10.5% plus municipal 1% tax lines (or one combined line), mandatory service charge, discounts and negative lines (kept as manual adjustments), `Items / Price` column headings, a total printed large at the top, an item count line, tip suggestions, cash or card-terminal blocks (AID, MID, TSI, authorization, receipt number, dates), address, phone and table numbers in the header. Each image is a thermal-paper style monospace print, then degraded: rotation, skew, perspective, blur, noise, low contrast, shadow, crumple warp, or a combined handheld "photo". Every receipt carries exact ground truth: items, quantities, line totals, adjustments, subtotal, tax lines, tip and total.

**Headline metric:** *bill exactness*, the share of receipts whose parsed bill equals the truth in every item (line total and quantity), adjustment, subtotal, tax, tip and total. Also reported: amounts-exact (ignoring quantities), **silent wrong** (wrong and not flagged for review; the failure the user cannot see), the share of wrong bills that were flagged, the parser's exactness on *perfect* text (`ideal-text` mode), and the usual item metrics. Every failure is grouped by layout feature, venue, degradation and cause, and attributed to the parser (wrong even on perfect text) or to the image reading (right on perfect text).

`StressParserIdealTextTests` runs the parser on perfect OCR text for 112 generated receipts in the required `swift test` job (no image, about 5 s) and requires every bill to be exact, so a parser regression on any layout feature fails there. Vision-recorded failures are committed as `Tests/Fixtures/Receipts/stress-vision-*` fixtures (synthetic only) and replayed by `StressFixtureTests`.

### Results (seed 2026, n=224, macOS runner, Vision accurate)

| Stage | Bill exact | Amounts exact | Silent wrong | Wrong bills flagged | Parser on perfect text | Item recall / precision | Quantity accuracy |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Before** (parser as of `f8529cc`) | 16.5% | 23.2% | 1.3% | 98.4% | 21.9% | 79.8% / 71.1% | 74.0% |
| After the first parser fixes | 72.8% | 79.5% | 4.9% | 82.0% | 100% | 97.5% / 97.9% | 96.8% |
| After OCR-recovery fixes | 79.9% | 84.8% | 1.8% | 91.1% | 100% | 98.5% / 98.2% | 98.2% |
| **After** (final) | **81.2%** | 84.8% | **0.4%** (1 receipt) | 97.6% | 100% | 98.5% / 98.2% | 98.6% |

Reading it honestly: the first jump removed numbers that are not prices (street numbers, zip codes, table numbers, item counts) that used to become phantom items and to hide the real ones; it also raised the silent-wrong rate for a while: receipts that used to fail loudly for other reasons now failed only on a quantity that Vision had garbled, which nothing flagged. The later fixes bring the silent rate back down by recovering a quantity only when the receipt's own arithmetic confirms it, and by flagging the rest. The 42 receipts that are still wrong (18.8%) are all image reading, 41 of them flagged for review and 1 silent; the parser is exact on all 224 when given perfect text. They are: Vision dropping the left text of a row, reading `@` as `€` or `8`, `(` as `1`, or `Service` as `Sorytee`, on every kind of image (5 of the 80 undegraded ones, up to 6 of 16 for noise and low contrast). See the failure table in each run's `summary.md`.

### Parser changes the stress test drove

Each has a failing test committed before the fix (`ReceiptParserHeaderNoiseTests`, `ReceiptParserOcrRecoveryTests`, `StressFixtureTests`):

1. A whole number is not a price in the header: `Calle Luna 123`, `Ponce, PR 00717`, `Tab #41 Bar 4` above the first priced item, when the receipt prints cents. `12A` and `B-2` are never amounts.
2. `Items: 5`, `Total de artículos: 5` are counts, not items or totals (they also stopped the second tax line from counting).
3. `Propina sugerida 18%: $x` under the total is not the tip; a bare `15%` row is a tip-table row.
4. `Service Charge` is a tip (it was read as `change` given back); `Charge` alone too.
5. A price-only row between two keyword rows was merged into the row above it (`IVU Municipal 1% 0.45` + `50.31` gave a tax of 55.05); a name-only header line no longer sticks to a later price row.
6. `3 x Pastelillo de` / `carne 21.15` (name wrapped, price on the last row) keeps the quantity, flagged; a row that starts with a quantity is never a modifier of the row above.
7. A small number before a name (`4 Double Burger 25.00`) is a quantity, flagged for review because it could be part of the name (`7 Up`).
8. Vision reads `x` as `×`, `@` as `€`/`©`/`®` or a digit: `3 @ 7.85 23.55` now gives quantity 3 because 3 × 7.85 = 23.55; two prices on a row that do not divide stay one item, flagged; a misread `13 x $10.72)` is corrected to 3 by the line total (only when dropping the leading digit gives exactly line total ÷ unit), flagged; any other quantity row that does not multiply out is kept as printed and flagged.
9. A price whose name Vision dropped stays as an **unnamed, flagged item** so the bill still adds up (the review screen asks for the name); a price equal to the sum of the items is a subtotal with its label dropped; a lone price under the totals equal to subtotal + tax + tip is a total with its label dropped. All three are marked for attention.

Left alone on purpose: a leading number that Vision dropped together with the name (`3 Detergente  $34.29` read as `$34.29`) gives an unnamed item with quantity 1, flagged; `$10-65` (a dot read as a dash) stays an unparsed price.

## Datasets

### Synthetic (`SyntheticReceiptGenerator`)

Committed generator in `Sources/OCRBenchmarkKit/SyntheticReceiptGenerator.swift`. Styles: Puerto Rico restaurant (IVU 11.5%), colmado, restaurant with service charge, English diner, long colmado list. Variants: clean, skew, low contrast. Ground truth is exact; images are rendered at runtime (not committed).

### CORD v2 (real world)

- **Source:** [naver-clova-ix/cord-v2](https://huggingface.co/datasets/naver-clova-ix/cord-v2) (test split).
- **License:** [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) — Clova AI / NAVER (Park et al., 2019). Attribution required if you publish results; do not commit images or annotations to the repo.
- **Cache:** `~/Documents/firstmate/data/esplitealo-ocr-benchmark/cord-cache/` (`manifest.json`, `images/`, `ground_truth/`).
- **Price normalization:** ground-truth prices are read with the same per-receipt number-format inference as the parser (`CordDatasetLoader.minor`), so whole-unit prices (`12`) and thousands-separated ones (`12.500`) compare equal to parser output.
- **Product scope:** CORD is mostly Indonesian rupiah. `CordBenchmarkScope` marks IDR-style ground truth (large integer amounts, `17,000` / `60.000` shapes, IDR labels) as **out of product scope**. Headline PR/USD metrics use the synthetic set; CORD full-set numbers are for research comparison only.

## Metrics (JSON schema v1)

Per receipt and aggregate:

| Metric | Meaning |
| --- | --- |
| `itemRecall` / `itemPrecision` | Multiset match on line totals (same rule as OCR research) |
| `itemDescriptionAccuracy` | Matched items with name similarity ≥ 0.7 |
| `quantityAccuracy` | Matched items with correct quantity |
| `subtotalIdentificationRate` / `taxIdentificationRate` / `totalIdentificationRate` | Printed footer fields correct when present in ground truth |
| `reconciliationAgreementRate` | Parser `reconciles` flag matches expected outcome from ground-truth totals |
| `failureReasons` | e.g. `missedItems`, `extraItems`, `wrongItemPrices`, `reconciliationMismatch` |

## Measured results (identical metrics, Vision accurate, M1-class Mac)

### Recall drop diagnosis (86% → 62% on CORD)

An early CORD run reported **86%** item recall vs **62%** after ground-truth and scoring fixes. **This is not parser hardening regression:**

1. **Same parser, same metric code:** Re-running all 100 CORD images with the pre-hardening parser (`0cf6c34`) and the current parser yields **the same 62.2%** item recall.
2. **Ground-truth loader:** The 86% figure used incomplete `gt_parse` / menu extraction; many receipts scored as empty ground truth (recall is defined as 1.0 when there are zero GT items). After fixing `CordGroundTruthParser`, counts are honest.
3. **Removed tautology:** An early `itemPriceAccuracy` column matched only on equal line totals (always 1.0 when recall matched); it was removed from reports.

### Before / after table (same scorer, n=100 CORD test split)

| Stage | Item recall | Item precision | Total ID rate | Notes |
| --- | ---: | ---: | ---: | --- |
| Invalid early CORD run | 0.86 | 0.30 | 0.60 | Inflated recall; do not compare |
| **Final (GT + scorer fixed)** | **0.62** | **0.60** | **0.60** | Full set, all IDR/out-of-scope |
| Research reference | 0.77 | 0.84 | — | Prior harness on same public set |

### Product-scope headline (PR / USD)

| Dataset | n | Item recall | Total ID rate |
| --- | ---: | ---: | ---: |
| **Synthetic Puerto Rico** | 15 | **1.00** | **0.93** |
| CORD in product scope | 0 | — | — |
| CORD full (reference) | 100 | 0.62 | 0.60 |

No CORD test image in our cache met PR/USD ground-truth heuristics (all 100 are IDR-style). Use **synthetic n=15** for product headline numbers; use **CORD n=100** only as a stress / research benchmark.

### Parser hardening (no CORD recall change)

- Payment / card slip lines (`EDC`, `change due`, token `no:` with amount) no longer become items.
- Footer `(Qty …)` lines ignored.
- See `ReceiptParserTests`.

### What remains on CORD (full set)

- Dominant failures: `missedItems`, `extraItems`, footer total/tax mismatches, OCR garble on blurry photos.
- Locale: IDR digit shapes vs PR USD cents (out of product scope; uncertain rows stay flagged, not silently dropped).
- One skewed long synthetic receipt still misses footer totals (`long-colmado-skew`).

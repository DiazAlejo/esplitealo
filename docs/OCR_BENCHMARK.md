# OCR accuracy benchmark

Repeatable Vision + parser accuracy measurement for Esplitealo. **Not part of CI** (slow, network for CORD fetch, Vision variance).

## Quick start (macOS)

```sh
# Unit tests (metrics + harness) run in CI:
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test

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

## Datasets

### Synthetic (`SyntheticReceiptGenerator`)

Committed generator in `Sources/EsplitealoCore/OCRBenchmark/SyntheticReceiptGenerator.swift`. Styles: Puerto Rico restaurant (IVU 11.5%), colmado, restaurant with service charge, English diner, long colmado list. Variants: clean, skew, low contrast. Ground truth is exact; images are rendered at runtime (not committed).

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

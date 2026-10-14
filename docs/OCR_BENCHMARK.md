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

Reports default to `~/Documents/firstmate/data/esplitealo-ocr-benchmark/reports/`.

## Datasets

### Synthetic (`SyntheticReceiptGenerator`)

Committed generator in `Sources/EsplitealoCore/OCRBenchmark/SyntheticReceiptGenerator.swift`. Styles: Puerto Rico restaurant (IVU 11.5%), colmado, restaurant with service charge, English diner, long colmado list. Variants: clean, skew, low contrast. Ground truth is exact; images are rendered at runtime (not committed).

### CORD v2 (real world)

- **Source:** [naver-clova-ix/cord-v2](https://huggingface.co/datasets/naver-clova-ix/cord-v2) (test split).
- **License:** [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) — Clova AI / NAVER (Park et al., 2019). Attribution required if you publish results; do not commit images or annotations to the repo.
- **Cache:** `~/Documents/firstmate/data/esplitealo-ocr-benchmark/cord-cache/` (`manifest.json`, `images/`, `ground_truth/`).

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

## Measured results (this branch)

Environment: Apple Silicon Mac, macOS, Vision **accurate** mode, geometry row builder + `ReceiptParser`.

| Dataset | Receipts | Item recall | Item precision | Item price acc. | Total ID rate | Reconciliation agree. |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Synthetic PR (15 variants) | 15 | **1.00** | 0.99 | **1.00** | 0.93 | 0.93 |
| CORD v2 (after parser hardening) | 100 | **0.62** | **0.60** | 0.70 | 0.60 | 0.76 |

**Research reference** (same pipeline class, M1, 100 CORD images): ~**76.7%** item recall, ~84% precision (`data/esplitealo-ocr-research/report.md` in firstmate task data, §6.1). This branch’s CORD numbers are lower partly because ground-truth prices are compared as digit-stripped integers (IDR-style) while the product parser targets **USD cents / Puerto Rico**; footer/payment classification fixes improved precision (~0.30 → ~0.60) with stricter reconciliation scoring.

### Parser hardening (test-first)

- Payment / card slip lines (`EDC`, `No:`, `change due`) no longer become items.
- Footer `(Qty …)` lines ignored.
- See `ReceiptParserTests` and `docs/RECEIPT_PARSING.md`.

### What remains

- CORD locale (comma thousands, zero-decimal) vs PR USD scope — flagged, not silently guessed.
- Skewed long receipts can still pick up extra OCR rows (`long-colmado-skew` synthetic case).
- OCR garble on blurry CORD photos (dominant missed-item cause).

#!/usr/bin/env python3
"""Download CORD v2 test samples for the Esplitealo OCR benchmark.

Source: https://huggingface.co/datasets/naver-clova-ix/cord-v2 (CC-BY 4.0).
Images and annotations are cached outside the git repo (see docs/OCR_BENCHMARK.md).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

DEFAULT_CACHE = Path.home() / "Documents/firstmate/data/esplitealo-ocr-benchmark/cord-cache"


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch CORD v2 into a local benchmark cache")
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--limit", type=int, default=100, help="Number of test images (max 100 for test split sample)")
    args = parser.parse_args()

    try:
        from datasets import load_dataset  # type: ignore
    except ImportError:
        print(
            "Install the Hugging Face datasets package: pip install datasets",
            file=sys.stderr,
        )
        return 1

    args.cache.mkdir(parents=True, exist_ok=True)
    images_dir = args.cache / "images"
    gt_dir = args.cache / "ground_truth"
    images_dir.mkdir(exist_ok=True)
    gt_dir.mkdir(exist_ok=True)

    ds = load_dataset("naver-clova-ix/cord-v2", split="test")
    entries = []
    for idx, row in enumerate(ds):
        if idx >= args.limit:
            break
        receipt_id = f"cord_{idx:03d}"
        image_path = images_dir / f"{receipt_id}.png"
        gt_path = gt_dir / f"{receipt_id}.gt.json"
        if not image_path.exists():
            row["image"].save(image_path)
        gt = row.get("ground_truth") or row.get("gt_parse")
        if isinstance(gt, str):
            gt = json.loads(gt)
        if isinstance(gt, dict) and "gt_parse" in gt:
            gt = gt["gt_parse"]
        gt_path.write_text(json.dumps(gt, ensure_ascii=False), encoding="utf-8")
        entries.append(
            {
                "id": receipt_id,
                "imageFile": f"images/{receipt_id}.png",
                "groundTruthFile": f"ground_truth/{receipt_id}.gt.json",
            }
        )

    manifest = {
        "source": "naver-clova-ix/cord-v2",
        "license": "CC-BY-4.0",
        "split": "test",
        "entries": entries,
    }
    (args.cache / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Cached {len(entries)} receipts under {args.cache}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

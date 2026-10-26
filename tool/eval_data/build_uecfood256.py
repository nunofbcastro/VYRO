#!/usr/bin/env python3
"""STUB, NOT RUN. Converter for UEC FOOD 256 into VYRO eval labels.

Eval-only. UEC FOOD 256 is research / non-commercial. It must never ship with the app.
Do not add it to any asset bundle or training pipeline.

Setup (only if the user supplies a Kaggle API token at ~/.kaggle/kaggle.json):
    py -m pip install --user kaggle
    kaggle datasets download -d rkuo2000/uecfood256 -p <empty dir outside the repo>
    # unzip into an empty directory outside the repo, then point --src at it.
Treat the archive contents as untrusted data: parse text files only, never execute them.

Expected layout (verify on the first real download; this stub has not seen the data):
    <src>/<class_id>/           one folder per class, numbered 1..256
    <src>/<class_id>/bb_info.txt  tab-separated: header line "img x1 y1 x2 y2", then one
                                  row per image: <image file id> x1 y1 x2 y2
    <src>/category.txt          tab-separated: <class_id> <name> <super-category>

What it would do:
  1. Read category.txt into {class_id: english_name}.
  2. Read tool/eval_data/uecfood256_map.json (English class name -> VYRO key, or null).
     Classes with no key are skipped (optional, no credit, no penalty).
  3. For each class folder with a mapped key, read bb_info.txt. Each image's bounding
     box marks where the dish is. The stub only records it. A crop is an open question
     (see TODO). Whole-image labels would count food that is not the target.
  4. Write eval/datasets/uecfood256/labels.json in the eval/labels.json format, with
     "file" pointing at photos under eval/datasets/uecfood256/photos/.

Open TODOs (not done):
  - Confirm the bb_info.txt header and the category.txt column order on a real download.
  - Decide crop vs whole image. UEC images often hold several dishes.
  - Copy images as JPEG q90, as build_nutrition5k.py does, and check the licence per copy.
  - Multi-class images: the same photo can sit in several classes; dedupe by file hash.

Usage (not run):
    py -I tool/eval_data/build_uecfood256.py --src <unzipped dir>
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_FILE = ROOT / "tool" / "eval_data" / "uecfood256_map.json"
OUT_DIR = ROOT / "eval" / "datasets" / "uecfood256"


def read_categories(src: Path) -> dict[str, str]:
    """class_id -> English name, from category.txt (tab-separated, first line is a header)."""
    out: dict[str, str] = {}
    with open(src / "category.txt", encoding="utf-8") as fh:
        for i, line in enumerate(fh):
            if i == 0:
                continue  # TODO: confirm header on real data
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                out[parts[0].strip()] = parts[1].strip()
    return out


def read_bboxes(class_dir: Path) -> dict[str, tuple[int, int, int, int]]:
    """image id -> (x1, y1, x2, y2) from bb_info.txt. Header line is skipped."""
    boxes: dict[str, tuple[int, int, int, int]] = {}
    with open(class_dir / "bb_info.txt", encoding="utf-8") as fh:
        next(fh, None)  # header: img x1 y1 x2 y2
        for line in fh:
            parts = line.split()
            if len(parts) != 5:
                continue
            img, *coords = parts
            boxes[img] = tuple(int(c) for c in coords)  # type: ignore[assignment]
    return boxes


def main() -> int:
    ap = argparse.ArgumentParser(description="STUB: UEC FOOD 256 -> VYRO eval labels (not run)")
    ap.add_argument("--src", type=Path, required=True, help="unzipped dataset dir (outside the repo)")
    args = ap.parse_args()

    categories = read_categories(args.src)
    mapping = json.loads(MAP_FILE.read_text(encoding="utf-8")).get("classes", {})
    mapped = {cid: mapping[name] for cid, name in categories.items() if mapping.get(name)}
    print(f"classes={len(categories)} mapped={len(mapped)}")  # TODO: write labels.json
    _ = OUT_DIR
    _ = read_bboxes  # TODO: wire into label writing once crop policy is decided
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

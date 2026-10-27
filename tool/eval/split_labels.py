"""Rebuild the Nutrition5k train (nutrition5k_50) and holdout labels from the full labels file.

The split is fixed: a photo never moves between train and holdout. The split is read from
eval/datasets/nutrition5k/split.json. On the first run that file is written from the existing
eval/datasets/nutrition5k_50/labels.json and eval/datasets/nutrition5k_holdout/labels.json.

Usage (run by tool/eval/refresh_labels.ps1 after build_nutrition5k.py --no-download):
    py -I tool/eval/split_labels.py
    py -I tool/eval/split_labels.py --root C:\\path\\to\\VYRO
"""

from __future__ import annotations

import argparse
import json
import os
import sys

FULL = os.path.join("eval", "datasets", "nutrition5k", "labels.json")
SPLIT = os.path.join("eval", "datasets", "nutrition5k", "split.json")
TRAIN_DIR = os.path.join("eval", "datasets", "nutrition5k_50")
HOLDOUT_DIR = os.path.join("eval", "datasets", "nutrition5k_holdout")


def read_json(path: str):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: str, data) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def files_of(labels: list[dict]) -> list[str]:
    return [entry["file"] for entry in labels]


def derive_split(root: str) -> dict:
    """Membership from the subset files that exist today (the split of record)."""
    train = os.path.join(root, TRAIN_DIR, "labels.json")
    holdout = os.path.join(root, HOLDOUT_DIR, "labels.json")
    for path in (train, holdout):
        if not os.path.exists(path):
            raise SystemExit(f"no split.json and no subset file to derive it from: {path}")
    return {
        "note": "Nutrition5k split of record. Photos never move between train and holdout.",
        "train": files_of(read_json(train)),
        "holdout": files_of(read_json(holdout)),
    }


def build_subset(full: list[dict], wanted: list[str], label: str) -> list[dict]:
    by_file = {entry["file"]: entry for entry in full}
    missing = [f for f in wanted if f not in by_file]
    if missing:
        raise SystemExit(f"{label}: files in the split but not in {FULL}: {missing[:5]}")
    return [by_file[f] for f in wanted]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--root", default=os.path.normpath(os.path.join(here, "..", "..")))
    args = ap.parse_args(argv)
    root = os.path.abspath(args.root)

    split_path = os.path.join(root, SPLIT)
    if os.path.exists(split_path):
        split = read_json(split_path)
    else:
        split = derive_split(root)
        write_json(split_path, split)
        print(f"wrote {split_path} (derived from the existing subset files)")

    overlap = set(split["train"]) & set(split["holdout"])
    if overlap:
        raise SystemExit(f"split overlap, refusing to write: {sorted(overlap)[:5]}")

    full = read_json(os.path.join(root, FULL))
    for name, folder in (("train", TRAIN_DIR), ("holdout", HOLDOUT_DIR)):
        subset = build_subset(full, split[name], name)
        out = os.path.join(root, folder, "labels.json")
        write_json(out, subset)
        photos = os.path.join(root, folder, "photos")
        missing_photos = [e["file"] for e in subset if not os.path.exists(os.path.join(photos, e["file"]))]
        print(f"{name}: {len(subset)} labels -> {out}")
        if missing_photos:
            print(f"  warning: {len(missing_photos)} photo(s) missing in {photos}: {missing_photos[:5]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

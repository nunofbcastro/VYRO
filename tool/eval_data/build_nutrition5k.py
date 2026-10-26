#!/usr/bin/env python3
"""Build the Nutrition5k food-photo benchmark subset for VYRO's offline eval.

Dev-time only. The VYRO app never runs this and makes no such requests.

Source:  Nutrition5k (Thames et al., "Nutrition5k: Towards Automatic Nutritional
         Understanding of Generic Food", CVPR 2021), Google Research, CC BY 4.0.
         https://github.com/google-research-datasets/Nutrition5k
Bucket:  https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset/
         Only metadata CSVs and the selected imagery/realsense_overhead/<dish>/rgb.png
         files are fetched. The 181 GB bucket is never mirrored.

Steps (default run):
  1. Download metadata (dish CSVs, ingredients CSV, dataset README) into
     eval/datasets/nutrition5k/metadata/ (cached).
  2. Parse dishes, drop ingredients with no name or non-positive mass, and bin
     dishes by filtered ingredient count: 1-2, 3-4, 5+.
  3. Sample a stratified subset with a fixed seed. A dish is kept only if its
     overhead rgb.png exists (HEAD request). The selection is written to
     eval/datasets/nutrition5k/manifest.json and reused on later runs
     (use --reselect to redo it).
  4. Download each rgb.png and save it as a JPEG (quality 90) to
     eval/datasets/nutrition5k/photos/<dish_id>.jpg. Existing files are skipped.
  5. Build eval/datasets/nutrition5k/labels.json (same shape as eval/labels.json)
     using tool/eval_data/nutrition5k_map.json, and write mapping coverage stats to
     eval/datasets/nutrition5k/mapping_stats.json.

Other modes:
  --suggest   Add an auto-suggested map entry (reviewed: false) for every subset
              ingredient name not yet in the map. Existing entries are never
              overwritten. Review the file by hand, then set reviewed: true.
  --no-download  Rebuild labels and stats from cached photos and metadata only.

Requires Pillow in the interpreter that runs it (py -I ignores user site-packages). See eval/datasets/README.md.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import random
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DATASETS = ROOT / "eval" / "datasets" / "nutrition5k"
META_DIR = DATASETS / "metadata"
PHOTO_DIR = DATASETS / "photos"
MANIFEST = DATASETS / "manifest.json"
LABELS = DATASETS / "labels.json"
STATS = DATASETS / "mapping_stats.json"
MAP_FILE = ROOT / "tool" / "eval_data" / "nutrition5k_map.json"
FOODS_JSON = ROOT / "assets" / "nutrition" / "foods.json"

BASE = "https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset/"
README_URL = "https://raw.githubusercontent.com/google-research-datasets/Nutrition5k/main/README.md"
DISH_CSVS = ["metadata/dish_metadata_cafe1.csv", "metadata/dish_metadata_cafe2.csv"]
INGR_CSV = "metadata/ingredients_metadata.csv"
OVERHEAD = "imagery/realsense_overhead/{dish}/rgb.png"

SEED = 20260415
TARGET = 150
JPEG_QUALITY = 90
MIN_OPTIONAL_GRAMS = 5.0
USER_AGENT = "VYRO-eval-builder/1.0 (dev-time benchmark; contact: repo owner)"
BINS = ["1-2", "3-4", "5+"]

# Ingredients that are usually not visible or not scored in a photo. Used on top of
# the explicit "optional" flags in the map. Matched against the lower-case name.
OPTIONAL_PATTERN = re.compile(
    r"\b(oil|vinegar|salt|pepper|spice|seasoning|dressing|sauce|mayonnaise|mayo|"
    r"ketchup|mustard|syrup|sugar|butter|cumin|paprika|oregano|basil|thyme|"
    r"rosemary|cinnamon|nutmeg|ginger|garlic powder|onion powder|herb|bouillon|"
    r"broth|stock|gravy|marinade|honey)\b"
)


def log(msg: str) -> None:
    print(msg, flush=True)


def http_get(url: str, retries: int = 3, timeout: int = 90) -> bytes:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise
            last = e
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            last = e
        time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"GET failed after {retries} tries: {url}: {last}")


def url_exists(url: str) -> bool:
    """HEAD check. 404 (or 403) means the object is absent. Transient errors are retried."""
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status == 200
        except urllib.error.HTTPError as e:
            if e.code in (403, 404):
                return False
            time.sleep(1.0 * (attempt + 1))
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            time.sleep(1.0 * (attempt + 1))
    return False


def fetch_metadata() -> dict[str, str]:
    META_DIR.mkdir(parents=True, exist_ok=True)
    out: dict[str, str] = {}
    for rel in DISH_CSVS + [INGR_CSV]:
        dest = META_DIR / Path(rel).name
        if not dest.exists():
            log(f"download {rel}")
            dest.write_bytes(http_get(BASE + rel))
        out[rel] = hashlib.sha256(dest.read_bytes()).hexdigest()
    readme = META_DIR / "Nutrition5k_README.md"
    if not readme.exists():
        log("download dataset README")
        readme.write_bytes(http_get(README_URL))
    return out


def parse_dishes() -> tuple[list[dict], Counter]:
    """Return dishes with filtered ingredients, plus drop counters."""
    drops: Counter = Counter()
    seen: set[str] = set()
    dishes: list[dict] = []
    for rel in DISH_CSVS:
        cafe = Path(rel).stem.rsplit("_", 1)[-1]  # cafe1 / cafe2
        with open(META_DIR / Path(rel).name, encoding="utf-8", newline="") as fh:
            for row in csv.reader(fh):
                if not row or not row[0].startswith("dish_"):
                    continue
                dish_id = row[0].strip()
                if dish_id in seen:
                    drops["duplicate_dish_id"] += 1
                    continue
                seen.add(dish_id)
                # The CSVs have no num_ingrs column (the README mentions one; the data does not).
                # Layout: dish_id, total_calories, total_mass, total_fat, total_carb, total_protein,
                # then 7 fields per ingredient. Ingredient count = (width - 6) / 7.
                if (len(row) - 6) % 7:
                    drops["bad_row_width"] += 1
                    continue
                n = (len(row) - 6) // 7
                try:
                    total_mass = float(row[2])
                    total_cal = float(row[1])
                except (ValueError, IndexError):
                    drops["bad_header"] += 1
                    continue
                if total_mass <= 0:
                    drops["zero_total_mass"] += 1
                    continue
                ingredients = []
                for i in range(n):
                    base = 6 + 7 * i
                    ingr_id, name, grams, cal, fat, carb, prot = row[base : base + 7]
                    name = name.strip().lower()
                    try:
                        grams_f = float(grams)
                    except ValueError:
                        drops["bad_ingredient_grams"] += 1
                        continue
                    if not name:
                        drops["ingredient_without_name"] += 1
                        continue
                    if grams_f <= 0:
                        drops["ingredient_zero_grams"] += 1
                        continue
                    ingredients.append(
                        {
                            "ingr_id": ingr_id.strip(),
                            "name": name,
                            "grams": grams_f,
                            "calories": float(cal or 0),
                        }
                    )
                if not ingredients:
                    drops["no_ingredients_after_filter"] += 1
                    continue
                dishes.append(
                    {
                        "dish_id": dish_id,
                        "cafe": cafe,
                        "total_mass": total_mass,
                        "total_calories": total_cal,
                        "ingredients": ingredients,
                        "n_ingr": len(ingredients),
                    }
                )
    dishes.sort(key=lambda d: d["dish_id"])
    return dishes, drops


def bin_of(n: int) -> str:
    if n <= 2:
        return "1-2"
    if n <= 4:
        return "3-4"
    return "5+"


def select_dishes(dishes: list[dict], target: int, seed: int) -> tuple[list[dict], dict]:
    by_bin: dict[str, list[dict]] = {b: [] for b in BINS}
    for d in dishes:
        by_bin[bin_of(d["n_ingr"])].append(d)
    base = target // len(BINS)
    quotas = {"1-2": base, "3-4": base, "5+": target - 2 * base}
    rng = random.Random(seed)
    chosen: list[dict] = []
    report: dict[str, dict] = {}
    for b in BINS:
        pool = list(by_bin[b])  # already sorted by dish_id
        rng.shuffle(pool)
        got: list[dict] = []
        checked = 0
        i = 0
        while len(got) < quotas[b] and i < len(pool):
            chunk = pool[i : i + 32]
            i += len(chunk)
            urls = [BASE + OVERHEAD.format(dish=d["dish_id"]) for d in chunk]
            with ThreadPoolExecutor(max_workers=8) as ex:
                flags = list(ex.map(url_exists, urls))
            for d, ok in zip(chunk, flags):
                checked += 1
                if ok and len(got) < quotas[b]:
                    got.append(d)
        log(
            f"bin {b}: eligible={len(pool)} checked={checked} "
            f"with_overhead_selected={len(got)}/{quotas[b]}"
        )
        report[b] = {
            "eligible": len(pool),
            "head_checked": checked,
            "selected": len(got),
            "quota": quotas[b],
        }
        chosen.extend(got)
    chosen.sort(key=lambda d: d["dish_id"])
    return chosen, report


def jpeg_from_png(png: bytes) -> bytes:
    with Image.open(io.BytesIO(png)) as im:
        rgb = im.convert("RGB")
        buf = io.BytesIO()
        rgb.save(buf, "JPEG", quality=JPEG_QUALITY)
        return buf.getvalue()


def download_photo(dish: dict) -> dict:
    dish_id = dish["dish_id"]
    dest = PHOTO_DIR / f"{dish_id}.jpg"
    if dest.exists():
        return {"dish_id": dish_id, "png_sha256": dish.get("png_sha256"), "jpg_bytes": dest.stat().st_size, "cached": True}
    png = http_get(BASE + OVERHEAD.format(dish=dish_id))
    jpg = jpeg_from_png(png)
    dest.write_bytes(jpg)
    return {
        "dish_id": dish_id,
        "png_sha256": hashlib.sha256(png).hexdigest(),
        "png_bytes": len(png),
        "jpg_bytes": len(jpg),
        "cached": False,
    }


# ---------------------------------------------------------------- mapping

def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def load_foods() -> dict[str, dict]:
    data = json.loads(FOODS_JSON.read_text(encoding="utf-8"))
    return {f["key"]: f for f in data["foods"]}


def load_map() -> dict[str, dict]:
    if not MAP_FILE.exists():
        return {}
    return json.loads(MAP_FILE.read_text(encoding="utf-8")).get("ingredients", {})


def save_map(entries: dict[str, dict]) -> None:
    doc = {
        "_about": (
            "Nutrition5k ingredient name (lower case, as in dish_metadata) -> VYRO foods.json key. "
            "key null = no DB equivalent (scored as neither hit nor miss). any_of = alternative keys "
            "that also count as a hit. optional = not scored when absent from the photo. reviewed = "
            "a human checked this entry. See eval/datasets/README.md for the rules."
        ),
        "ingredients": dict(sorted(entries.items())),
    }
    MAP_FILE.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def suggest_key(name: str, db: dict[str, dict]) -> str | None:
    """Best-effort: DB key whose English name or alias contains every token of the ingredient."""
    tokens = set(normalize(name).split())
    if not tokens:
        return None
    best: tuple[int, int, str] | None = None
    for key, food in db.items():
        candidates = [food.get("nameEn", "")] + list(food.get("aliases", []))
        for cand in candidates:
            ctoks = set(normalize(cand).split())
            if tokens and tokens <= ctoks:
                # Prefer the candidate with the fewest extra words.
                score = (len(ctoks - tokens), len(cand), key)
                if best is None or score < best:
                    best = score
    return best[2] if best else None


def run_suggest(dishes: list[dict]) -> None:
    db = load_foods()
    entries = load_map()
    added = 0
    for d in dishes:
        for ing in d["ingredients"]:
            if ing["name"] not in entries:
                key = suggest_key(ing["name"], db)
                entries[ing["name"]] = {"key": key, "reviewed": False}
                added += 1
    save_map(entries)
    log(f"suggest: added {added} entries to {MAP_FILE}")


def is_optional_name(name: str) -> bool:
    return bool(OPTIONAL_PATTERN.search(name))


def build_labels(dishes: list[dict], db: dict[str, dict]) -> tuple[list[dict], dict]:
    entries = load_map()
    errors: list[str] = []
    for name, m in entries.items():
        for k in [m.get("key")] + list(m.get("any_of", []) or []):
            if k is not None and k not in db:
                errors.append(f"{name}: unknown key {k}")
    if errors:
        raise SystemExit("map errors:\n  " + "\n  ".join(errors))

    labels: list[dict] = []
    total_items = mapped_items = 0
    total_grams = mapped_grams = 0.0
    name_freq: Counter = Counter()
    name_grams: defaultdict = defaultdict(float)
    unmapped_missing: Counter = Counter()
    unmapped_null: Counter = Counter()
    unmapped_null_grams: defaultdict = defaultdict(float)
    key_hits: Counter = Counter()

    for d in dishes:
        merged: dict[str, dict] = {}
        for ing in d["ingredients"]:
            name = ing["name"]
            name_freq[name] += 1
            name_grams[name] += ing["grams"]
            total_items += 1
            total_grams += ing["grams"]
            m = entries.get(name)
            if m is None:
                unmapped_missing[name] += 1
                m = {}
            key = m.get("key")
            any_of = list(m.get("any_of") or [])
            optional = bool(m.get("optional", False))
            optional = optional or ing["grams"] < MIN_OPTIONAL_GRAMS or is_optional_name(name)
            if key is None:
                unmapped_null[name] += 1
                unmapped_null_grams[name] += ing["grams"]
                optional = True
                label_key = f"name:{name}"
                entry = {"name": name, "text": name, "optional": True}
            else:
                mapped_items += 1
                mapped_grams += ing["grams"]
                key_hits[key] += 1
                label_key = key
                entry = {"name": db[key]["namePt"], "key": key}
                if any_of:
                    entry["any_of"] = any_of
                if optional:
                    entry["optional"] = True
            if label_key in merged:
                prev = merged[label_key]
                prev["grams"] = round(prev["grams"] + ing["grams"], 1)
                prev["ingredient"] = prev["ingredient"] + " / " + name
                if prev.get("optional") and not optional:
                    prev.pop("optional", None)
            else:
                entry["grams"] = round(ing["grams"], 1)
                entry["ingredient"] = name
                entry["ingr_id"] = ing["ingr_id"]
                merged[label_key] = entry
        foods = list(merged.values())
        labels.append(
            {
                "file": f"{d['dish_id']}.jpg",
                "notes": (
                    f"Nutrition5k {d['dish_id']} ({d['cafe']}), overhead RGB. "
                    f"{d['n_ingr']} ingredients, {d['total_mass']:.1f} g total. "
                    "Labels auto-mapped from ingredient names; CC BY 4.0."
                ),
                "total_mass": round(d["total_mass"], 1),
                "foods": foods,
            }
        )

    unmapped_total = sorted(
        unmapped_null.items(), key=lambda kv: (-unmapped_null_grams[kv[0]], kv[0])
    )
    stats = {
        "dishes": len(dishes),
        "items": {
            "total": total_items,
            "mapped": mapped_items,
            "mapped_share": round(mapped_items / total_items, 4) if total_items else 0,
        },
        "grams": {
            "total": round(total_grams, 1),
            "mapped": round(mapped_grams, 1),
            "mapped_share": round(mapped_grams / total_grams, 4) if total_grams else 0,
        },
        "names_not_in_map": dict(unmapped_missing.most_common()),
        "names_mapped_to_null": [
            {"name": n, "items": unmapped_null[n], "grams": round(g, 1)}
            for n, g in unmapped_null_grams.items()
        ],
        "top_frequent_names": [
            {
                "name": n,
                "items": c,
                "grams": round(name_grams[n], 1),
                "key": (entries.get(n) or {}).get("key"),
                "reviewed": bool((entries.get(n) or {}).get("reviewed", False)),
            }
            for n, c in name_freq.most_common(80)
        ],
        "keys_used": dict(key_hits.most_common()),
    }
    stats["names_mapped_to_null"].sort(key=lambda r: -r["grams"])
    return labels, stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--target", type=int, default=TARGET)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--reselect", action="store_true", help="ignore manifest and re-sample")
    ap.add_argument("--no-download", action="store_true", help="only rebuild labels and stats from cache")
    ap.add_argument("--suggest", action="store_true", help="add auto-suggested map entries for missing names")
    args = ap.parse_args()

    PHOTO_DIR.mkdir(parents=True, exist_ok=True)
    meta_hashes = fetch_metadata()
    dishes, drops = parse_dishes()
    log(f"parsed dishes={len(dishes)} drops={dict(drops)}")
    bin_counts = Counter(bin_of(d["n_ingr"]) for d in dishes)
    log(f"eligible by bin: {dict(bin_counts)}")

    old_rows: dict[str, dict] = {}
    if MANIFEST.exists():
        old_rows = {r["dish_id"]: r for r in json.loads(MANIFEST.read_text(encoding="utf-8")).get("dishes", [])}

    if MANIFEST.exists() and not args.reselect:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        chosen_ids = [d["dish_id"] for d in manifest["dishes"]]
        by_id = {d["dish_id"]: d for d in dishes}
        chosen = [by_id[i] for i in chosen_ids if i in by_id]
        selection_report = manifest.get("selection", {})
        log(f"reusing selection from manifest: {len(chosen)} dishes")
    else:
        chosen, selection_report = select_dishes(dishes, args.target, args.seed)
        manifest = {"dishes": [], "selection": selection_report}

    if args.suggest:
        run_suggest(chosen)
        return 0

    photo_info: dict[str, dict] = {}
    if not args.no_download:
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = {d["dish_id"]: ex.submit(download_photo, d) for d in chosen}
            for dish_id, fut in futs.items():
                photo_info[dish_id] = fut.result()
        log(f"photos ready: {len(chosen)}")

    manifest_rows = []
    for d in chosen:
        info = photo_info.get(d["dish_id"], {})
        prev = old_rows.get(d["dish_id"], {})  # keep provenance from earlier downloads
        jpg = PHOTO_DIR / f"{d['dish_id']}.jpg"
        manifest_rows.append(
            {
                "dish_id": d["dish_id"],
                "cafe": d["cafe"],
                "bin": bin_of(d["n_ingr"]),
                "n_ingredients": d["n_ingr"],
                "total_mass": round(d["total_mass"], 1),
                "total_calories": round(d["total_calories"], 1),
                "png_sha256": info.get("png_sha256") or prev.get("png_sha256"),
                "png_bytes": info.get("png_bytes") or prev.get("png_bytes"),
                "jpg_bytes": jpg.stat().st_size if jpg.exists() else None,
            }
        )
    manifest = {
        "source": BASE + "imagery/realsense_overhead/<dish_id>/rgb.png",
        "license": "CC BY 4.0 (Nutrition5k, Thames et al. 2021, CVPR)",
        "seed": args.seed,
        "target": args.target,
        "jpeg_quality": JPEG_QUALITY,
        "metadata_sha256": meta_hashes,
        "parsed_dishes": len(dishes),
        "drops": dict(drops),
        "selection": selection_report,
        "dishes": manifest_rows,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    db = load_foods()
    labels, stats = build_labels(chosen, db)
    LABELS.write_text(json.dumps(labels, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    STATS.write_text(json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    jpg_total = sum(r["jpg_bytes"] or 0 for r in manifest_rows)
    log(f"dishes={len(chosen)} jpg_total_bytes={jpg_total} ({jpg_total / 1e6:.1f} MB)")
    log(
        f"items mapped {stats['items']['mapped']}/{stats['items']['total']} "
        f"({stats['items']['mapped_share']:.1%}); grams mapped "
        f"{stats['grams']['mapped']}/{stats['grams']['total']} ({stats['grams']['mapped_share']:.1%})"
    )
    log(f"wrote {LABELS}")
    log(f"wrote {STATS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

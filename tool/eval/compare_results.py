"""Summarise food-vision eval results (stdlib only).

Reads the newest result JSON per (dataset, strategy) under eval/results/ and
eval/datasets/*/results/, prints a summary and writes eval/results_summary.md.

Usage (from the repo root):
    py -I tool/eval/compare_results.py
    py -I tool/eval/compare_results.py --root C:\\path\\to\\VYRO --out eval/results_summary.md

Unit tests: py -I -m unittest tool/eval/test_compare_results.py
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Iterable

LEGACY = "legacy_app"
PIPELINE = "pipeline"
TRAIN = "nutrition5k_50"
HOLDOUT = "nutrition5k_holdout"
OWN = "eval"


@dataclass
class RunRecord:
    dataset: str
    strategy: str
    timestamp: str
    path: str
    summary: dict
    images: list = field(default_factory=list)


def dataset_name(labels_path: str | None, fallback: str) -> str:
    """'eval/datasets/nutrition5k_50/labels.json' -> 'nutrition5k_50', 'eval/labels.json' -> 'eval'."""
    if not labels_path:
        return fallback
    normalised = labels_path.replace("\\", "/").rstrip("/")
    parent = os.path.dirname(normalised)
    return os.path.basename(parent) or fallback


def parse_result(doc: dict, path: str = "") -> RunRecord:
    """Turn one result JSON document into a RunRecord. Raises KeyError on a malformed document."""
    meta = doc["meta"]
    summary = doc["summary"]
    fallback = os.path.basename(os.path.dirname(os.path.dirname(path))) if path else "unknown"
    return RunRecord(
        dataset=dataset_name(meta.get("labels"), fallback),
        strategy=str(meta["strategy"]),
        timestamp=str(meta.get("timestamp", "")),
        path=path,
        summary=summary,
        images=list(doc.get("images", [])),
    )


def newest_per_key(records: Iterable[RunRecord]) -> dict[tuple[str, str], RunRecord]:
    """Keep the newest run (largest timestamp, then path) for each (dataset, strategy)."""
    best: dict[tuple[str, str], RunRecord] = {}
    for r in records:
        key = (r.dataset, r.strategy)
        current = best.get(key)
        if current is None or (r.timestamp, r.path) > (current.timestamp, current.path):
            best[key] = r
    return best


def load_records(root: str) -> tuple[list[RunRecord], list[str]]:
    """Load every result JSON under the known result folders. Returns (records, problems)."""
    patterns = [
        os.path.join(root, "eval", "results", "*.json"),
        os.path.join(root, "eval", "datasets", "*", "results", "*.json"),
    ]
    records: list[RunRecord] = []
    problems: list[str] = []
    for pattern in patterns:
        for path in sorted(glob.glob(pattern)):
            try:
                with open(path, encoding="utf-8") as fh:
                    records.append(parse_result(json.load(fh), path))
            except (OSError, ValueError, KeyError, TypeError) as err:
                problems.append(f"{path}: {err}")
    return records, problems


def _num(value) -> float | None:
    return float(value) if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def mean_latency_ms(record: RunRecord) -> float | None:
    stored = _num(record.summary.get("mean_latency_ms"))
    if stored is not None:
        return stored
    values = [v for v in (_num(img.get("latency_ms")) for img in record.images) if v is not None]
    return sum(values) / len(values) if values else None


def fmt(value, digits: int = 3) -> str:
    if value is None:
        return "-"
    return f"{value:.{digits}f}"


def fp_per_photo(record: RunRecord) -> float | None:
    stored = _num(record.summary.get("mean_false_positives_per_photo"))
    if stored is not None:
        return stored
    photos = record.summary.get("photos") or 0
    return record.summary.get("fp", 0) / photos if photos else None


def table_rows(latest: dict[tuple[str, str], RunRecord]) -> list[list[str]]:
    header = ["dataset", "strategy", "photos", "precision", "recall", "F1", "exact meals", "FP/photo", "mean latency (ms)", "errors"]
    rows = [header]
    for (dataset, strategy), r in sorted(latest.items()):
        s = r.summary
        photos = s.get("photos", 0)
        exact = s.get("exact_meals", 0)
        rows.append([
            dataset,
            strategy,
            str(photos),
            fmt(_num(s.get("precision"))),
            fmt(_num(s.get("recall"))),
            fmt(_num(s.get("f1"))),
            f"{exact}/{photos}",
            fmt(fp_per_photo(r), 2),
            fmt(mean_latency_ms(r), 0),
            str(s.get("errors", 0)),
        ])
    return rows


def delta_rows(latest: dict[tuple[str, str], RunRecord], dataset: str) -> list[list[str]] | None:
    before = latest.get((dataset, LEGACY))
    after = latest.get((dataset, PIPELINE))
    if before is None or after is None:
        return None
    rows = [["metric", LEGACY, PIPELINE, "delta"]]

    def add(name: str, a: float | None, b: float | None, digits: int = 3):
        delta = None if a is None or b is None else b - a
        sign = "" if delta is None else ("+" if delta >= 0 else "")
        rows.append([name, fmt(a, digits), fmt(b, digits), "-" if delta is None else f"{sign}{delta:.{digits}f}"])

    add("precision", _num(before.summary.get("precision")), _num(after.summary.get("precision")))
    add("recall", _num(before.summary.get("recall")), _num(after.summary.get("recall")))
    add("F1", _num(before.summary.get("f1")), _num(after.summary.get("f1")))
    add("FP/photo", fp_per_photo(before), fp_per_photo(after), 2)
    add("exact meals", _num(before.summary.get("exact_meals")), _num(after.summary.get("exact_meals")), 0)
    add("mean latency (ms)", mean_latency_ms(before), mean_latency_ms(after), 0)
    return rows


@dataclass
class Tally:
    unmatched_model_names: Counter = field(default_factory=Counter)
    false_positives: Counter = field(default_factory=Counter)
    misses: Counter = field(default_factory=Counter)


def tally_errors(latest: dict[tuple[str, str], RunRecord], dataset: str) -> Tally:
    """Counts across every strategy's newest run on a dataset (what the next alias round needs)."""
    t = Tally()
    for (ds, _strategy), r in latest.items():
        if ds != dataset:
            continue
        for img in r.images:
            for p in img.get("predicted", []) or []:
                if isinstance(p, dict) and p.get("key") in (None, "") and p.get("name"):
                    t.unmatched_model_names[str(p["name"])] += 1
            for name in img.get("false_positives", []) or []:
                t.false_positives[str(name)] += 1
            for name in img.get("misses", []) or []:
                t.misses[str(name)] += 1
    return t


def top_lines(counter: Counter, n: int = 15) -> list[str]:
    return [f"| {name} | {count} |" for name, count in counter.most_common(n)] or ["| (none) | 0 |"]


def markdown_table(rows: list[list[str]]) -> list[str]:
    out = ["| " + " | ".join(rows[0]) + " |", "|" + "|".join("---" for _ in rows[0]) + "|"]
    out += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return out


def build_markdown(latest: dict[tuple[str, str], RunRecord], problems: list[str]) -> str:
    out = ["# Food-vision eval summary", "", "Generated by `tool/eval/compare_results.py` from the newest result per dataset and strategy.", ""]
    out += ["## Results", ""]
    if latest:
        out += markdown_table(table_rows(latest))
    else:
        out.append("No result files found.")
    out.append("")
    for dataset, label in ((TRAIN, "Train (nutrition5k_50)"), (HOLDOUT, "Holdout (nutrition5k_holdout)")):
        rows = delta_rows(latest, dataset)
        out += [f"## Before and after: {label}", ""]
        out += markdown_table(rows) if rows else [f"Needs both `{LEGACY}` and `{PIPELINE}` runs on `{dataset}`."]
        out.append("")
    t = tally_errors(latest, HOLDOUT)
    out += ["## Holdout: most frequent names (all strategies, newest runs)", ""]
    out += ["### Unmatched model names (no database key)", "", "| name | count |", "|---|---|"]
    out += top_lines(t.unmatched_model_names) + [""]
    out += ["### Most frequent false positives", "", "| name | count |", "|---|---|"]
    out += top_lines(t.false_positives) + [""]
    out += ["### Most frequent misses", "", "| name | count |", "|---|---|"]
    out += top_lines(t.misses) + [""]
    if problems:
        out += ["## Files that could not be read", ""] + [f"- {p}" for p in problems] + [""]
    return "\n".join(out)


def _console(text: str) -> None:
    stream = sys.stdout
    try:
        stream.write(text + "\n")
    except UnicodeEncodeError:
        stream.buffer.write((text + "\n").encode("utf-8", "replace"))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--root", default=os.path.normpath(os.path.join(here, "..", "..")))
    ap.add_argument("--out", default=None, help="markdown output (default: <root>/eval/results_summary.md)")
    args = ap.parse_args(argv)
    root = os.path.abspath(args.root)
    out = args.out or os.path.join(root, "eval", "results_summary.md")

    records, problems = load_records(root)
    latest = newest_per_key(records)
    text = build_markdown(latest, problems)
    _console(text)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text + "\n")
    _console(f"\nWrote {os.path.abspath(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

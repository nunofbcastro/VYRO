"""Unit tests for tool/eval/compare_results.py. Run: py -I -m unittest tool/eval/test_compare_results.py"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import compare_results as cr  # noqa: E402


def doc(strategy, dataset="nutrition5k_50", timestamp="20261026-100000", precision=0.5, recall=0.5, f1=0.5,
        tp=5, fp=5, fn=5, exact=2, photos=10, images=None, mean_latency=1000.0):
    return {
        "meta": {"timestamp": timestamp, "strategy": strategy, "labels": f"eval/datasets/{dataset}/labels.json"},
        "summary": {
            "photos": photos, "errors": 0, "tp": tp, "fp": fp, "fn": fn, "exact_meals": exact,
            "precision": precision, "recall": recall, "f1": f1, "exact_meal_rate": exact / photos,
            "mean_false_positives_per_photo": fp / photos, "mean_latency_ms": mean_latency,
            "median_latency_ms": mean_latency,
        },
        "images": images or [],
    }


class ParseTest(unittest.TestCase):
    def test_dataset_from_labels_path(self):
        self.assertEqual(cr.dataset_name("eval/datasets/nutrition5k_holdout/labels.json", "x"), "nutrition5k_holdout")
        self.assertEqual(cr.dataset_name("eval/labels.json", "x"), "eval")
        self.assertEqual(cr.dataset_name("eval\\datasets\\nutrition5k_50\\labels.json", "x"), "nutrition5k_50")
        self.assertEqual(cr.dataset_name(None, "fallback"), "fallback")

    def test_parse_result_reads_strategy_and_summary(self):
        r = cr.parse_result(doc("pipeline", precision=0.25), "a.json")
        self.assertEqual(r.dataset, "nutrition5k_50")
        self.assertEqual(r.strategy, "pipeline")
        self.assertEqual(r.summary["precision"], 0.25)

    def test_missing_meta_raises(self):
        with self.assertRaises(KeyError):
            cr.parse_result({"summary": {}}, "a.json")


class AggregationTest(unittest.TestCase):
    def test_newest_run_wins_per_dataset_and_strategy(self):
        records = [
            cr.parse_result(doc("pipeline", timestamp="20261026-100000", precision=0.1), "old.json"),
            cr.parse_result(doc("pipeline", timestamp="20261027-090000", precision=0.9), "new.json"),
            cr.parse_result(doc("pipeline", dataset="nutrition5k_holdout", timestamp="20261020-000000"), "h.json"),
        ]
        latest = cr.newest_per_key(records)
        self.assertEqual(len(latest), 2)
        self.assertEqual(latest[("nutrition5k_50", "pipeline")].summary["precision"], 0.9)

    def test_timestamps_compare_as_text_not_insertion_order(self):
        records = [
            cr.parse_result(doc("legacy_app", timestamp="20261027-090000", precision=0.7), "b.json"),
            cr.parse_result(doc("legacy_app", timestamp="20261026-090000", precision=0.2), "a.json"),
        ]
        self.assertEqual(cr.newest_per_key(records)[("nutrition5k_50", "legacy_app")].summary["precision"], 0.7)

    def test_mean_latency_falls_back_to_images(self):
        images = [{"latency_ms": 100}, {"latency_ms": 300}, {"latency_ms": None}]
        r = cr.parse_result(doc("pipeline", images=images, mean_latency=None), "a.json")
        r.summary["mean_latency_ms"] = None
        self.assertEqual(cr.mean_latency_ms(r), 200.0)

    def test_fp_per_photo_uses_summary(self):
        r = cr.parse_result(doc("pipeline", fp=6, photos=3), "a.json")
        self.assertAlmostEqual(cr.fp_per_photo(r), 2.0)


class TableAndDeltaTest(unittest.TestCase):
    def setUp(self):
        self.latest = cr.newest_per_key([
            cr.parse_result(doc("legacy_app", precision=0.5, recall=0.4, f1=0.44, fp=10, exact=2, photos=10, mean_latency=2000), "l.json"),
            cr.parse_result(doc("pipeline", precision=0.6, recall=0.5, f1=0.55, fp=5, exact=4, photos=10, mean_latency=2500), "p.json"),
        ])

    def test_table_has_row_per_dataset_strategy(self):
        rows = cr.table_rows(self.latest)
        self.assertEqual(rows[0][0], "dataset")
        self.assertEqual(len(rows), 3)
        pipeline = [r for r in rows if r[1] == "pipeline"][0]
        self.assertEqual(pipeline[3:5], ["0.600", "0.500"])
        self.assertEqual(pipeline[6], "4/10")
        self.assertEqual(pipeline[7], "0.50")

    def test_delta_is_pipeline_minus_legacy(self):
        rows = cr.delta_rows(self.latest, "nutrition5k_50")
        by_name = {r[0]: r for r in rows[1:]}
        self.assertEqual(by_name["precision"][3], "+0.100")
        self.assertEqual(by_name["FP/photo"][3], "-0.50")
        self.assertEqual(by_name["exact meals"][3], "+2")

    def test_delta_none_when_one_side_missing(self):
        self.assertIsNone(cr.delta_rows(self.latest, "nutrition5k_holdout"))

    def test_missing_metric_shows_dash(self):
        self.assertEqual(cr.fmt(None), "-")

    def test_markdown_contains_sections(self):
        text = cr.build_markdown(self.latest, [])
        self.assertIn("## Results", text)
        self.assertIn("## Before and after: Train", text)
        self.assertIn("Needs both", text)


class TallyTest(unittest.TestCase):
    def test_counts_unmatched_names_and_errors_on_holdout(self):
        images = [{
            "predicted": [{"name": "Ovo", "key": None}, {"name": "Ovo estrelado", "key": "egg_fried"}],
            "false_positives": ["Ovo"],
            "misses": ["Pão"],
        }]
        latest = cr.newest_per_key([cr.parse_result(doc("pipeline", dataset="nutrition5k_holdout", images=images), "h.json")])
        t = cr.tally_errors(latest, "nutrition5k_holdout")
        self.assertEqual(t.unmatched_model_names["Ovo"], 1)
        self.assertNotIn("Ovo estrelado", t.unmatched_model_names)
        self.assertEqual(t.false_positives["Ovo"], 1)
        self.assertEqual(t.misses["Pão"], 1)
        self.assertEqual(cr.tally_errors(latest, "nutrition5k_50").misses, {})


class LoadTest(unittest.TestCase):
    def test_load_reads_result_folders_and_reports_bad_files(self):
        import json
        with tempfile.TemporaryDirectory() as root:
            d = os.path.join(root, "eval", "datasets", "nutrition5k_holdout", "results")
            os.makedirs(d)
            os.makedirs(os.path.join(root, "eval", "results"))
            with open(os.path.join(d, "a.json"), "w", encoding="utf-8") as fh:
                json.dump(doc("pipeline", dataset="nutrition5k_holdout"), fh)
            with open(os.path.join(root, "eval", "results", "bad.json"), "w", encoding="utf-8") as fh:
                fh.write("{not json")
            records, problems = cr.load_records(root)
            self.assertEqual([r.dataset for r in records], ["nutrition5k_holdout"])
            self.assertEqual(len(problems), 1)
            self.assertIn("bad.json", problems[0])


if __name__ == "__main__":
    unittest.main()

"""Future-only acceptance cases for GAME-WEB-CONTINUE-PERF-003/r1.

Source checked into Draft PR #12 without executing these tests or any program.
Uses only synthetic JSON evidence, temporary local paths, and standard unittest.
NOT_RUN is the delivery status; assertions below are future acceptance criteria.
"""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from perf_report_candidate import (
    ANALYZER_PERCENTILE, BUDGETS, STAT_PATHS, build_report, read_object, save_pair
)
from perf_series_candidate import (
    _snapshot, build_series_summary, html_series_report, read_series_manifest,
    MAX_GROUP_RUNS, SCHEMA,
)


def synthetic_analysis(frame_p50=None):
    checks = {
        key: {"value": bound, "status": "PASS", "upper_inclusive": bound}
        for key, _, _, bound in BUDGETS
    }
    if frame_p50 is not None:
        checks["frame_p50_ms"]["value"] = frame_p50
        checks["frame_p50_ms"]["status"] = (
            "PASS" if frame_p50 <= 12 else "FAIL"
        )
    stats = {
        "frame_ms": {"p50": None, "p95": None, "p99": None},
        "script_ms": {"p95": None},
        "ram_gib": {"peak": None},
        "vram_delta_gib": {"peak": None},
        "draw_calls": {"peak": None},
        "triangles": {"peak": None},
    }
    for key, path in STAT_PATHS.items():
        stats[path[0]][path[1]] = checks[key]["value"]
    subset = (
        "FAIL" if any(x["status"] == "FAIL" for x in checks.values()) else "PASS"
    )
    return {
        "task_id": "GAME-WEB-PERF-002",
        "version": "r1",
        "sample_count": 100,
        "error_count": 0,
        "errors": [],
        "percentile_definition": ANALYZER_PERCENTILE,
        "status": "incomplete",
        "full_scene_pass": False,
        "measured_subset_status": subset,
        "stats": stats,
        "checks": checks,
    }


def run(run_id, frame_p50=12, capture=None, missing_key=None):
    source = synthetic_analysis(frame_p50)
    if missing_key:
        source["checks"][missing_key]["value"] = None
        source["checks"][missing_key]["status"] = "INCOMPLETE"
        section, field = STAT_PATHS[missing_key]
        source["stats"][section][field] = None
        source["measured_subset_status"] = "INCOMPLETE"
    report = build_report(source, capture=capture)
    return _snapshot(run_id, report)


def group(name, *runs):
    return {"name": name, "runs": list(runs)}


def metric(stats, key):
    return next(row for row in stats["metrics"] if row["key"] == key)


def manifest_write(root, groups):
    filename = root / "series.json"
    filename.write_text(
        json.dumps({"schema": SCHEMA, "groups": groups}), encoding="utf-8"
    )
    return filename


class SeriesFutureAcceptance(unittest.TestCase):
    def test_three_runs_use_run_level_median_never_pooled_frames(self):
        report = build_series_summary([
            group("current", run("A", 9), run("B", 12), run("C", 10)),
        ])
        p50 = metric(report["groups"][0], "frame_p50_ms")
        self.assertEqual((p50["min"], p50["median"], p50["max"]), (9, 10, 12))
        self.assertEqual((p50["n_observed"], p50["n_total"]), (3, 3))
        self.assertEqual(p50["coverage"], "COMPLETE_NUMERIC")
        self.assertFalse(report["frame_percentiles_pooled"])
        self.assertFalse(report["full_scene_pass"])
        self.assertEqual(report["status"], "INCOMPLETE")
        self.assertEqual(report["test_status"], "NOT_RUN")

    def test_partial_missing_is_not_zero_and_coverage_is_explicit(self):
        summary = build_series_summary([
            group("current", run("A"), run("B", missing_key="script_p95_ms")),
        ])
        script = metric(summary["groups"][0], "script_p95_ms")
        self.assertEqual((script["n_observed"], script["n_missing"]), (1, 1))
        self.assertEqual(script["coverage"], "PARTIAL")
        self.assertEqual(script["missing_runs"][0]["run_id"], "B")
        self.assertEqual(script["median"], 2)
        self.assertIsNone(summary["groups"][0]["runs"][1]["measurements"]["script_p95_ms"]["value"])

    def test_entirely_missing_field_is_null_not_pass(self):
        summary = build_series_summary([
            group("current", run("A", missing_key="script_p95_ms"),
                  run("B", missing_key="script_p95_ms")),
        ])
        script = metric(summary["groups"][0], "script_p95_ms")
        self.assertEqual(script["coverage"], "NOT_MEASURED")
        self.assertIsNone(script["min"])
        self.assertIsNone(script["median"])
        self.assertIsNone(script["max"])

    def test_groups_compare_medians_not_frame_series(self):
        summary = build_series_summary([
            group("baseline", run("B1", 11), run("B2", 12)),
            group("current", run("C1", 9), run("C2", 10)),
        ])
        comp = summary["group_comparison"]
        row = next(x for x in comp["rows"] if x["key"] == "frame_p50_ms")
        self.assertEqual(row["baseline_median"], 11.5)
        self.assertEqual(row["current_median"], 9.5)
        self.assertEqual(row["delta_median"], -2)
        self.assertEqual(row["status"], "NUMERIC_ONLY")
        self.assertFalse(comp["comparison_is_verified_benchmark"])
        self.assertEqual(comp["context_status"], "UNVERIFIED")

    def test_partially_missing_group_has_no_delta(self):
        summary = build_series_summary([
            group("baseline", run("B1"), run("B2")),
            group("current", run("C1", missing_key="frame_p99_ms"), run("C2")),
        ])
        row = next(x for x in summary["group_comparison"]["rows"]
                   if x["key"] == "frame_p99_ms")
        self.assertEqual(row["status"], "NOT_COMPARABLE")
        self.assertIsNone(row["delta_median"])
        self.assertIsNone(row["delta_percent"])

    def test_zero_median_denominator_has_null_percent(self):
        summary = build_series_summary([
            group("baseline", run("B1", 0), run("B2", 0)),
            group("current", run("C1", 1), run("C2", 1)),
        ])
        row = next(x for x in summary["group_comparison"]["rows"]
                   if x["key"] == "frame_p50_ms")
        self.assertEqual(row["delta_median"], 1)
        self.assertIsNone(row["delta_percent"])

    def test_conflicting_engine_scene_metadata_prevents_group_deltas(self):
        first = {"engine_version": "4.7.2", "rendering_driver": "opengl3",
                 "scene_sha256": "a" * 64, "is_synthetic": True}
        second = {"engine_version": "4.7.2", "rendering_driver": "vulkan",
                  "scene_sha256": "b" * 64, "is_synthetic": True}
        summary = build_series_summary([
            group("baseline", run("B", capture=first)),
            group("current", run("C", capture=second)),
        ])
        comp = summary["group_comparison"]
        self.assertEqual(comp["context_status"], "CONFLICT")
        self.assertTrue(all(x["delta_median"] is None for x in comp["rows"]))

    def test_synthetic_and_real_declarations_are_not_equivalent(self):
        base = {"is_synthetic": True, "rendering_driver": "opengl3",
                "engine_version": "4.7.2"}
        real = {"is_synthetic": False, "rendering_driver": "opengl3",
                "display_server": "windows", "capture_complete": True,
                "engine_version": "4.7.2"}
        summary = build_series_summary([
            group("baseline", run("B", capture=base)),
            group("current", run("C", capture=real)),
        ])
        self.assertEqual(summary["group_comparison"]["context_status"], "CONFLICT")
        self.assertFalse(summary["has_verified_real_game_benchmark"])

    def test_headless_and_rendered_origin_mismatch_is_not_comparable(self):
        headless = {"is_synthetic": False, "rendering_driver": "dummy",
                    "display_server": "headless", "capture_complete": True,
                    "engine_version": "4.7.2"}
        rendered = {"is_synthetic": False, "rendering_driver": "opengl3",
                    "display_server": "windows", "capture_complete": True,
                    "engine_version": "4.7.2"}
        summary = build_series_summary([
            group("baseline", run("H", capture=headless)),
            group("current", run("R", capture=rendered)),
        ])
        comparison = summary["group_comparison"]
        self.assertEqual(comparison["context_status"], "CONFLICT")
        self.assertTrue(all(row["delta_median"] is None for row in comparison["rows"]))

    def test_html_is_offline_and_escapes_declared_metadata(self):
        attack = {"is_synthetic": True, "engine_version": "<script>alert(1)</script>"}
        result = build_series_summary([group("current", run("A", capture=attack), run("B"))])
        page = html_series_report(result)
        self.assertNotIn("<script>", page)
        self.assertIn("default-src 'none'", page)
        self.assertIn("NOT_RUN", page)
        self.assertNotIn("https://", page)

    def test_manifest_loads_actual_synthetic_objects_and_hides_source_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            (base / "one.json").write_text(json.dumps(synthetic_analysis()), encoding="utf-8")
            (base / "two.json").write_text(json.dumps(synthetic_analysis(10)), encoding="utf-8")
            manifest = manifest_write(base, [{
                "name": "current",
                "runs": [{"id": "A", "analysis": "one.json"},
                         {"id": "B", "analysis": "two.json"}],
            }])
            groups = read_series_manifest(manifest, read_object, build_report)
            report = build_series_summary(groups)
            self.assertEqual(report["groups"][0]["n_runs"], 2)
            self.assertNotIn(str(base), json.dumps(report))

    def test_reject_duplicate_run_identifiers(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            for name in ("a", "b"):
                (base / (name + ".json")).write_text(
                    json.dumps(synthetic_analysis()), encoding="utf-8"
                )
            manifest = manifest_write(base, [{
                "name": "current",
                "runs": [{"id": "x", "analysis": "a.json"},
                         {"id": "x", "analysis": "b.json"}],
            }])
            with self.assertRaises(ValueError):
                read_series_manifest(manifest, read_object, build_report)

    def test_reject_duplicate_input_file(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            (base / "a.json").write_text(json.dumps(synthetic_analysis()), encoding="utf-8")
            manifest = manifest_write(base, [{
                "name": "current",
                "runs": [{"id": "A", "analysis": "a.json"},
                         {"id": "B", "analysis": "a.json"}],
            }])
            with self.assertRaises(ValueError):
                read_series_manifest(manifest, read_object, build_report)

    def test_reject_traversal_absolute_and_url_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            (base / "a.json").write_text(json.dumps(synthetic_analysis()), encoding="utf-8")
            for attack in ("../outside.json", "/tmp/other.json", "http://evil/data.json",
                           "C:/secret.json", "relative\\bad.json"):
                manifest = manifest_write(base, [{
                    "name": "current",
                    "runs": [{"id": "A", "analysis": "a.json"},
                             {"id": "B", "analysis": attack}],
                }])
                with self.assertRaises((ValueError, OSError)):
                    read_series_manifest(manifest, read_object, build_report)

    def test_limit_groups_and_count_to_prevent_unbounded_read(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            rows = [
                {"id": "run_" + str(i), "analysis": "a" + str(i) + ".json"}
                for i in range(MAX_GROUP_RUNS + 1)
            ]
            manifest = manifest_write(base, [{"name": "current", "runs": rows}])
            with self.assertRaises(ValueError):
                read_series_manifest(manifest, read_object, build_report)
            manifest = manifest_write(base, [{"name": "baseline", "runs": []},
                                            {"name": "current", "runs": []}])
            with self.assertRaises(ValueError):
                read_series_manifest(manifest, read_object, build_report)

    def test_exclusive_html_and_summary_creation(self):
        summary = build_series_summary([group("current", run("A"), run("B"))])
        with tempfile.TemporaryDirectory() as folder:
            prefix = Path(folder) / "series"
            html, meta = save_pair(prefix, html_series_report(summary), summary)
            content_before = html.read_bytes(), meta.read_bytes()
            with self.assertRaises(FileExistsError):
                save_pair(prefix, "overwrite", {})
            self.assertEqual(content_before, (html.read_bytes(), meta.read_bytes()))


if __name__ == "__main__":
    unittest.main()

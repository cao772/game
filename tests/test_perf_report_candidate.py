"""Future acceptance cases for GAME-WEB-MODULE-PERF-001/r1.

Intentionally NOT executed when authored or submitted. Only standard unittest.
These use synthetic dictionaries; no Godot runs or measured benchmarks.
"""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from perf_report_candidate import (BUDGETS, MAX_INPUT_BYTES, build_report, compare_reports,
                                   html_report, read_object, save_pair)


def synthetic_analysis():
    checks = {
        key: {"value": bound, "upper_inclusive": bound, "status": "PASS"}
        for key, _, _, bound in BUDGETS
    }
    return {
        "task_id": "GAME-WEB-PERF-002",
        "version": "r1",
        "error_count": 0,
        "errors": [],
        "sample_count": 3,
        "stats": {
            "frame_ms": {"p50": 12.0, "p95": 16.7, "p99": 24.0},
            "script_ms": {"p95": 2.0},
            "ram_gib": {"peak": 1.2},
            "vram_delta_gib": {"peak": 1.0},
            "draw_calls": {"peak": 200},
            "triangles": {"peak": 150000},
        },
        "status": "incomplete",
        "full_scene_pass": False,
        "percentile_definition": "nearest-rank: ascending, rank=ceil(p*n); no interpolation",
        "measured_subset_status": "PASS",
        "checks": checks,
        "not_measured": {
            "cold_load_s": {"value": None, "status": "NOT_MEASURED"}
        },
    }


class ReportCandidateCases(unittest.TestCase):
    def test_boundary_subset_is_not_whole_scene_pass(self):
        report = build_report(synthetic_analysis())
        self.assertEqual(report["measured_subset_status"], "PASS")
        self.assertEqual(report["whole_scene_status"], "INCOMPLETE")
        self.assertFalse(report["full_scene_pass"])
        self.assertEqual(report["budget_approval"], "UNAPPROVED_PROPOSAL")
        self.assertEqual(report["capture"]["origin"], "UNVERIFIED")

    def test_threshold_breach_is_fail(self):
        src = synthetic_analysis()
        src["checks"]["frame_p99_ms"]["value"] = 24.01
        src["checks"]["frame_p99_ms"]["status"] = "FAIL"
        src["stats"]["frame_ms"]["p99"] = 24.01
        src["measured_subset_status"] = "FAIL"
        report = build_report(src)
        self.assertEqual(report["measured_subset_status"], "FAIL")
        self.assertEqual(
            next(m for m in report["metrics"] if m["key"] == "frame_p99_ms")["status"],
            "FAIL",
        )
        self.assertFalse(report["full_scene_pass"])

    def test_null_and_missing_are_not_pass(self):
        for drop in (False, True):
            src = synthetic_analysis()
            if drop:
                del src["checks"]["script_p95_ms"]
            else:
                src["checks"]["script_p95_ms"] = {
                    "value": None, "upper_inclusive": 2.0, "status": "INCOMPLETE"
                }
            src["measured_subset_status"] = "INCOMPLETE"
            result = build_report(src)
            self.assertEqual(result["measured_subset_status"], "INCOMPLETE")
            value = next(x for x in result["metrics"] if x["key"] == "script_p95_ms")
            self.assertIsNone(value["observed"])
            self.assertEqual(value["status"], "NOT_MEASURED")

    def test_analyzer_error_blocks_pass(self):
        src = synthetic_analysis()
        src["error_count"] = 1
        src["measured_subset_status"] = "INCOMPLETE"
        result = build_report(src)
        self.assertEqual(result["measured_subset_status"], "INCOMPLETE")
        self.assertFalse(any(x["status"] == "PASS" for x in result["metrics"]))

    def test_incorrect_pass_and_budget_conflict_are_incomplete(self):
        src = synthetic_analysis()
        src["checks"]["frame_p99_ms"]["value"] = 26
        self.assertEqual(build_report(src)["measured_subset_status"], "INCOMPLETE")
        src = synthetic_analysis()
        src["checks"]["frame_p99_ms"]["upper_inclusive"] = 100
        self.assertEqual(build_report(src)["measured_subset_status"], "INCOMPLETE")

    def test_unverified_and_synthetic_origin(self):
        src = synthetic_analysis()
        result = build_report(src, capture={"is_synthetic": True})
        self.assertEqual(result["capture"]["origin"], "SYNTHETIC")
        result = build_report(src, capture={
            "is_synthetic": False,
            "capture_complete": True,
            "display_server": "headless",
            "rendering_driver": "dummy",
        })
        self.assertEqual(result["capture"]["origin"], "NOT_GPU_BENCHMARK")

    def test_process_memory_never_fills_frame_ram(self):
        src = synthetic_analysis()
        src["checks"]["ram_peak_gib"]["value"] = None
        src["checks"]["ram_peak_gib"]["status"] = "INCOMPLETE"
        src["measured_subset_status"] = "INCOMPLETE"
        memory = {
            "is_synthetic": False,
            "status": "complete",
            "samples": 10,
            "pid": 123,
            "expected_exe_matched": True,
            "process_creation_filetime_100ns": "12345678901",
            "working_set_peak_observed_gib": 0.5,
            "private_bytes_peak_observed_gib": 0.3,
        }
        result = build_report(src, memory=memory)
        measured = next(x for x in result["metrics"] if x["key"] == "ram_peak_gib")
        self.assertIsNone(measured["observed"])
        self.assertEqual(result["process_memory"]["working_set_peak_observed_gib"], 0.5)
        self.assertEqual(result["whole_scene_status"], "INCOMPLETE")

    def test_zero_samples_and_nan_cannot_pass(self):
        src = synthetic_analysis()
        src["sample_count"] = 0
        self.assertEqual(build_report(src)["measured_subset_status"], "INCOMPLETE")
        src = synthetic_analysis()
        src["checks"]["frame_p50_ms"]["value"] = float("nan")
        src["measured_subset_status"] = "INCOMPLETE"
        self.assertEqual(build_report(src)["measured_subset_status"], "INCOMPLETE")

    def test_escapes_untrusted_text_and_is_offline(self):
        src = synthetic_analysis()
        rendered = html_report(build_report(src, capture={
            "is_synthetic": True, "engine_version": '<script>alert(1)</script>'
        }))
        self.assertNotIn("<script>", rendered)
        self.assertIn("&lt;script&gt;", rendered)
        self.assertIn("default-src 'none'", rendered)
        self.assertNotIn("https://", rendered)

    def test_refuses_to_overwrite_either_file(self):
        result = build_report(synthetic_analysis())
        with tempfile.TemporaryDirectory() as folder:
            prefix = Path(folder) / "report"
            html, summary = save_pair(prefix, html_report(result), result)
            original_html = html.read_text(encoding="utf-8")
            original_json = summary.read_text(encoding="utf-8")
            with self.assertRaises(FileExistsError):
                save_pair(prefix, "bad", {"bad": True})
            self.assertEqual(html.read_text(encoding="utf-8"), original_html)
            self.assertEqual(summary.read_text(encoding="utf-8"), original_json)

            second_prefix = Path(folder) / "second"
            previous_json = Path(str(second_prefix) + ".summary.json")
            previous_json.write_text("protected", encoding="utf-8")
            with self.assertRaises(FileExistsError):
                save_pair(second_prefix, "bad", {"bad": True})
            self.assertFalse(Path(str(second_prefix) + ".html").exists())
            self.assertEqual(previous_json.read_text(encoding="utf-8"), "protected")

    def test_two_run_numeric_comparison_is_not_benchmark(self):
        baseline = build_report(synthetic_analysis())
        current_src = synthetic_analysis()
        current_src["checks"]["frame_p99_ms"]["value"] = 23.0
        current_src["stats"]["frame_ms"]["p99"] = 23.0
        current = build_report(current_src)
        comp = compare_reports(current, baseline)
        frame = next(x for x in comp["rows"] if x["key"] == "frame_p99_ms")
        self.assertEqual(frame["baseline"], 24.0)
        self.assertEqual(frame["current"], 23.0)
        self.assertEqual(frame["delta"], -1.0)
        self.assertEqual(frame["status"], "NUMERIC_ONLY")
        self.assertFalse(comp["comparison_is_verified_benchmark"])
        self.assertEqual(comp["context_status"], "UNVERIFIED")

    def test_compare_missing_is_not_comparable(self):
        baseline_src = synthetic_analysis()
        baseline_src["checks"]["script_p95_ms"]["value"] = None
        baseline_src["checks"]["script_p95_ms"]["status"] = "INCOMPLETE"
        baseline_src["stats"]["script_ms"]["p95"] = None
        baseline_src["measured_subset_status"] = "INCOMPLETE"
        comp = compare_reports(build_report(synthetic_analysis()), build_report(baseline_src))
        row = next(x for x in comp["rows"] if x["key"] == "script_p95_ms")
        self.assertIsNone(row["delta"])
        self.assertEqual(row["status"], "NOT_COMPARABLE")

    def test_compare_declared_scene_hash_conflict(self):
        src = synthetic_analysis()
        left = build_report(src, capture={"scene_sha256": "a" * 64, "is_synthetic": True})
        right = build_report(src, capture={"scene_sha256": "b" * 64, "is_synthetic": True})
        comp = compare_reports(left, right)
        self.assertEqual(comp["context_status"], "CONFLICT")
        self.assertTrue(all(row["delta"] is None for row in comp["rows"]))

    def test_zero_baseline_has_delta_but_undefined_percent(self):
        src = synthetic_analysis()
        src["checks"]["draw_calls_peak"]["value"] = 0
        src["stats"]["draw_calls"]["peak"] = 0
        baseline = build_report(src)
        current = build_report(synthetic_analysis())
        comp = compare_reports(current, baseline)
        row = next(x for x in comp["rows"] if x["key"] == "draw_calls_peak")
        self.assertEqual(row["delta"], 200)
        self.assertIsNone(row["delta_percent"])

    def test_wrong_stats_is_incomplete_even_with_pass_check(self):
        src = synthetic_analysis()
        src["stats"]["frame_ms"]["p50"] = 8.0
        src["measured_subset_status"] = "INCOMPLETE"
        result = build_report(src)
        metric = next(x for x in result["metrics"] if x["key"] == "frame_p50_ms")
        self.assertEqual(metric["status"], "INCOMPLETE")
        self.assertEqual(result["measured_subset_status"], "INCOMPLETE")

    def test_wrong_version_definition_and_missing_error_details(self):
        for key, value in (
            ("version", "r999"),
            ("percentile_definition", "nearest-rank ceil is not verified"),
            ("errors", None),
            ("status", "PASS"),
        ):
            src = synthetic_analysis()
            src[key] = value
            src["measured_subset_status"] = "INCOMPLETE"
            result = build_report(src)
            self.assertEqual(result["measured_subset_status"], "INCOMPLETE")
            self.assertFalse(any(metric["status"] == "PASS" for metric in result["metrics"]))

    def test_duplicate_json_keys_and_nonfinite_constants_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "bad.json"
            for payload in ('{"x": 1, "x": 2}', '{"x": NaN}', '{"x": Infinity}'):
                file.write_text(payload, encoding="utf-8")
                with self.assertRaises(ValueError):
                    read_object(file)

    def test_json_byte_limit_and_non_object(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "bad.json"
            file.write_text('{"payload":"' + ("x" * MAX_INPUT_BYTES) + '"}', encoding="utf-8")
            with self.assertRaises(ValueError):
                read_object(file)
            file.write_text('[1,2]', encoding="utf-8")
            with self.assertRaises(ValueError):
                read_object(file)

    def test_comparison_html_escapes_source_metadata(self):
        left = build_report(synthetic_analysis(), capture={
            "is_synthetic": True,
            "engine_version": '<img src=x onerror=alert(1)>'
        })
        left["comparison"] = compare_reports(left, build_report(synthetic_analysis()))
        output = html_report(left)
        self.assertNotIn('<img src=x', output)
        self.assertIn('&lt;img', output)
        self.assertIn('两次观测数值比较', output)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Future acceptance cases for GAME-WEB-MODULE-TECHQA-001/r1.

Pure synthetic in-memory fixtures: no target execution, network or shell.
Author's development request explicitly says NOT_RUN. This file is NOT_RUN.
"""
import base64
import hashlib
import json
import unittest

import perf_qa_results_summary_candidate as summary


def stdout_bytes(document):
    return json.dumps(
        document, ensure_ascii=False, allow_nan=False
    ).encode("utf-8")


def original(case_id, document, classification, defect=False, exit_code=0):
    raw = stdout_bytes(document)
    return {
        "case_id": case_id,
        "purpose": "synthetic acceptance fixture",
        "synthetic": True,
        "input_sha256": hashlib.sha256(b"synthetic-csv").hexdigest(),
        "command": ["python", "/candidate/analyzer.py", "/temp/input.csv"],
        "raw_stdout": raw.decode("utf-8"),
        "raw_stderr": "",
        "stdout_base64": base64.b64encode(raw).decode("ascii"),
        "stderr_base64": "",
        "exit_code": exit_code,
        "timed_out": False,
        "classification": classification,
        "defect": defect,
        "verdict": None,
        "verdict_fields": [],
        "detail": "synthetic fixture",
    }


def analyzer_json(subset="PASS", errors=0):
    statuses = {
        key: {"status": subset if not errors else "INCOMPLETE",
              "value": 0 if not errors else None}
        for key in summary.MEASURED_METRICS
    }
    return {
        "task_id": "GAME-WEB-PERF-002",
        "version": "r1",
        "scope": "CSV measured subset only",
        "sample_count": 100,
        "status": "incomplete",
        "full_scene_pass": False,
        "measured_subset_status": subset,
        "error_count": errors,
        "checks": statuses,
        "not_measured": {
            key: {"value": None, "status": "NOT_MEASURED"}
            for key in summary.SCENE_GAPS
        },
    }


def adapter_case(
    case_id="C01_baseline", classification="baseline_subset_pass",
    subset="PASS", errors=0, exit_code=0, defect=False,
):
    doc = analyzer_json(subset, errors)
    raw = original(
        case_id, doc, "schema_unrecognized",
        defect=False, exit_code=exit_code,
    )
    return {
        "case_id": case_id,
        "expected": "baseline_subset_pass",
        "classification": classification,
        "defect": defect,
        "measured_subset_status": subset,
        "full_scene_status": "incomplete",
        "full_scene_pass": False,
        "data_quality": "invalid" if errors else "valid",
        "error_count": errors,
        "schema_issues": [],
        "notes": [],
        "original_qa_evidence": raw,
    }


def adapter_report(cases):
    defects = [c["case_id"] for c in cases if c["defect"]]
    return {
        "task_id": summary.ADAPTER_TASK,
        "version": "r1",
        "source_pins": {
            "qa_pr5_head": summary.PR5_HEAD,
            "analyzer_pr2_head": summary.ANALYZER_HEAD,
        },
        "status": "defects_found" if defects else "no_definitive_subset_defects",
        "exit_code": 1 if defects else 0,
        "scope": "measured CSV subset only",
        "full_scene_status": "incomplete",
        "full_scene_pass": False,
        "full_scene_certified": False,
        "synthetic_data": True,
        "actual_performance_measurement": False,
        "target_source_modified": False,
        "cases_planned": len(cases),
        "cases_executed": len(cases),
        "defect_cases": defects,
        "results": cases,
    }


def qa_case(case_id="C01_baseline", classification="baseline_pass",
            defect=False, verdict=True, exit_code=0):
    row = original(
        case_id, {"status": "PASS" if verdict else "FAIL"},
        classification, defect, exit_code,
    )
    row["verdict"] = verdict
    return row


def qa_report(cases):
    defects = [c["case_id"] for c in cases if c["defect"]]
    return {
        "task_id": summary.QA_TASK,
        "version": "r2",
        "status": "defects_found" if defects else "no_definitive_defects",
        "exit_code": 1 if defects else 0,
        "synthetic_data": True,
        "actual_performance_measurement": False,
        "full_scene_performance_certified": False,
        "target_source_modified": False,
        "cases_planned": len(cases),
        "cases_executed": len(cases),
        "cases_skipped": [],
        "defect_cases": defects,
        "results": cases,
    }


def summarize(*docs):
    return summary.aggregate_documents([
        (f"synthetic_{i}.json", doc) for i, doc in enumerate(docs)
    ])


class ResultsSummaryCandidateTests(unittest.TestCase):
    def test_01_baseline_subset_never_scene_pass(self):
        result = summarize(adapter_report([adapter_case()]))
        self.assertEqual(result["status"], "no_definitive_qa_defects")
        self.assertFalse(result["full_scene_pass"])
        self.assertEqual(result["scene_acceptance"], "NOT_ESTABLISHED")
        row = result["reports"][0]["cases"][0]
        self.assertEqual(row["measured_subset"], "PASS")
        self.assertEqual(row["scene"], "not_certified")
        self.assertEqual(set(row["unmeasured_fields"]), set(summary.SCENE_GAPS))

    def test_02_missing_scene_coverage_is_inconclusive(self):
        row = adapter_case()
        doc = json.loads(row["original_qa_evidence"]["raw_stdout"])
        del doc["not_measured"]["cold_load_s"]
        row["original_qa_evidence"] = original(
            row["case_id"], doc, "schema_unrecognized"
        )
        result = summarize(adapter_report([row]))
        self.assertEqual(result["status"], "inconclusive")
        self.assertEqual(result["reports"][0]["cases"][0]["evaluation"],
                         "inconclusive")

    def test_03_claimed_scene_pass_is_not_accepted(self):
        row = adapter_case()
        row["full_scene_pass"] = True
        result = summarize(adapter_report([row]))
        self.assertFalse(result["full_scene_pass"])
        self.assertEqual(result["reports"][0]["cases"][0]["evaluation"],
                         "inconclusive")

    def test_04_raw_base64_disagreement_blocks_certainty(self):
        row = adapter_case()
        row["original_qa_evidence"]["raw_stdout"] = '{"status":"PASS"}'
        result = summarize(adapter_report([row]))
        self.assertEqual(result["status"], "inconclusive")
        issues = result["reports"][0]["cases"][0]["issues"]
        self.assertIn("raw_stdout_mismatch", issues)

    def test_05_unknown_schema_cannot_be_certified(self):
        doc = adapter_report([adapter_case()])
        doc["task_id"] = "other"
        result = summarize(doc)
        self.assertEqual(result["status"], "inconclusive")
        self.assertEqual(result["reports"][0]["issues"],
                         ["unrecognized_report_task_or_version"])

    def test_06_r2_nonzero_explicit_wrong_pass(self):
        rows = [
            qa_case(),
            qa_case("C02_frame_p50", "wrong_pass", True, True, 1),
        ]
        result = summarize(qa_report(rows))
        self.assertEqual(result["status"], "defects_found")
        self.assertEqual(result["confirmed_defects_across_reports"], 1)
        self.assertEqual(result["reports"][0]["subset_counts"],
                         {"not_assessed": 2})

    def test_07_invalid_input_separate_from_measurements(self):
        rows = [
            adapter_case(),
            adapter_case(
                case_id="C10_missing_column",
                classification="invalid_input_rejected",
                subset="INCOMPLETE", errors=1, exit_code=2,
            ),
        ]
        result = summarize(adapter_report(rows))
        self.assertEqual(result["reports"][0]["data_quality_counts"]["invalid"], 1)
        self.assertFalse(result["full_scene_pass"])

    def test_08_explicit_wrong_subset_pass_nonzero(self):
        rows = [
            adapter_case(),
            adapter_case(
                case_id="C02_frame_p50",
                classification="wrong_subset_pass",
                subset="PASS", exit_code=1, defect=True,
            ),
        ]
        result = summarize(adapter_report(rows))
        self.assertEqual(result["confirmed_defects_across_reports"], 1)
        self.assertEqual(result["status"], "defects_found")

    def test_09_unexpected_classification_is_inconclusive(self):
        row = adapter_case()
        row["classification"] = "mystery"
        result = summarize(adapter_report([row]))
        self.assertEqual(result["reports"][0]["cases"][0]["evaluation"],
                         "inconclusive")

    def test_10_schema_issue_cannot_be_ignored(self):
        row = adapter_case()
        row["schema_issues"] = ["threshold_mismatch:frame_p50_ms"]
        result = summarize(adapter_report([row]))
        self.assertEqual(result["status"], "inconclusive")

    def test_11_same_case_id_in_distinct_reports_not_merged(self):
        result = summarize(
            adapter_report([adapter_case()]),
            adapter_report([adapter_case()]),
        )
        self.assertEqual(result["reports_received"], 2)
        self.assertEqual(result["cases_observed_across_reports"], 2)
        self.assertTrue(result["report_units_are_independent"])

    def test_12_duplicate_json_keys_rejected(self):
        with self.assertRaises(summary.ReportInputError):
            summary.strict_json(b'{"status":"PASS","status":"FAIL"}')

    def test_13_non_finite_json_constant_rejected(self):
        with self.assertRaises(summary.ReportInputError):
            summary.strict_json(b'{"value":NaN}')

    def test_14_non_synthetic_data_claim_is_inconclusive(self):
        report = adapter_report([adapter_case()])
        report["synthetic_data"] = False
        result = summarize(report)
        self.assertEqual(result["status"], "inconclusive")
        self.assertIn("synthetic_provenance_not_confirmed",
                      result["reports"][0]["issues"])

    def test_15_missing_evidence_cannot_validate_defect(self):
        rows = [
            adapter_case(),
            adapter_case(
                case_id="C02_frame_p50",
                classification="wrong_subset_pass", subset="PASS",
                exit_code=1, defect=True,
            ),
        ]
        rows[1]["original_qa_evidence"]["stdout_base64"] = "invalid!"
        result = summarize(adapter_report(rows))
        self.assertEqual(result["confirmed_defects_across_reports"], 0)
        self.assertEqual(result["reports"][0]["cases"][1]["evaluation"],
                         "inconclusive")

    def test_16_report_exit_status_disagreement_uncertain(self):
        report = adapter_report([adapter_case()])
        report["exit_code"] = 1
        result = summarize(report)
        self.assertEqual(result["status"], "inconclusive")
        self.assertIn("report_status_exit_conflict",
                      result["reports"][0]["issues"])

    def test_17_incomplete_run_cannot_report_success(self):
        report = adapter_report([adapter_case()])
        report["cases_planned"] = 15
        result = summarize(report)
        self.assertEqual(result["status"], "inconclusive")
        self.assertEqual(result["reports"][0]["cases_skipped_count"], 14)

    def test_18_unknown_fields_do_not_erase_raw_evidence(self):
        row = adapter_case()
        row["vendor_extension"] = {"opaque": "uninterpreted"}
        result = summarize(adapter_report([row]))
        preserved = result["reports"][0]["cases"][0]["evidence"]
        self.assertIn("vendor_extension", preserved)

    def test_19_contradictory_report_claim_never_scene_success(self):
        report = adapter_report([adapter_case()])
        report["full_scene_certified"] = True
        result = summarize(report)
        self.assertEqual(result["status"], "inconclusive")
        self.assertFalse(result["full_scene_pass"])

    def test_20_qa_schema_unrecognized_is_not_failure(self):
        row = qa_case(classification="schema_unrecognized",
                      verdict=None)
        report = qa_report([row])
        report["status"] = "schema_unrecognized"
        report["exit_code"] = 4
        result = summarize(report)
        self.assertEqual(result["status"], "inconclusive")
        self.assertEqual(result["confirmed_defects_across_reports"], 0)


if __name__ == "__main__":
    unittest.main()

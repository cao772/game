#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GAME-WEB-MODULE-TECHQA-002/r1 future offline acceptance (NOT_RUN).

These tests build synthetic in-memory report fixtures. They never invoke
any game, target analyzer, CLI command, network or external application.
Do not interpret these test definitions as execution results.
"""
import argparse
import base64
import hashlib
import json
import unittest

import perf_qa_results_summary_candidate as foundation
import perf_qa_results_views_candidate as views
import test_perf_qa_results_summary_candidate as fixture


def foundation_summary(*documents):
    return foundation.aggregate_documents([
        (f"synthetic_{i}", d) for i, d in enumerate(documents)
    ])


def view(*docs, filters=None, include_evidence=False):
    return views.create_view(
        foundation_summary(*docs), filters or {}, include_evidence
    )


def accepted_case():
    return fixture.adapter_case()


def invalid_case():
    return fixture.adapter_case(
        case_id="C10_missing_column",
        classification="invalid_input_rejected",
        subset="INCOMPLETE", errors=1, exit_code=2,
    )


def failed_case():
    return fixture.adapter_case(
        case_id="C02_frame_p50", classification="subset_rejected",
        subset="FAIL", errors=0, exit_code=1,
    )


def wrong_pass_case():
    return fixture.adapter_case(
        case_id="C02_frame_p50", classification="wrong_subset_pass",
        subset="PASS", exit_code=1, defect=True,
    )


def change_analyzer_json(row, update):
    original = row["original_qa_evidence"]
    doc = json.loads(original["raw_stdout"])
    update(doc)
    modified = fixture.original(
        row["case_id"], doc, original["classification"],
        original["defect"], original["exit_code"],
    )
    row["original_qa_evidence"] = modified
    return row


class ViewsAcceptanceCandidate(unittest.TestCase):
    def test_01_global_status_is_unchanged(self):
        original = foundation_summary(
            fixture.adapter_report([accepted_case(), wrong_pass_case()])
        )
        filtered = views.create_view(
            original, {"evaluation": ("observed_expected_behavior",)}
        )
        self.assertEqual(filtered["status"], original["status"])
        self.assertEqual(filtered["source_summary"]["confirmed_defects"], 1)
        self.assertEqual(filtered["selection_summary"]["selected_confirmed_defects"], 0)
        self.assertFalse(filtered["full_scene"]["full_scene_pass"])

    def test_02_subset_filter_pass(self):
        result = view(
            fixture.adapter_report([accepted_case(), failed_case()]),
            filters={"subset": ("PASS",)},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 1)
        self.assertEqual(result["selected_cases"][0]["measured_subset_status"], "PASS")

    def test_03_generic_r2_is_not_assessed(self):
        result = view(fixture.qa_report([fixture.qa_case()]))
        self.assertEqual(result["selected_cases"][0]["measured_subset_status"],
                         "not_assessed")
        self.assertEqual(
            {item["state"] for item in result["evidence_index"]["unmeasured"]},
            {"not_reported"},
        )

    def test_04_report_type_filter(self):
        result = view(
            fixture.qa_report([fixture.qa_case()]),
            fixture.adapter_report([accepted_case()]),
            filters={"report_type": ("schema_adapter_r1",)},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 1)
        self.assertEqual(result["selected_cases"][0]["report_index"], 1)

    def test_05_same_dimension_OR(self):
        result = view(
            fixture.adapter_report([accepted_case(), failed_case()]),
            filters={"subset": ("PASS", "FAIL")},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 2)

    def test_06_different_dimensions_AND(self):
        result = view(
            fixture.adapter_report([accepted_case(), failed_case()]),
            filters={"subset": ("PASS",), "evaluation": ("confirmed_defect",)},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 0)
        self.assertEqual(result["view_status"], "empty_selection")

    def test_07_case_id_filter(self):
        result = view(
            fixture.adapter_report([accepted_case(), invalid_case()]),
            filters={"case_id": ("C10_missing_column",)},
        )
        self.assertEqual(result["selected_cases"][0]["case_id"],
                         "C10_missing_column")

    def test_08_evidence_index_five_fields_each(self):
        result = view(fixture.adapter_report([accepted_case()]))
        entries = result["evidence_index"]["unmeasured"]
        self.assertEqual(len(entries), len(views.SCENE_METRICS))
        self.assertEqual({x["metric"] for x in entries},
                         set(views.SCENE_METRICS))
        self.assertTrue(all(x["state"] == "documented_not_measured"
                            for x in entries))

    def test_09_metric_filter(self):
        result = view(
            fixture.adapter_report([accepted_case()]),
            filters={"missing_metric": ("cold_load_s",)},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 1)

    def test_10_state_filter_separates_known_and_unknown(self):
        mixed = view(
            fixture.qa_report([fixture.qa_case()]),
            fixture.adapter_report([accepted_case()]),
            filters={"missing_state": ("not_reported",)},
        )
        self.assertEqual(mixed["selection_summary"]["cases_selected"], 1)
        self.assertEqual(mixed["selected_cases"][0]["report_type"], "qa_r2")

    def test_11_missing_not_measured_key(self):
        row = accepted_case()
        change_analyzer_json(
            row, lambda doc: doc["not_measured"].pop("cold_load_s")
        )
        result = view(fixture.adapter_report([row]))
        entry = next(x for x in result["evidence_index"]["unmeasured"]
                     if x["metric"] == "cold_load_s")
        self.assertEqual(entry["state"], "unknown_evidence")
        self.assertEqual(result["status"], "inconclusive")

    def test_12_conflicting_missing_entry_is_not_a_measurement(self):
        row = accepted_case()
        change_analyzer_json(
            row, lambda doc: doc["not_measured"]["cold_load_s"].update(
                status="PASS", value=0
            )
        )
        result = view(fixture.adapter_report([row]))
        entry = next(x for x in result["evidence_index"]["unmeasured"]
                     if x["metric"] == "cold_load_s")
        self.assertEqual(entry["state"], "inconsistent")
        self.assertTrue(entry["never_implies_measurement_value"])

    def test_13_invalid_data_stays_separate(self):
        result = view(fixture.adapter_report([accepted_case(), invalid_case()]))
        self.assertEqual(result["selection_summary"]["counts"]["data_quality"],
                         {"invalid": 1, "valid": 1})
        problems = result["evidence_index"]["data_quality"]
        self.assertEqual(len(problems), 1)
        self.assertEqual(problems[0]["quality"], "invalid")

    def test_14_raw_diagnostic_detail_never_in_quality_index(self):
        row = invalid_case()
        change_analyzer_json(
            row, lambda doc: doc.update(
                errors=[{"code": "MISSING_COLUMNS",
                         "detail": "PRIVATE_PATH_NEVER_OUTPUT"}]
            )
        )
        result = view(fixture.adapter_report([row]))
        quality = result["evidence_index"]["data_quality"]
        self.assertEqual(quality[0]["error_codes"], ["MISSING_COLUMNS"])
        self.assertNotIn(
            "PRIVATE_PATH_NEVER_OUTPUT", json.dumps(quality)
        )

    def test_15_default_excludes_raw_evidence(self):
        result = view(fixture.adapter_report([accepted_case()]))
        self.assertFalse(result["privacy"]["raw_evidence_included"])
        self.assertNotIn("raw_case_evidence", result["selected_cases"][0])

    def test_16_raw_evidence_is_opt_in_only(self):
        result = view(
            fixture.adapter_report([accepted_case()]),
            include_evidence=True,
        )
        case = result["selected_cases"][0]
        self.assertTrue(result["privacy"]["raw_evidence_included"])
        self.assertIn("original_qa_evidence", case["raw_case_evidence"])

    def test_17_pointer_addresses_unsliced_source(self):
        result = view(
            fixture.adapter_report([accepted_case(), invalid_case()]),
            filters={"case_id": ("C10_missing_column",)},
        )
        case = result["selected_cases"][0]
        self.assertEqual(case["case_index"], 1)
        self.assertEqual(
            case["evidence_ref"]["case_pointer"],
            "/reports/0/cases/1/evidence",
        )

    def test_18_stdout_digest_recomputed_from_base64(self):
        row = accepted_case()
        result = view(fixture.adapter_report([row]))
        expected = hashlib.sha256(
            base64.b64decode(row["original_qa_evidence"]["stdout_base64"])
        ).hexdigest()
        self.assertEqual(
            result["selected_cases"][0]["evidence_fingerprints"]["stdout_sha256"],
            expected,
        )
        self.assertFalse(
            result["selected_cases"][0]["evidence_fingerprints"][
                "input_hash_verified_from_csv"
            ]
        )

    def test_19_duplicate_case_ids_across_reports_not_joined(self):
        result = view(
            fixture.adapter_report([accepted_case()]),
            fixture.adapter_report([accepted_case()]),
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 2)
        self.assertEqual(
            [x["report_index"] for x in result["selected_cases"]], [0, 1]
        )

    def test_20_defects_visible_despite_filtered_view(self):
        result = view(
            fixture.adapter_report([accepted_case(), wrong_pass_case()]),
            filters={"case_id": ("C01_baseline",)},
        )
        self.assertEqual(result["status"], "defects_found")
        self.assertEqual(result["source_summary"]["confirmed_defects"], 1)
        self.assertEqual(result["selection_summary"]["selected_confirmed_defects"], 0)

    def test_21_uncertainty_is_indexed(self):
        row = accepted_case()
        row["schema_issues"] = ["threshold_mismatch:frame_p50_ms"]
        result = view(fixture.adapter_report([row]))
        self.assertEqual(result["status"], "inconclusive")
        issues = result["evidence_index"]["uncertainty"][0]["reason_codes"]
        self.assertIn("schema:threshold_mismatch:frame_p50_ms", issues)

    def test_22_reason_filter_exact(self):
        row = accepted_case()
        row["schema_issues"] = ["threshold_mismatch:frame_p50_ms"]
        result = view(
            fixture.adapter_report([row]),
            filters={"reason": ("schema:threshold_mismatch:frame_p50_ms",)},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 1)

    def test_23_selection_empty_never_becomes_pass(self):
        result = view(
            fixture.adapter_report([accepted_case(), wrong_pass_case()]),
            filters={"case_id": ("C15_missing_cell",)},
        )
        self.assertEqual(result["view_status"], "empty_selection")
        self.assertEqual(result["status"], "defects_found")
        self.assertFalse(result["full_scene"]["full_scene_pass"])

    def test_24_skipped_cases_preserved(self):
        report = fixture.adapter_report([accepted_case()])
        report["cases_planned"] = 15
        result = view(report)
        self.assertEqual(result["status"], "inconclusive")
        self.assertEqual(
            result["source_summary"]["unexecuted_case_index"][0]["unexecuted"],
            14,
        )

    def test_25_input_alias_does_not_disclose_path(self):
        self.assertEqual(
            views._safe_basename(
                __import__("pathlib").Path("/secret/work/account.json"), 3
            ),
            "input_03",
        )

    def test_26_bad_json_stays_uncertain(self):
        row = accepted_case()
        orig = row["original_qa_evidence"]
        orig["stdout_base64"] = base64.b64encode(b"not-json").decode("ascii")
        orig["raw_stdout"] = "not-json"
        result = view(fixture.adapter_report([row]))
        self.assertEqual(result["status"], "inconclusive")
        self.assertEqual(
            result["evidence_index"]["unmeasured"][0]["state"],
            "unknown_evidence",
        )

    def test_27_data_quality_filter(self):
        result = view(
            fixture.adapter_report([accepted_case(), invalid_case()]),
            filters={"quality": ("invalid",)},
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 1)
        self.assertEqual(result["selected_cases"][0]["case_id"], "C10_missing_column")

    def test_28_selected_uncertain_never_claims_full_scene(self):
        row = accepted_case()
        row["schema_issues"] = ["inconsistent_input"]
        result = view(
            fixture.adapter_report([row]),
            filters={"evaluation": ("inconclusive",)},
        )
        self.assertEqual(result["selection_summary"]["selected_inconclusive_cases"], 1)
        self.assertEqual(result["full_scene"]["certification"], "NOT_ESTABLISHED")

    def test_29_missing_state_filter_is_and_with_metric(self):
        result = view(
            fixture.qa_report([fixture.qa_case()]),
            fixture.adapter_report([accepted_case()]),
            filters={
                "missing_metric": ("active_npcs_peak",),
                "missing_state": ("documented_not_measured",),
            },
        )
        self.assertEqual(result["selection_summary"]["cases_selected"], 1)
        self.assertEqual(result["selected_cases"][0]["report_type"], "schema_adapter_r1")

    def test_30_unrecognized_source_never_certifies(self):
        output = foundation.aggregate_documents([
            ("untrusted", {"task_id": "unknown", "version": "r100"})
        ])
        result = views.create_view(output, {})
        self.assertEqual(result["status"], "inconclusive")
        self.assertFalse(result["full_scene"]["full_scene_pass"])
        self.assertEqual(result["selection_summary"]["cases_selected"], 0)


if __name__ == "__main__":
    unittest.main()

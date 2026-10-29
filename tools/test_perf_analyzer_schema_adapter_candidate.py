#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GAME-WEB-TECHQA-ADAPTER-001/r1: pinned measured-subset schema candidate.

Derived from source inspection, NOT_RUN. Python 3.12 standard library.
No changes to the target analyzer or existing r2 QA tool.
Run only on trusted analyzer files. All inputs are synthetic.

Requires sibling test_perf_analyzer_contract_candidate.py from PR #5.
Uses that tool to invoke the analyzer exactly ONCE per case (max 15),
in independent temporary directories, 5-second timeout, no shell.
Keeps the original raw stdout/stderr, exit code and base64 evidence.
"""

import argparse
import base64
import json
import math
import sys
from pathlib import Path

import test_perf_analyzer_contract_candidate as qa

TASK_ID = "GAME-WEB-TECHQA-ADAPTER-001"
VERSION = "r1"
QA_HEAD = "413a9e9ded41bf7694ed5d1265c5932d3e6fa60a"
ANALYZER_HEAD = "cb0026ec668b96832efed5bf452a90548bc31c20"
ANALYZER_TASK = "GAME-WEB-PERF-002"
SCOPE = "CSV measured subset only"
METRICS = {
    "frame_p50_ms": ("frame_ms", "p50", 12.0),
    "frame_p95_ms": ("frame_ms", "p95", 16.7),
    "frame_p99_ms": ("frame_ms", "p99", 24.0),
    "script_p95_ms": ("script_ms", "p95", 2.0),
    "ram_peak_gib": ("ram_gib", "peak", 1.2),
    "vram_delta_peak_gib": ("vram_delta_gib", "peak", 1.0),
    "draw_calls_peak": ("draw_calls", "peak", 200),
    "triangles_peak": ("triangles", "peak", 150000),
}
UNMEASURED = {
    "cold_load_s",
    "scene_switch_s",
    "dynamic_lights_peak",
    "shadow_lights_peak",
    "active_npcs_peak",
}
BAD_INPUT_CASES = {
    "C10_missing_column", "C11_empty_table",
    "C12_nan", "C13_infinity",
    "C14_negative", "C15_missing_cell",
}


def number(value):
    return (type(value) in (int, float)
            and math.isfinite(value) and value >= 0)


def same(left, right):
    return (number(left) and number(right)
            and math.isclose(left, right, rel_tol=1e-9, abs_tol=1e-9))


def nearest_rank(values, fraction):
    ordered = sorted(values)
    return ordered[math.ceil(fraction * len(ordered)) - 1]


def expected_values(case):
    """Independent nearest-rank and peak calculation on synthetic rows."""
    rows = case["rows"]
    columns = case["columns"]

    def values(column):
        index = columns.index(column)
        return [float(row[index]) for row in rows]

    frame = values("frame_ms")
    script = values("script_ms")
    return {
        "frame_p50_ms": nearest_rank(frame, 0.50),
        "frame_p95_ms": nearest_rank(frame, 0.95),
        "frame_p99_ms": nearest_rank(frame, 0.99),
        "script_p95_ms": nearest_rank(script, 0.95),
        "ram_peak_gib": max(values("ram_gib")),
        "vram_delta_peak_gib": max(values("vram_delta_gib")),
        "draw_calls_peak": max(values("draw_calls")),
        "triangles_peak": max(values("triangles")),
    }


def inspect_schema(document, original, case):
    """Return (normalized, issues). Issues always mean INCONCLUSIVE.

    Verifies only the exact output contract read at ANALYZER_HEAD.
    No inference from process success to metrics or from subset to scene.
    """
    issues = []
    normalized = {
        "measured_subset_status": None,
        "full_scene_status": None,
        "full_scene_pass": None,
        "data_quality": "unknown",
        "error_count": None,
    }

    if not isinstance(document, dict):
        return normalized, ["root_not_object"]

    required = {
        "task_id", "version", "scope", "source", "sample_count",
        "stats", "checks", "not_measured", "measured_subset_status",
        "status", "full_scene_pass", "error_count", "errors",
    }
    missing = sorted(required - document.keys())
    if missing:
        return normalized, ["missing_fields:" + ",".join(missing)]

    if document["task_id"] != ANALYZER_TASK:
        issues.append("unexpected_task_id")
    if document["version"] != "r1":
        issues.append("unexpected_version")
    if document["scope"] != SCOPE:
        issues.append("unexpected_scope")
    if document["source"] != original["command"][-1]:
        issues.append("source_does_not_match_invocation")

    subset = document["measured_subset_status"]
    scene = document["status"]
    scene_pass = document["full_scene_pass"]
    normalized["measured_subset_status"] = subset
    normalized["full_scene_status"] = scene
    normalized["full_scene_pass"] = scene_pass

    if subset not in ("PASS", "FAIL", "INCOMPLETE"):
        issues.append("unknown_subset_status")
    if scene != "incomplete" or scene_pass is not False:
        issues.append("full_scene_contract_conflict")

    count = document["error_count"]
    rows_count = document["sample_count"]
    errors = document["errors"]
    normalized["error_count"] = count

    if type(count) is not int or count < 0:
        issues.append("invalid_error_count")
    if type(rows_count) is not int or rows_count < 0:
        issues.append("invalid_sample_count")
    else:
        expected_count = (0 if case["case_id"] in
                          {"C10_missing_column", "C11_empty_table"}
                          else len(case["rows"]))
        if rows_count != expected_count:
            issues.append("sample_count_mismatch")

    if not isinstance(errors, list):
        issues.append("errors_not_array")
    elif type(count) is int and count >= 0:
        if len(errors) != min(count, 20):
            issues.append("error_list_count_mismatch")
        for entry in errors:
            if (not isinstance(entry, dict)
                or not isinstance(entry.get("code"), str)
                or not isinstance(entry.get("detail"), str)):
                issues.append("malformed_error_entry")
                break

    stats = document["stats"]
    checks = document["checks"]
    if not isinstance(stats, dict) or not isinstance(checks, dict):
        return normalized, issues + ["stats_or_checks_not_object"]
    if set(checks) != set(METRICS):
        return normalized, issues + ["checks_keys_mismatch"]

    observed_statuses = []
    for name, (metric, field, upper) in METRICS.items():
        check = checks[name]
        stat = stats.get(metric)
        if (not isinstance(check, dict)
            or not isinstance(stat, dict)
            or field not in stat):
            issues.append("missing_check_or_stat:" + name)
            continue
        if not same(check.get("upper_inclusive"), upper):
            issues.append("threshold_mismatch:" + name)
        value = check.get("value")
        status = check.get("status")
        observed_statuses.append(status)
        if count == 0:
            if not same(value, stat[field]):
                issues.append("check_stat_conflict:" + name)
            if not number(value):
                issues.append("non_numeric_measurement:" + name)
            elif status != ("PASS" if value <= upper else "FAIL"):
                issues.append("check_threshold_conflict:" + name)
        else:
            if value is not None or stat[field] is not None:
                issues.append("invalid_input_has_measurement:" + name)
            if status != "INCOMPLETE":
                issues.append("invalid_input_has_verdict:" + name)

    not_measured = document["not_measured"]
    if not isinstance(not_measured, dict) or set(not_measured) != UNMEASURED:
        issues.append("not_measured_keys_mismatch")
    else:
        for key in UNMEASURED:
            item = not_measured[key]
            if (not isinstance(item, dict)
                or item.get("value") is not None
                or item.get("status") != "NOT_MEASURED"):
                issues.append("unmeasured_field_conflict:" + key)

    if type(count) is int and count >= 0:
        normalized["data_quality"] = (
            "invalid" if count > 0 else "valid"
        )
        if count > 0:
            if subset != "INCOMPLETE":
                issues.append("errors_vs_subset_conflict")
        elif len(observed_statuses) == len(METRICS):
            expected_subset = (
                "PASS" if all(s == "PASS" for s in observed_statuses)
                else "FAIL" if any(s == "FAIL" for s in observed_statuses)
                else None
            )
            if subset != expected_subset:
                issues.append("checks_vs_subset_conflict")

    return normalized, issues


def adapt_case(original, case):
    """Adapter analysis; does not alter or delete original QA evidence."""
    state = original["classification"]
    record = {
        "case_id": case["case_id"],
        "expected": ("invalid_input" if case["case_id"] in BAD_INPUT_CASES
                     else "baseline_subset_pass" if case["case_id"] ==
                     "C01_baseline" else "subset_fail"),
        "classification": "inconclusive",
        "defect": False,
        "measured_subset_status": None,
        "full_scene_status": None,
        "full_scene_pass": None,
        "data_quality": "unknown",
        "schema_issues": [],
        "notes": [],
        "original_qa_evidence": original,
    }
    if state == "contract_mismatch":
        record["classification"] = "contract_mismatch"
        record["notes"].append("No CLI retry or alternative flags")
        return record
    if state in ("timeout", "exception", "format_error"):
        record["classification"] = state
        record["defect"] = True
        return record

    # Restore the original stdout bytes, without relying on lossy text.
    try:
        stdout = base64.b64decode(
            original["stdout_base64"], validate=True
        )
        document, parse_error = qa.parse_json_output(stdout)
    except (ValueError, KeyError) as exc:
        record["schema_issues"].append("invalid_evidence:" + str(exc))
        return record

    if parse_error is not None:
        record["schema_issues"].append("json_unavailable:" + parse_error)
        return record

    normalized, issues = inspect_schema(document, original, case)
    record.update(normalized)
    record["schema_issues"] = issues
    if issues:
        record["classification"] = "inconclusive"
        return record

    subset = normalized["measured_subset_status"]
    count = normalized["error_count"]
    bad_input = case["case_id"] in BAD_INPUT_CASES
    baseline = case["case_id"] == "C01_baseline"

    if baseline:
        if subset == "PASS" and count == 0:
            if all(same(document["checks"][key]["value"], value)
                   for key, value in expected_values(case).items()):
                record["classification"] = "baseline_subset_pass"
            else:
                record["schema_issues"].append("baseline_metrics_mismatch")
        else:
            record["schema_issues"].append("baseline_not_subset_pass")
        return record

    # A recognized, internally consistent subset PASS on invalid or
    # over-budget synthetic input is an error, regardless of exit code.
    if subset == "PASS":
        record["classification"] = "wrong_subset_pass"
        record["defect"] = True
        if original["exit_code"] != 0:
            record["notes"].append("explicit_PASS_despite_nonzero_exit")
        return record

    if bad_input:
        if subset == "INCOMPLETE" and count > 0:
            if original["exit_code"] == 2:
                record["classification"] = "invalid_input_rejected"
            else:
                record["schema_issues"].append("invalid_input_exit_mismatch")
        else:
            record["schema_issues"].append("invalid_input_not_incomplete")
        return record

    # A valid but over-budget input must be reported FAIL with correct
    # nearest-rank and peak values; do not trust the process exit code.
    if subset == "FAIL" and count == 0:
        expected = expected_values(case)
        if all(same(document["checks"][key]["value"], value)
               for key, value in expected.items()):
            if original["exit_code"] == 1:
                record["classification"] = "subset_rejected"
            else:
                record["schema_issues"].append("subset_fail_exit_mismatch")
        else:
            record["schema_issues"].append("subset_measurement_mismatch")
    else:
        record["schema_issues"].append("overbudget_not_subset_fail")
    return record


def run_adapter(analyzer):
    cases = qa.build_cases()
    assert len(cases) <= qa.MAX_CASES
    results = []
    for case in cases:
        # The ONE AND ONLY invocation of the target for this case:
        raw_result = qa.evaluate_case(analyzer, case)
        adapted = adapt_case(raw_result, case)
        results.append(adapted)
        if adapted["classification"] == "contract_mismatch":
            break
        if case["case_id"] == "C01_baseline":
            if adapted["classification"] != "baseline_subset_pass":
                break

    labels = [r["classification"] for r in results]
    defects = [r["case_id"] for r in results if r["defect"]]
    if "contract_mismatch" in labels:
        status, code = "contract_mismatch", 2
    elif defects:
        status, code = "defects_found", 1
    elif len(results) != len(cases) or "inconclusive" in labels:
        status, code = "inconclusive", 4
    else:
        status, code = "no_definitive_subset_defects", 0

    return {
        "task_id": TASK_ID,
        "version": VERSION,
        "source_pins": {"qa_pr5_head": QA_HEAD,
                        "analyzer_pr2_head": ANALYZER_HEAD},
        "status": status,
        "exit_code": code,
        "scope": "measured CSV subset only",
        "full_scene_status": "incomplete",
        "full_scene_pass": False,
        "full_scene_certified": False,
        "synthetic_data": True,
        "actual_performance_measurement": False,
        "target_source_modified": False,
        "cases_planned": len(cases),
        "cases_executed": len(results),
        "defect_cases": defects,
        "results": results,
        "limitations": [
            "Only the pinned analyzer r1 JSON schema is recognized",
            "Unknown or internally inconsistent output is inconclusive",
            "No PASS for a full scene, even if subset metrics PASS",
            "Runtime results must be supplied by Codex; development NOT_RUN",
            "Imports existing PR5 r2 runner; branch is stacked on PR5",
            "Does not sandbox network or child processes of a target",
        ],
    }, code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analyzer", required=True, type=Path)
    args = parser.parse_args()
    analyzer = args.analyzer.expanduser().resolve()
    if not analyzer.is_file():
        report = {
            "task_id": TASK_ID,
            "version": VERSION,
            "status": "contract_mismatch",
            "exit_code": 2,
            "detail": "Analyzer path is not a regular file",
            "cases_executed": 0,
            "synthetic_data": True,
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 2
    report, code = run_adapter(analyzer)
    print(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False))
    return code


if __name__ == "__main__":
    sys.exit(main())

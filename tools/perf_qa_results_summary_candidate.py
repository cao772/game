#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GAME-WEB-MODULE-TECHQA-001/r1: offline QA results summarizer.

Read-only aggregation of JSON reports from pinned PR #5 and PR #7.
Does NOT import or execute the analyzer, QA runner, or schema adapter.
No network, shell, subprocess, shared interface, or scene mutation.

DEVELOPMENT_VALIDATION = NOT_RUN (see companion documentation).
"""
from __future__ import annotations

import argparse
import base64
import binascii
from collections import Counter
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

TASK_ID = "GAME-WEB-MODULE-TECHQA-001"
VERSION = "r1"
DEVELOPMENT_VALIDATION = "NOT_RUN"
QA_TASK = "GAME-WEB-TECHQA-001"
ADAPTER_TASK = "GAME-WEB-TECHQA-ADAPTER-001"
PR5_HEAD = "413a9e9ded41bf7694ed5d1265c5932d3e6fa60a"
PR7_HEAD = "482802ce44e2b14d5461969a7fb58d48c9bd8615"
ANALYZER_HEAD = "cb0026ec668b96832efed5bf452a90548bc31c20"
MAX_REPORTS = 32
MAX_FILE_BYTES = 16 * 1024 * 1024
MAX_CASES = 15
CASE_IDS = (
    "C01_baseline", "C02_frame_p50", "C03_frame_p95", "C04_frame_p99",
    "C05_script_p95", "C06_ram", "C07_vram", "C08_draw_calls",
    "C09_triangles", "C10_missing_column", "C11_empty_table",
    "C12_nan", "C13_infinity", "C14_negative", "C15_missing_cell",
)
INVALID_INPUTS = set(CASE_IDS[9:])
MEASURED_METRICS = (
    "frame_p50_ms", "frame_p95_ms", "frame_p99_ms", "script_p95_ms",
    "ram_peak_gib", "vram_delta_peak_gib", "draw_calls_peak",
    "triangles_peak",
)
SCENE_GAPS = (
    "cold_load_s", "scene_switch_s", "dynamic_lights_peak",
    "shadow_lights_peak", "active_npcs_peak",
)
QA_CLASSES = {
    "baseline_pass", "baseline_unexpected_fail", "wrong_pass", "rejected",
    "schema_unrecognized", "inconclusive", "format_error", "exception",
    "timeout", "contract_mismatch",
}
ADAPTER_CLASSES = {
    "baseline_subset_pass", "subset_rejected", "invalid_input_rejected",
    "wrong_subset_pass", "inconclusive", "timeout", "exception",
    "format_error", "contract_mismatch",
}
DEFECT_CLASSES = {"wrong_pass", "wrong_subset_pass", "timeout",
                  "exception", "format_error"}
UNCERTAIN_CLASSES = {"inconclusive", "schema_unrecognized",
                     "baseline_unexpected_fail", "contract_mismatch"}
SUCCESS_CLASSES = {"baseline_pass", "rejected", "baseline_subset_pass",
                   "subset_rejected", "invalid_input_rejected"}
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")


class ReportInputError(ValueError):
    """Malformed, incompatible, or unsafe-to-trust report input."""


def _no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for name, value in pairs:
        if name in result:
            raise ReportInputError("duplicate_json_key:" + name)
        result[name] = value
    return result


def _reject_constant(value: str) -> None:
    raise ReportInputError("non_finite_json_constant:" + value)


def strict_json(raw: bytes) -> Any:
    return json.loads(
        raw.decode("utf-8"),
        object_pairs_hook=_no_duplicate_keys,
        parse_constant=_reject_constant,
    )


def read_report(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise ReportInputError("report_not_regular_file")
    if path.stat().st_size > MAX_FILE_BYTES:
        raise ReportInputError("report_exceeds_16_MiB")
    with path.open("rb") as stream:
        content = stream.read(MAX_FILE_BYTES + 1)
    if len(content) > MAX_FILE_BYTES:
        raise ReportInputError("report_exceeds_16_MiB")
    document = strict_json(content)
    if not isinstance(document, dict):
        raise ReportInputError("report_root_not_object")
    return document


def _integer(value: Any) -> bool:
    return type(value) is int and value >= 0


def _append(issues: list[str], code: str) -> None:
    if code not in issues:
        issues.append(code)


def _same_evidence(original: Any) -> tuple[list[str], dict[str, Any]]:
    """Validate r2's raw / base64 evidence, without executing anything.

    A SHA256 input field is only syntax-checked: original CSV bytes were
    not included in these reports, so input hash cannot be recomputed.
    """
    issues: list[str] = []
    details: dict[str, Any] = {
        "raw_evidence_integrity": "unverified",
        "input_sha256_validation": "format_only",
    }
    if not isinstance(original, dict):
        return ["missing_original_qa_evidence"], details

    decoded: dict[str, bytes] = {}
    for stream in ("stdout", "stderr"):
        encoded = original.get(stream + "_base64")
        text = original.get("raw_" + stream)
        if not isinstance(encoded, str) or not isinstance(text, str):
            _append(issues, "missing_raw_" + stream)
            continue
        try:
            actual = base64.b64decode(encoded, validate=True)
        except (ValueError, binascii.Error):
            _append(issues, "invalid_" + stream + "_base64")
            continue
        if actual.decode("utf-8", errors="replace") != text:
            _append(issues, "raw_" + stream + "_mismatch")
        decoded[stream] = actual

    digest = original.get("input_sha256")
    if not isinstance(digest, str) or HEX_SHA256.fullmatch(digest) is None:
        _append(issues, "invalid_input_sha256_format")
    if type(original.get("timed_out")) is not bool:
        _append(issues, "missing_timeout_flag")
    exit_code = original.get("exit_code")
    if exit_code is not None and type(exit_code) is not int:
        _append(issues, "invalid_exit_code")
    if original.get("timed_out") is False and exit_code is None:
        # An invocation failure (contract mismatch) is permitted without
        # an exit code. Other classifications must have an exit code.
        if original.get("classification") != "contract_mismatch":
            _append(issues, "missing_exit_code")
    if original.get("synthetic") is not True:
        _append(issues, "unconfirmed_synthetic_case")
    command = original.get("command")
    if not isinstance(command, list) or not all(
        isinstance(item, str) for item in command
    ) or len(command) != 3:
        _append(issues, "unexpected_invocation_shape")
    if "stdout" in decoded and "stderr" in decoded and not issues:
        details["raw_evidence_integrity"] = "verified_against_base64"
    return issues, details


def _extract_analyzer_claim(original: dict[str, Any]) -> tuple[Any, list[str]]:
    """Parse real stdout without assigning semantics to unknown fields."""
    if not isinstance(original.get("stdout_base64"), str):
        return None, ["stdout_unavailable"]
    try:
        raw = base64.b64decode(
            original["stdout_base64"], validate=True
        )
        doc = strict_json(raw)
    except (UnicodeError, ValueError, binascii.Error) as exc:
        return None, ["stdout_not_parseable_json:" + type(exc).__name__]
    if not isinstance(doc, dict):
        return None, ["stdout_json_not_object"]
    return doc, []


def _coverage_from_document(doc: Any) -> tuple[list[str], list[str]]:
    if not isinstance(doc, dict):
        return [], ["coverage_unknown"]
    unmeasured = doc.get("not_measured")
    if not isinstance(unmeasured, dict):
        return [], ["not_measured_unavailable"]
    if set(unmeasured) != set(SCENE_GAPS):
        return [], ["not_measured_keys_unknown"]
    for key in SCENE_GAPS:
        item = unmeasured[key]
        if (not isinstance(item, dict)
                or item.get("value") is not None
                or item.get("status") != "NOT_MEASURED"):
            return [], ["not_measured_semantics_conflict"]
    return list(SCENE_GAPS), []


def _evaluate_case(source_type: str, case: Any) -> dict[str, Any]:
    issues: list[str] = []
    if not isinstance(case, dict):
        return {
            "case_id": None, "classification": "unrecognized",
            "evaluation": "inconclusive", "issues": ["case_not_object"],
            "evidence": case, "confirmed_defect": False,
            "measured_subset": "not_assessed",
            "scene": "not_certified", "data_quality": "unknown",
            "unmeasured_fields": [],
        }

    case_id = case.get("case_id")
    classification = case.get("classification")
    expected_classes = QA_CLASSES if source_type == "qa_r2" else ADAPTER_CLASSES
    if case_id not in CASE_IDS:
        _append(issues, "unknown_case_id")
    if classification not in expected_classes:
        _append(issues, "unknown_case_classification")
    if type(case.get("defect")) is not bool:
        _append(issues, "defect_flag_not_boolean")
    else:
        if case["defect"] != (classification in DEFECT_CLASSES):
            _append(issues, "defect_flag_vs_classification_conflict")

    original = case if source_type == "qa_r2" else case.get(
        "original_qa_evidence"
    )
    evidence_issues, integrity = _same_evidence(original)
    issues.extend(evidence_issues)
    if isinstance(original, dict):
        if original.get("case_id") != case_id:
            _append(issues, "nested_case_id_mismatch")
        if source_type == "qa_r2":
            if original.get("classification") != classification:
                _append(issues, "original_classification_mismatch")

    subset = "not_assessed"
    data_quality = "unknown"
    unmeasured_fields: list[str] = []
    scene = "not_certified"
    raw_claim = None

    if source_type == "schema_adapter_r1":
        reported_subset = case.get("measured_subset_status")
        reported_scene = case.get("full_scene_status")
        reported_pass = case.get("full_scene_pass")
        reported_quality = case.get("data_quality")
        subset = (reported_subset if reported_subset in
                  ("PASS", "FAIL", "INCOMPLETE") else "unknown")
        data_quality = (reported_quality if reported_quality in
                        ("valid", "invalid", "unknown") else "unknown")
        if (reported_scene not in (None, "incomplete")
                or reported_pass not in (None, False)):
            _append(issues, "scene_claim_conflict")
        if classification in SUCCESS_CLASSES or classification == "wrong_subset_pass":
            if (reported_scene != "incomplete"
                    or reported_pass is not False):
                _append(issues, "missing_full_scene_incomplete_claim")

        if not isinstance(case.get("schema_issues"), list):
            _append(issues, "schema_issues_not_list")
        elif case["schema_issues"]:
            _append(issues, "reported_schema_issues")
        if classification == "inconclusive" and not case.get("schema_issues"):
            _append(issues, "inconclusive_without_detail")
        if (classification in ("baseline_subset_pass", "subset_rejected")
                and data_quality != "valid"):
            _append(issues, "successful_subset_with_unknown_data_quality")
        if (classification == "invalid_input_rejected"
                and data_quality != "invalid"):
            _append(issues, "invalid_input_quality_conflict")

        if isinstance(original, dict) and not original.get("timed_out"):
            raw_claim, parse_issues = _extract_analyzer_claim(original)
            # Contract mismatch/format errors are allowed to have non-JSON.
            if classification in SUCCESS_CLASSES | {"wrong_subset_pass"}:
                issues.extend(parse_issues)
            if isinstance(raw_claim, dict):
                if raw_claim.get("measured_subset_status") != reported_subset:
                    _append(issues, "subset_claim_vs_stdout_conflict")
                if (raw_claim.get("status") != reported_scene
                        or raw_claim.get("full_scene_pass") is not reported_pass):
                    _append(issues, "scene_claim_vs_stdout_conflict")
                count = raw_claim.get("error_count")
                if not _integer(count):
                    _append(issues, "invalid_stdout_error_count")
                elif reported_quality in ("valid", "invalid"):
                    expected_quality = "valid" if count == 0 else "invalid"
                    if expected_quality != reported_quality:
                        _append(issues, "data_quality_vs_stdout_conflict")
                unmeasured_fields, coverage_issues = _coverage_from_document(
                    raw_claim
                )
                if classification in SUCCESS_CLASSES | {"wrong_subset_pass"}:
                    issues.extend(coverage_issues)
                checks = raw_claim.get("checks")
                if (classification in SUCCESS_CLASSES | {"wrong_subset_pass"}
                        and (not isinstance(checks, dict)
                             or set(checks) != set(MEASURED_METRICS))):
                    _append(issues, "measured_check_fields_unrecognized")
                if (classification == "wrong_subset_pass"
                        and reported_subset != "PASS"):
                    _append(issues, "wrong_subset_pass_without_explicit_pass")
        if classification == "baseline_subset_pass" and case_id != "C01_baseline":
            _append(issues, "baseline_class_on_adversarial_case")
        if classification == "subset_rejected" and case_id in INVALID_INPUTS | {
            "C01_baseline"
        }:
            _append(issues, "subset_rejected_case_mismatch")
        if (classification == "invalid_input_rejected"
                and case_id not in INVALID_INPUTS):
            _append(issues, "invalid_rejection_case_mismatch")
        if classification == "wrong_subset_pass" and case_id == "C01_baseline":
            _append(issues, "wrong_pass_on_valid_baseline")
    else:
        if classification == "baseline_pass" and case_id != "C01_baseline":
            _append(issues, "qa_baseline_case_mismatch")
        if classification == "wrong_pass" and case_id == "C01_baseline":
            _append(issues, "qa_wrong_pass_on_baseline")
        if classification == "wrong_pass" and case.get("verdict") is not True:
            _append(issues, "wrong_pass_without_explicit_verdict")
        # The r2 "overall" verdict is a QA classification, not the
        # measured-subset schema or a full-scene certification.

    if issues:
        evaluation = "inconclusive"
    elif classification in DEFECT_CLASSES:
        evaluation = "confirmed_defect"
    elif classification in SUCCESS_CLASSES:
        evaluation = "observed_expected_behavior"
    else:
        evaluation = "inconclusive"

    return {
        "case_id": case_id,
        "classification": classification,
        "evaluation": evaluation,
        "confirmed_defect": evaluation == "confirmed_defect",
        "issues": sorted(set(issues)),
        "measured_subset": subset,
        "scene": scene,
        "data_quality": data_quality,
        "unmeasured_fields": unmeasured_fields,
        "evidence_integrity": integrity,
        # Retain original stdout, stderr, exit, base64 and all metadata.
        # Never collapse embedded r2 evidence from the adapter.
        "evidence": case,
    }


def _validate_report(document: Any, origin: str) -> dict[str, Any]:
    issues: list[str] = []
    if not isinstance(document, dict):
        return {"source": origin, "status": "inconclusive",
                "issues": ["root_not_object"], "cases": []}

    task = document.get("task_id")
    if task == QA_TASK and document.get("version") == "r2":
        source_type = "qa_r2"
    elif task == ADAPTER_TASK and document.get("version") == "r1":
        source_type = "schema_adapter_r1"
    else:
        return {
            "source": origin, "status": "inconclusive",
            "issues": ["unrecognized_report_task_or_version"],
            "reported_task": task, "reported_version": document.get("version"),
            "cases": [], "raw_report": document,
        }

    if document.get("synthetic_data") is not True:
        _append(issues, "synthetic_provenance_not_confirmed")
    if document.get("actual_performance_measurement") is not False:
        _append(issues, "actual_performance_claim_conflict")
    if document.get("target_source_modified") is not False:
        _append(issues, "target_mutation_claim_conflict")

    if source_type == "qa_r2":
        if document.get("full_scene_performance_certified") is not False:
            _append(issues, "full_scene_certification_claim_conflict")
    else:
        pins = document.get("source_pins")
        if not isinstance(pins, dict) or (
            pins.get("qa_pr5_head") != PR5_HEAD
            or pins.get("analyzer_pr2_head") != ANALYZER_HEAD
        ):
            _append(issues, "source_pin_mismatch")
        if (document.get("full_scene_status") != "incomplete"
                or document.get("full_scene_pass") is not False
                or document.get("full_scene_certified") is not False):
            _append(issues, "full_scene_summary_conflict")

    raw_cases = document.get("results")
    if not isinstance(raw_cases, list):
        _append(issues, "results_not_array")
        raw_cases = []
    if not (1 <= len(raw_cases) <= MAX_CASES):
        _append(issues, "case_count_out_of_range")
    planned = document.get("cases_planned")
    executed = document.get("cases_executed")
    if not _integer(planned) or not (1 <= planned <= MAX_CASES):
        _append(issues, "invalid_cases_planned")
    if not _integer(executed) or executed != len(raw_cases):
        _append(issues, "cases_executed_mismatch")
    if _integer(planned) and len(raw_cases) > planned:
        _append(issues, "more_cases_than_planned")

    ids = [c.get("case_id") if isinstance(c, dict) else None
           for c in raw_cases]
    if len(set(str(x) for x in ids)) != len(ids):
        _append(issues, "duplicate_case_id")
    if ids and ids[0] != "C01_baseline":
        _append(issues, "baseline_not_first")

    cases = [_evaluate_case(source_type, item) for item in raw_cases]
    confirmed = [c["case_id"] for c in cases if c["confirmed_defect"]]
    uncertain = [c["case_id"] for c in cases
                 if c["evaluation"] == "inconclusive"]
    declared = document.get("defect_cases")
    declared_flags = [
        c.get("case_id") for c in raw_cases
        if isinstance(c, dict) and c.get("defect") is True
    ]
    if (not isinstance(declared, list)
            or declared != declared_flags):
        _append(issues, "defect_case_index_mismatch")

    reported_status = document.get("status")
    reported_exit = document.get("exit_code")
    allowed_statuses = (
        {"defects_found", "contract_mismatch", "schema_unrecognized",
         "inconclusive", "no_definitive_defects"}
        if source_type == "qa_r2" else
        {"defects_found", "contract_mismatch", "inconclusive",
         "no_definitive_subset_defects"}
    )
    if reported_status not in allowed_statuses:
        _append(issues, "unknown_report_status")
    if type(reported_exit) is not int or reported_exit not in (0, 1, 2, 4):
        _append(issues, "unknown_report_exit_code")
    expected_exit = {
        "defects_found": 1, "contract_mismatch": 2,
        "schema_unrecognized": 4, "inconclusive": 4,
        "no_definitive_defects": 0, "no_definitive_subset_defects": 0,
    }
    if reported_status in expected_exit and reported_exit != expected_exit[reported_status]:
        _append(issues, "report_status_exit_conflict")
    if declared_flags and reported_status not in (
        "defects_found", "contract_mismatch"
    ):
        _append(issues, "report_omits_declared_defects")

    # Do not mask gaps by treating nonexecution as success.
    skipped_count = planned - len(raw_cases) if _integer(planned) else None
    if skipped_count is not None and skipped_count < 0:
        skipped_count = None
    if (source_type == "qa_r2"
            and isinstance(document.get("cases_skipped"), list)
            and len(document["cases_skipped"]) != skipped_count):
        _append(issues, "skipped_case_count_mismatch")

    count = Counter(c["evaluation"] for c in cases)
    quality = Counter(c["data_quality"] for c in cases)
    subset = Counter(c["measured_subset"] for c in cases)
    if issues:
        status = "inconclusive"
    elif confirmed:
        status = "defects_found"
    elif uncertain or (skipped_count is None or skipped_count > 0):
        status = "inconclusive"
    else:
        status = "no_definitive_qa_defects"

    return {
        "source": origin,
        "type": source_type,
        "reported_status": reported_status,
        "status": status,
        "issues": issues,
        "cases_planned": planned,
        "cases_executed": len(raw_cases),
        "cases_skipped_count": skipped_count,
        "confirmed_defect_cases": confirmed,
        "inconclusive_cases": uncertain,
        "evaluation_counts": dict(count),
        "subset_counts": dict(subset),
        "data_quality_counts": dict(quality),
        "full_scene_certified": False,
        "cases": cases,
        "raw_report_metadata": {
            "task_id": task, "version": document.get("version"),
            "status": reported_status, "exit_code": reported_exit,
            "source_pins": document.get("source_pins"),
        },
    }


def aggregate_documents(sources: list[tuple[str, Any]]) -> dict[str, Any]:
    """Pure helper for future acceptance cases; never invokes the target."""
    reports = [_validate_report(document, name)
               for name, document in sources]
    number_of_cases = sum(len(item["cases"]) for item in reports)
    number_of_defects = sum(
        len(item.get("confirmed_defect_cases", [])) for item in reports
    )
    number_of_uncertain = sum(
        len(item.get("inconclusive_cases", [])) for item in reports
    )
    number_of_issues = sum(len(item.get("issues", [])) for item in reports)

    if not reports or number_of_issues:
        status = "inconclusive"
    elif number_of_defects:
        status = "defects_found"
    elif any(item["status"] == "inconclusive" for item in reports):
        status = "inconclusive"
    else:
        status = "no_definitive_qa_defects"

    # Defects do not disappear when some other input is uncertain.
    # Keep a separate confirmed-defect count regardless of status.
    return {
        "task_id": TASK_ID,
        "version": VERSION,
        "status": status,
        "exit_code": 1 if number_of_defects and not number_of_issues
                     else 4 if status == "inconclusive"
                     else 0,
        "development_validation": DEVELOPMENT_VALIDATION,
        "reports_received": len(reports),
        "report_units_are_independent": True,
        "cases_observed_across_reports": number_of_cases,
        "confirmed_defects_across_reports": number_of_defects,
        "inconclusive_cases_across_reports": number_of_uncertain,
        "report_level_issues": number_of_issues,
        "measured_subset_scope_only": True,
        "actual_performance_measurement": False,
        "full_scene_status": "not_certified",
        "full_scene_pass": False,
        "scene_acceptance": "NOT_ESTABLISHED",
        "synthetic_data": True,
        "reports": reports,
        "limitations": [
            "Aggregates synthetic black-box QA reports, not game FPS measurements",
            "Every report is a separate run; same case IDs are not deduplicated across runs",
            "r2 generic verdicts do not establish measured-subset status",
            "Only adapter r1 reports supply measured-subset and scene coverage",
            "Raw/base64 evidence is preserved; CSV SHA256 can only be syntax-checked",
            "Unknown/contradictory/missing evidence remains inconclusive",
            "A full scene cannot be certified by either pinned source",
            "This program never launches the analyzer or QA runner",
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report", type=Path, required=True, action="append",
        help="Input JSON from PR5 r2 or PR7 r1 (repeatable, up to 32)",
    )
    parser.add_argument(
        "--output", type=Path,
        help="Optional new JSON output file; refuses to overwrite",
    )
    args = parser.parse_args(argv)
    if len(args.report) > MAX_REPORTS:
        parser.error("too_many_reports_maximum_32")

    sources: list[tuple[str, Any]] = []
    for path in args.report:
        label = str(path)
        try:
            sources.append((label, read_report(path)))
        except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
            sources.append((label, {
                "task_id": "unreadable", "version": None,
                "input_error": type(exc).__name__ + ": " + str(exc),
            }))

    output = aggregate_documents(sources)
    # Keep failures explicit without leaking arbitrary report contents.
    for item, (_, source) in zip(output["reports"], sources):
        if isinstance(source, dict) and "input_error" in source:
            item["issues"].append("input_error:" + source["input_error"])

    serialized = json.dumps(
        output, ensure_ascii=False, allow_nan=False, indent=2
    ) + "\n"
    if args.output is not None:
        try:
            with args.output.open("x", encoding="utf-8") as stream:
                stream.write(serialized)
        except OSError as exc:
            print("output_error:" + str(exc), file=sys.stderr)
            return 2
    else:
        sys.stdout.write(serialized)
    return output["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())

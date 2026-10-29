#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GAME-WEB-MODULE-TECHQA-002/r1: offline report views and missing-evidence index.

Read-only view over GAME-WEB-MODULE-TECHQA-001/r1 report aggregation.
Does not execute the analyzer, QA tools, tests or any network call.
Source reports and raw case evidence are not modified.
Development/validation status: NOT_RUN.
"""
from __future__ import annotations

import argparse
import base64
import binascii
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

import perf_qa_results_summary_candidate as foundation

TASK_ID = "GAME-WEB-MODULE-TECHQA-002"
VERSION = "r1"
VALIDATION = "NOT_RUN"
MAX_REPORTS = foundation.MAX_REPORTS
SCENE_METRICS = tuple(foundation.SCENE_GAPS)
REPORT_TYPES = ("qa_r2", "schema_adapter_r1")
CASE_EVALUATIONS = (
    "confirmed_defect", "inconclusive", "observed_expected_behavior",
)
SUBSET_STATUSES = ("PASS", "FAIL", "INCOMPLETE", "unknown", "not_assessed")
QUALITY_STATUSES = ("valid", "invalid", "unknown")
MISSING_STATES = (
    "documented_not_measured", "not_reported",
    "inconsistent", "unknown_evidence",
)


def _unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def _counter(items: list[str]) -> dict[str, int]:
    return dict(sorted(Counter(items).items()))


def _safe_basename(path: Path, number: int) -> str:
    """Stable aliases without embedding private file names in output."""
    return f"input_{number:02d}"


def _document_from_original(case: dict[str, Any]) -> tuple[dict[str, Any] | None, list[str]]:
    evidence = case.get("evidence")
    if not isinstance(evidence, dict):
        return None, ["original_case_missing"]
    raw = evidence.get("original_qa_evidence", evidence)
    if not isinstance(raw, dict):
        return None, ["original_runner_evidence_missing"]
    encoded = raw.get("stdout_base64")
    if not isinstance(encoded, str):
        return None, ["stdout_base64_missing"]
    try:
        stdout = base64.b64decode(encoded, validate=True)
        document = foundation.strict_json(stdout)
    except (ValueError, UnicodeError, binascii.Error):
        return None, ["stdout_not_parseable"]
    if not isinstance(document, dict):
        return None, ["stdout_root_not_object"]
    return document, []


def _original_evidence(case: dict[str, Any]) -> dict[str, Any]:
    nested = case.get("evidence")
    if not isinstance(nested, dict):
        return {}
    origin = nested.get("original_qa_evidence", nested)
    return origin if isinstance(origin, dict) else {}


def _evidence_ref(report_index: int, case_index: int, adapter: bool) -> dict[str, str]:
    case_pointer = f"/reports/{report_index}/cases/{case_index}/evidence"
    original_pointer = (
        case_pointer + "/original_qa_evidence"
        if adapter else case_pointer
    )
    return {
        "case_pointer": case_pointer,
        "raw_stdout_pointer": original_pointer + "/raw_stdout",
        "raw_stderr_pointer": original_pointer + "/raw_stderr",
        "stdout_base64_pointer": original_pointer + "/stdout_base64",
        "stderr_base64_pointer": original_pointer + "/stderr_base64",
        "exit_code_pointer": original_pointer + "/exit_code",
        "input_sha256_pointer": original_pointer + "/input_sha256",
    }


def _hash_stdout(raw: dict[str, Any]) -> str | None:
    encoded = raw.get("stdout_base64")
    if not isinstance(encoded, str):
        return None
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        return None
    return hashlib.sha256(decoded).hexdigest()


def _confidence(case: dict[str, Any], report: dict[str, Any]) -> str:
    evidence = case.get("evidence_integrity")
    if not isinstance(evidence, dict):
        return "unverified"
    if (report.get("issues")
            or case.get("issues")
            or case.get("evaluation") == "inconclusive"):
        return "unverified"
    if evidence.get("raw_evidence_integrity") != "verified_against_base64":
        return "unverified"
    return "internally_consistent_only"


def _source_reasons(case: dict[str, Any], report: dict[str, Any]) -> list[str]:
    reasons = []
    for item in case.get("issues", []):
        if isinstance(item, str):
            reasons.append(item)
    for item in report.get("issues", []):
        if isinstance(item, str):
            reasons.append("report:" + item)
    evidence = case.get("evidence")
    if isinstance(evidence, dict):
        for item in evidence.get("schema_issues", []):
            if isinstance(item, str):
                reasons.append("schema:" + item)
    if case.get("evaluation") == "inconclusive" and not reasons:
        reasons.append("unresolved_without_reason")
    return _unique(reasons)


def _missing_metrics(
    source_type: str, document: dict[str, Any] | None
) -> list[dict[str, str]]:
    """Report claims, not inferred game measurements.

    Only adapter-r1's analyzer JSON may document NOT_MEASURED.
    PR5 generic QA reports do not establish scene coverage.
    """
    results = []
    not_measured = (
        document.get("not_measured")
        if isinstance(document, dict) and source_type == "schema_adapter_r1"
        else None
    )
    for metric in SCENE_METRICS:
        state = "not_reported"
        explanation = "no_verified_coverage_evidence"
        if source_type == "qa_r2":
            explanation = "generic_qa_does_not_report_scene_coverage"
        elif not isinstance(not_measured, dict):
            state = "unknown_evidence"
            explanation = "missing_not_measured_object"
        elif metric not in not_measured:
            state = "unknown_evidence"
            explanation = "missing_metric_entry"
        else:
            item = not_measured[metric]
            if (isinstance(item, dict)
                    and item.get("status") == "NOT_MEASURED"
                    and item.get("value") is None):
                state = "documented_not_measured"
                explanation = "analyzer_explicit_not_measured_null"
            else:
                state = "inconsistent"
                explanation = "metric_entry_contradicts_not_measured"
        results.append({
            "metric": metric, "state": state, "reason": explanation,
        })
    return results


def _data_quality_signal(
    source_type: str, case: dict[str, Any], doc: dict[str, Any] | None,
) -> dict[str, Any]:
    quality = case.get("data_quality", "unknown")
    if quality not in QUALITY_STATUSES:
        quality = "unknown"
    if source_type == "qa_r2":
        return {
            "status": "unknown", "error_count": None,
            "error_codes": [], "reason": "generic_qa_has_no_data_quality_contract",
        }
    if not isinstance(doc, dict):
        return {
            "status": "unknown", "error_count": None,
            "error_codes": [], "reason": "analyzer_json_unavailable",
        }
    error_count = doc.get("error_count")
    if type(error_count) is not int or error_count < 0:
        return {
            "status": "unknown", "error_count": None,
            "error_codes": [], "reason": "error_count_unrecognized",
        }
    errors = doc.get("errors")
    codes = []
    if isinstance(errors, list):
        for item in errors:
            if isinstance(item, dict) and isinstance(item.get("code"), str):
                codes.append(item["code"])
    return {
        "status": quality, "error_count": error_count,
        "error_codes": _unique(codes),
        "reason": "reported_by_schema_adapter_r1",
    }


def _build_case(
    report: dict[str, Any], case: dict[str, Any],
    report_index: int, case_index: int, include_evidence: bool,
) -> dict[str, Any]:
    source_type = report.get("type")
    adapter = source_type == "schema_adapter_r1"
    original = _original_evidence(case)
    document, parse_issues = _document_from_original(case)
    refs = _evidence_ref(report_index, case_index, adapter)
    confidence = _confidence(case, report)
    reasons = _source_reasons(case, report)
    quality = _data_quality_signal(source_type, case, document)
    metrics = _missing_metrics(source_type, document)
    if parse_issues:
        reasons = _unique(reasons + ["evidence:" + x for x in parse_issues])
    item = {
        "report_index": report_index,
        "report_alias": f"input_{report_index + 1:02d}",
        "report_type": source_type,
        "case_index": case_index,
        "case_id": case.get("case_id"),
        "classification": case.get("classification"),
        "evaluation": case.get("evaluation"),
        "confirmed_defect": case.get("confirmed_defect") is True,
        "measured_subset_status": case.get("measured_subset", "not_assessed"),
        "full_scene_status": "not_certified",
        "full_scene_pass": False,
        "data_quality": quality,
        "missing_metrics": metrics,
        "reason_codes": reasons,
        "evidence_integrity": confidence,
        "evidence_ref": refs,
        "evidence_fingerprints": {
            "stdout_sha256": _hash_stdout(original),
            "input_sha256_claim": original.get("input_sha256"),
            "input_hash_verified_from_csv": False,
        },
        "raw_evidence_included": include_evidence,
    }
    if include_evidence:
        # The original source may contain private stdout/stderr. This
        # explicit opt-in is never the default.
        item["raw_case_evidence"] = case.get("evidence")
    return item


def _matches(item: dict[str, Any], report: dict[str, Any],
             filters: dict[str, tuple[str, ...]]) -> bool:
    mapping = (
        ("evaluation", "evaluation"),
        ("subset", "measured_subset_status"),
        ("quality", None),
        ("classification", "classification"),
        ("case_id", "case_id"),
        ("report_type", "report_type"),
    )
    for filter_key, field in mapping:
        wanted = filters.get(filter_key, ())
        if not wanted:
            continue
        observed = (
            item["data_quality"]["status"]
            if filter_key == "quality" else item.get(field)
        )
        if observed not in wanted:
            return False
    reasons = filters.get("reason", ())
    if reasons and not any(x in item["reason_codes"] for x in reasons):
        return False
    metrics = filters.get("missing_metric", ())
    states = filters.get("missing_state", ())
    if metrics or states:
        matching = [
            m for m in item["missing_metrics"]
            if (not metrics or m["metric"] in metrics)
            and (not states or m["state"] in states)
        ]
        if not matching:
            return False
    return True


def _as_options(args: argparse.Namespace) -> dict[str, tuple[str, ...]]:
    names = (
        "evaluation", "subset", "quality", "classification", "case_id",
        "report_type", "reason", "missing_metric", "missing_state",
    )
    return {
        name: tuple(_unique(getattr(args, name) or [])) for name in names
    }


def create_view(source: dict[str, Any], filters: dict[str, tuple[str, ...]],
                include_evidence: bool = False) -> dict[str, Any]:
    """Pure view, preserving uncertainty and original summary totals.

    No filter ever changes source.status, source defect totals, the number
    of unexecuted cases, or the full-scene certification guard.
    """
    reports = source.get("reports", [])
    if not isinstance(reports, list):
        reports = []
    selected: list[dict[str, Any]] = []
    evidence_index = {
        "unmeasured": [], "data_quality": [],
        "uncertainty": [], "confirmed_defects": [],
    }
    for report_index, report in enumerate(reports):
        if not isinstance(report, dict):
            continue
        cases = report.get("cases", [])
        if not isinstance(cases, list):
            continue
        for case_index, case in enumerate(cases):
            if not isinstance(case, dict):
                continue
            row = _build_case(
                report, case, report_index, case_index, include_evidence
            )
            if not _matches(row, report, filters):
                continue
            selected.append(row)
            base_index = {
                "report_alias": row["report_alias"],
                "report_index": report_index,
                "case_id": row["case_id"],
                "case_index": case_index,
                "case_pointer": row["evidence_ref"]["case_pointer"],
                "stdout_pointer": row["evidence_ref"]["stdout_base64_pointer"],
                "stdout_sha256": row["evidence_fingerprints"]["stdout_sha256"],
            }
            for metric in row["missing_metrics"]:
                evidence_index["unmeasured"].append({
                    **base_index,
                    **metric,
                    "confidence": row["evidence_integrity"],
                    "never_implies_measurement_value": True,
                })
            quality = row["data_quality"]
            if quality["status"] != "valid":
                evidence_index["data_quality"].append({
                    **base_index,
                    "quality": quality["status"],
                    "error_count": quality["error_count"],
                    "error_codes": quality["error_codes"],
                    "reason": quality["reason"],
                    "raw_error_detail_emitted": False,
                })
            if row["evaluation"] == "inconclusive" or row["reason_codes"]:
                if row["evaluation"] == "inconclusive":
                    evidence_index["uncertainty"].append({
                        **base_index, "reason_codes": row["reason_codes"],
                    })
            if row["confirmed_defect"]:
                evidence_index["confirmed_defects"].append({
                    **base_index, "classification": row["classification"],
                })

    unknown_reports = [
        {"report_index": i, "report_alias": f"input_{i + 1:02d}",
         "issues": report.get("issues", [])}
        for i, report in enumerate(reports)
        if isinstance(report, dict) and (
            report.get("issues") or report.get("status") == "inconclusive"
        )
    ]
    skipped = [
        {"report_index": i, "report_alias": f"input_{i + 1:02d}",
         "unexecuted": report.get("cases_skipped_count")}
        for i, report in enumerate(reports)
        if isinstance(report, dict) and (
            type(report.get("cases_skipped_count")) is int
            and report["cases_skipped_count"] > 0
        )
    ]
    selection_counts = {
        "evaluation": _counter([str(x["evaluation"]) for x in selected]),
        "subset": _counter([str(x["measured_subset_status"]) for x in selected]),
        "data_quality": _counter([
            x["data_quality"]["status"] for x in selected
        ]),
        "report_type": _counter([str(x["report_type"]) for x in selected]),
        "missing_state": _counter([
            x["state"] for x in evidence_index["unmeasured"]
        ]),
        "missing_metric": _counter([
            x["metric"] for x in evidence_index["unmeasured"]
        ]),
    }
    selected_reports = sorted({x["report_index"] for x in selected})

    # Filters MUST NOT fabricate an overall success. The global status
    # comes from the unsliced foundation summary, not selected cases.
    global_status = source.get("status", "inconclusive")
    if global_status not in (
        "defects_found", "inconclusive", "no_definitive_qa_defects"
    ):
        global_status = "inconclusive"
    return {
        "task_id": TASK_ID,
        "version": VERSION,
        "development_validation": VALIDATION,
        "status": global_status,
        "original_aggregate_status": source.get("status"),
        "view_status": (
            "empty_selection" if not selected else "filtered_observations_only"
        ),
        "filtering_does_not_recalculate_qa_verdict": True,
        "filters": {k: list(v) for k, v in filters.items() if v},
        "privacy": {
            "raw_evidence_included": include_evidence,
            "input_file_names_included": False,
            "source_pointers_are_to_unfiltered_aggregate": True,
        },
        "source_summary": {
            "reports_received": source.get("reports_received", len(reports)),
            "total_cases_observed": source.get("cases_observed_across_reports"),
            "confirmed_defects": source.get("confirmed_defects_across_reports"),
            "inconclusive_cases": source.get("inconclusive_cases_across_reports"),
            "report_level_issues": source.get("report_level_issues"),
            "unresolved_report_index": unknown_reports,
            "unexecuted_case_index": skipped,
            "same_case_ids_are_not_merged": True,
        },
        "selection_summary": {
            "cases_selected": len(selected),
            "reports_with_selected_cases": len(selected_reports),
            "report_indices": selected_reports,
            "selected_confirmed_defects": sum(
                x["confirmed_defect"] for x in selected
            ),
            "selected_inconclusive_cases": sum(
                x["evaluation"] == "inconclusive" for x in selected
            ),
            "documented_not_measured_entries": sum(
                m["state"] == "documented_not_measured"
                for m in evidence_index["unmeasured"]
            ),
            "unverified_or_unknown_missing_entries": sum(
                m["state"] != "documented_not_measured"
                or m["confidence"] != "internally_consistent_only"
                for m in evidence_index["unmeasured"]
            ),
            "counts": selection_counts,
        },
        "full_scene": {
            "certification": "NOT_ESTABLISHED",
            "full_scene_pass": False,
            "observed_measured_subset_is_not_scene_pass": True,
            "unmeasured_schema_metrics": list(SCENE_METRICS),
        },
        "evidence_index": evidence_index,
        "selected_cases": selected,
        "limitations": [
            "All inputs are synthetic QA reports, not actual game performance",
            "Source report status and uncertainty are retained across filters",
            "PR5 generic QA does not establish a measured-subset status",
            "Missing scene metrics cannot be filled with zero or inferred",
            "Evidence refs address source aggregate paths, not external URLs",
            "Internal stdout/base64 agreement does not authenticate provenance",
            "Input CSV SHA256 cannot be verified without original CSV bytes",
            "A filtered no-defect result never certifies a full game scene",
            "Raw evidence is excluded by default due to privacy concerns",
            "This module never executes the analyzer or existing QA tools",
        ],
    }


def _choices(parser: argparse.ArgumentParser, name: str,
             choices: tuple[str, ...] | None, help_text: str) -> None:
    options = {"action": "append", "default": None, "help": help_text}
    if choices is not None:
        options["choices"] = choices
    parser.add_argument("--" + name.replace("_", "-"), **options)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report", action="append", type=Path, required=True,
        help="Offline PR5 r2 or PR7 r1 JSON report (repeatable, max 32)",
    )
    _choices(parser, "evaluation", CASE_EVALUATIONS, "Case evaluation")
    _choices(parser, "subset", SUBSET_STATUSES, "Measured subset only")
    _choices(parser, "quality", QUALITY_STATUSES, "Data-quality status")
    _choices(parser, "classification", None, "Exact source case classification")
    _choices(parser, "case_id", foundation.CASE_IDS, "Exact synthetic case ID")
    _choices(parser, "report_type", REPORT_TYPES, "PR5 r2 or PR7 r1")
    _choices(parser, "reason", None, "Exact reason code, report: or schema:")
    _choices(parser, "missing_metric", SCENE_METRICS, "Missing-scene metric")
    _choices(parser, "missing_state", MISSING_STATES, "Missing evidence state")
    parser.add_argument(
        "--include-evidence", action="store_true",
        help="Opt in to raw case evidence in output (may contain private logs)",
    )
    parser.add_argument(
        "--output", type=Path,
        help="New JSON output path; refuses overwrite",
    )
    args = parser.parse_args(argv)
    if len(args.report) > MAX_REPORTS:
        parser.error("maximum_32_reports")

    sources: list[tuple[str, Any]] = []
    for index, path in enumerate(args.report):
        alias = _safe_basename(path, index + 1)
        try:
            data = foundation.read_report(path)
        except (OSError, UnicodeError, ValueError) as exc:
            data = {
                "task_id": "unreadable_report",
                "version": None,
                "error_type": type(exc).__name__,
            }
        sources.append((alias, data))

    try:
        summary = foundation.aggregate_documents(sources)
        view = create_view(summary, _as_options(args), args.include_evidence)
    except (TypeError, ValueError, KeyError, IndexError) as exc:
        # Fail closed if older source aggregator cannot interpret the input.
        view = {
            "task_id": TASK_ID,
            "version": VERSION,
            "status": "inconclusive",
            "view_status": "source_aggregation_unrecognized",
            "error_type": type(exc).__name__,
            "full_scene": {
                "certification": "NOT_ESTABLISHED", "full_scene_pass": False
            },
            "development_validation": VALIDATION,
            "selected_cases": [],
        }

    rendered = json.dumps(
        view, ensure_ascii=False, allow_nan=False, indent=2
    ) + "\n"
    if args.output is None:
        sys.stdout.write(rendered)
    else:
        try:
            with args.output.open("x", encoding="utf-8") as stream:
                stream.write(rendered)
        except OSError as exc:
            print("output_write_error:" + type(exc).__name__, file=sys.stderr)
            return 2
    return {"defects_found": 1, "inconclusive": 4}.get(
        view.get("status"), 0
    )


if __name__ == "__main__":
    raise SystemExit(main())

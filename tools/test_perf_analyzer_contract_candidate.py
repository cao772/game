
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GAME-WEB-TECHQA-001 / W-TECH-QA / r2

Independent adversarial black-box QA for a performance analyzer.

Target CLI contract:
    python analyzer.py input.csv

Target stdout:
    JSON document

Python 3.12 standard library only.
No target source modification.
No shell=True, network calls, or global environment changes.

All CSV input data are synthetic.
This tool does NOT measure actual game performance.

r2 fixes:
1. Explicit overall PASS on invalid input is a defect even
   when the target exits with a nonzero code.
2. A JSON note containing "usage:" is not a CLI mismatch.
3. Genuine argparse usage errors still produce
   contract_mismatch, exit code 2.
4. Unknown or conflicting verdict fields remain inconclusive.
"""

import argparse
import base64
import csv
import hashlib
import io
import json
import subprocess
import sys
import tempfile

from collections import Counter
from pathlib import Path


TASK_ID = "GAME-WEB-TECHQA-001"
VERSION = "r2"
WINDOW = "W-TECH-QA"

TIMEOUT_SECONDS = 5
MAX_CASES = 15

COLUMNS = [
    "frame_ms",
    "script_ms",
    "ram_gib",
    "vram_delta_gib",
    "draw_calls",
    "triangles",
]

LIMITS = {
    "frame_p50_ms": 12.0,
    "frame_p95_ms": 16.7,
    "frame_p99_ms": 24.0,
    "script_p95_ms": 2.0,
    "ram_gib": 1.2,
    "vram_delta_gib": 1.0,
    "draw_calls": 200,
    "triangles": 150000,
}

# Candidate recognition rules only.
#
# These fields are interpreted as an OVERALL verdict.
# Do not silently add target-specific fields.
#
# In particular:
# - measured_subset_status is NOT an overall verdict.
# - full_scene_pass is NOT inferred from a CSV subset.
# - status="incomplete" is NOT treated as PASS or FAIL.

VERDICT_PATHS = [
    ("overall_pass",),
    ("passed",),
    ("pass",),
    ("status",),
    ("verdict",),
    ("result",),

    ("summary", "overall_pass"),
    ("summary", "passed"),
    ("summary", "pass"),
    ("summary", "status"),
    ("summary", "verdict"),

    ("overall", "pass"),
    ("overall", "passed"),
    ("overall", "status"),
]

PASS_WORDS = {"PASS", "PASSED"}
FAIL_WORDS = {"FAIL", "FAILED"}


# ------------------------------------------------------------
# Synthetic test cases
# ------------------------------------------------------------

def baseline_rows():
    return [
        [8.0, 1.0, 0.5, 0.2, 100, 50000]
        for _ in range(100)
    ]


def changed_rows(column, value):
    rows = baseline_rows()
    index = COLUMNS.index(column)

    for row in rows:
        row[index] = value

    return rows


def tail_spike(column, value, count):
    rows = baseline_rows()
    index = COLUMNS.index(column)

    for row in rows[-count:]:
        row[index] = value

    return rows


def make_case(
    case_id,
    rows,
    columns=None,
    purpose="",
):
    return {
        "case_id": case_id,
        "columns": list(
            COLUMNS if columns is None else columns
        ),
        "rows": rows,
        "purpose": purpose,
    }


def build_cases():
    cases = [
        make_case(
            "C01_baseline",
            baseline_rows(),
            purpose="All metrics below thresholds",
        ),

        make_case(
            "C02_frame_p50",
            changed_rows("frame_ms", 13.0),
            purpose="Frame P50 > 12 ms",
        ),

        make_case(
            "C03_frame_p95",
            tail_spike("frame_ms", 20.0, 10),
            purpose="Frame P95 > 16.7 ms",
        ),

        make_case(
            "C04_frame_p99",
            tail_spike("frame_ms", 30.0, 2),
            purpose="Frame P99 > 24 ms",
        ),

        make_case(
            "C05_script_p95",
            tail_spike("script_ms", 3.0, 10),
            purpose="Script P95 > 2 ms",
        ),

        make_case(
            "C06_ram",
            changed_rows("ram_gib", 1.3),
            purpose="RAM > 1.2 GiB",
        ),

        make_case(
            "C07_vram",
            changed_rows("vram_delta_gib", 1.1),
            purpose="VRAM delta > 1 GiB",
        ),

        make_case(
            "C08_draw_calls",
            changed_rows("draw_calls", 201),
            purpose="Draw calls > 200",
        ),

        make_case(
            "C09_triangles",
            changed_rows("triangles", 150001),
            purpose="Triangles > 150000",
        ),
    ]

    missing_index = COLUMNS.index("draw_calls")

    missing_columns = [
        column
        for column in COLUMNS
        if column != "draw_calls"
    ]

    missing_rows = [
        [
            value
            for index, value in enumerate(row)
            if index != missing_index
        ]
        for row in baseline_rows()
    ]

    cases.append(
        make_case(
            "C10_missing_column",
            missing_rows,
            columns=missing_columns,
            purpose="Missing draw_calls column must not PASS",
        )
    )

    cases.append(
        make_case(
            "C11_empty_table",
            [],
            purpose="Header-only CSV must not PASS",
        )
    )

    special_values = [
        ("C12_nan", "frame_ms", "NaN"),
        ("C13_infinity", "script_ms", "Infinity"),
        ("C14_negative", "ram_gib", -0.1),
        ("C15_missing_cell", "frame_ms", ""),
    ]

    for case_id, column, value in special_values:
        rows = baseline_rows()
        rows[0][COLUMNS.index(column)] = value

        cases.append(
            make_case(
                case_id,
                rows,
                purpose=(
                    f"Invalid or missing {column} "
                    "must not PASS"
                ),
            )
        )

    assert len(cases) == MAX_CASES

    return cases


def csv_bytes(case):
    buffer = io.StringIO(newline="")

    writer = csv.writer(
        buffer,
        lineterminator="\n",
    )

    writer.writerow(case["columns"])
    writer.writerows(case["rows"])

    return buffer.getvalue().encode("utf-8")


# ------------------------------------------------------------
# Raw subprocess evidence
# ------------------------------------------------------------

def as_bytes(value):
    if value is None:
        return b""

    if isinstance(value, bytes):
        return value

    return value.encode(
        "utf-8",
        errors="replace",
    )


def decode_bytes(value):
    return value.decode(
        "utf-8",
        errors="replace",
    )


def encode_base64(value):
    return base64.b64encode(value).decode("ascii")


def attach_raw_evidence(
    result,
    stdout,
    stderr,
):
    result["raw_stdout"] = decode_bytes(stdout)
    result["raw_stderr"] = decode_bytes(stderr)

    result["stdout_base64"] = encode_base64(stdout)
    result["stderr_base64"] = encode_base64(stderr)


# ------------------------------------------------------------
# Strict JSON parsing
# ------------------------------------------------------------

def reject_nonstandard_constant(value):
    raise ValueError(
        f"Nonstandard JSON constant: {value}"
    )


def parse_json_output(stdout):
    try:
        decoded = stdout.decode("utf-8")

        document = json.loads(
            decoded,
            parse_constant=reject_nonstandard_constant,
        )

        return document, None

    except (
        UnicodeDecodeError,
        ValueError,
    ) as exc:
        return None, str(exc)


# ------------------------------------------------------------
# Conservative overall-verdict recognition
# ------------------------------------------------------------

def get_nested(document, path):
    current = document

    for key in path:
        if not isinstance(current, dict):
            return None

        if key not in current:
            return None

        current = current[key]

    return current


def normalize_verdict(value):
    # bool is intentionally checked using exact type.
    # Integer 1 is not silently interpreted as True.
    if type(value) is bool:
        return value

    if isinstance(value, str):
        normalized = value.strip().upper()

        if normalized in PASS_WORDS:
            return True

        if normalized in FAIL_WORDS:
            return False

    return None


def recognize_verdict(document):
    recognized = []

    for path in VERDICT_PATHS:
        value = get_nested(document, path)
        verdict = normalize_verdict(value)

        if verdict is not None:
            recognized.append({
                "path": ".".join(path),
                "value": verdict,
            })

    if not recognized:
        return (
            None,
            "no_supported_verdict_field",
            [],
        )

    distinct_values = {
        item["value"]
        for item in recognized
    }

    if len(distinct_values) != 1:
        return (
            None,
            "conflicting_verdict_fields",
            recognized,
        )

    return (
        recognized[0]["value"],
        None,
        recognized,
    )


# ------------------------------------------------------------
# CLI mismatch and exception detection
# ------------------------------------------------------------

def is_argparse_cli_error(
    exit_code,
    json_error,
    stderr,
):
    """
    Recognize a genuine argparse-style CLI failure.

    Requirements:
    - exit code 2
    - stdout is NOT valid JSON
    - stderr contains usage and error diagnostics

    Normal JSON strings containing "usage:" are ignored.
    """

    if exit_code != 2:
        return False

    if json_error is None:
        return False

    message = stderr.lower()

    if "usage:" not in message:
        return False

    error_markers = (
        "error:",
        "unrecognized arguments",
        "the following arguments are required",
        "invalid choice:",
        "expected one argument",
        "too few arguments",
    )

    return any(
        marker in message
        for marker in error_markers
    )


def looks_like_exception(
    stderr,
    exit_code,
):
    if (
        exit_code is not None
        and exit_code < 0
    ):
        return True

    markers = (
        "Traceback (most recent call last)",
        "Unhandled exception",
        "uncaught exception",
    )

    return any(
        marker in stderr
        for marker in markers
    )


# ------------------------------------------------------------
# Classification helpers
# ------------------------------------------------------------

def classify(
    result,
    classification,
    detail,
    defect=False,
):
    result["classification"] = classification
    result["detail"] = detail
    result["defect"] = defect

    return result


def classify_baseline(
    result,
    exit_code,
    json_error,
    verdict,
    verdict_reason,
    stderr_text,
):
    if looks_like_exception(
        stderr_text,
        exit_code,
    ):
        return classify(
            result,
            "exception",
            "Uncaught exception or signal termination",
            defect=True,
        )

    # A valid baseline must satisfy the declared CLI contract.
    # Nonzero exit alone is not classified as a functional defect.
    if exit_code != 0:
        return classify(
            result,
            "contract_mismatch",
            (
                "Valid baseline returned nonzero exit code; "
                "declared CLI contract not satisfied"
            ),
        )

    if json_error is not None:
        return classify(
            result,
            "format_error",
            (
                "Exit code 0 but stdout is not strict "
                f"UTF-8 JSON: {json_error}"
            ),
            defect=True,
        )

    if verdict_reason is not None:
        return classify(
            result,
            "schema_unrecognized",
            verdict_reason,
        )

    if verdict is True:
        return classify(
            result,
            "baseline_pass",
            "Valid synthetic baseline accepted",
        )

    return classify(
        result,
        "baseline_unexpected_fail",
        (
            "Valid synthetic baseline was rejected; "
            "requires contract review"
        ),
    )


def classify_adversarial(
    result,
    exit_code,
    json_error,
    verdict,
    verdict_reason,
    stderr_text,
):
    """
    Important r2 ordering:

    1. A recognized explicit PASS is a defect,
       regardless of nonzero exit code.
    2. An exception is a defect.
    3. Nonzero exit without valid JSON may be rejection.
    4. A successful exit must provide valid JSON.
    5. Unknown/conflicting schemas remain inconclusive.
    """

    # FIX r2-1:
    # Explicit overall PASS cannot be hidden by exit code 1.
    if (
        json_error is None
        and verdict_reason is None
        and verdict is True
    ):
        return classify(
            result,
            "wrong_pass",
            (
                "Invalid or over-threshold synthetic input "
                "returned explicit overall PASS "
                f"with exit code {exit_code}"
            ),
            defect=True,
        )

    if looks_like_exception(
        stderr_text,
        exit_code,
    ):
        return classify(
            result,
            "exception",
            "Uncaught exception or signal termination",
            defect=True,
        )

    if json_error is not None:
        if exit_code != 0:
            return classify(
                result,
                "rejected",
                (
                    "Nonzero exit without parseable JSON PASS; "
                    "treated as rejection, not a defect"
                ),
            )

        return classify(
            result,
            "format_error",
            (
                "Exit code 0 but stdout is not strict "
                f"UTF-8 JSON: {json_error}"
            ),
            defect=True,
        )

    if verdict_reason is not None:
        return classify(
            result,
            "schema_unrecognized",
            verdict_reason,
        )

    if verdict is False:
        return classify(
            result,
            "rejected",
            (
                "Explicit overall FAIL on invalid or "
                "over-threshold input"
            ),
        )

    # Defensive fallback; should not be reached.
    return classify(
        result,
        "schema_unrecognized",
        "Unexpected unrecognized verdict state",
    )


# ------------------------------------------------------------
# Execute one case in its own temporary directory
# ------------------------------------------------------------

def evaluate_case(
    analyzer,
    case,
    timeout=TIMEOUT_SECONDS,
):
    payload = csv_bytes(case)

    result = {
        "case_id": case["case_id"],
        "purpose": case["purpose"],
        "synthetic": True,
        "input_columns": case["columns"],
        "input_rows": len(case["rows"]),
        "input_sha256": hashlib.sha256(
            payload
        ).hexdigest(),
        "timeout_seconds": timeout,
        "command": [],
        "raw_stdout": "",
        "raw_stderr": "",
        "stdout_base64": "",
        "stderr_base64": "",
        "exit_code": None,
        "timed_out": False,
        "classification": None,
        "defect": False,
        "verdict": None,
        "verdict_fields": [],
        "detail": "",
    }

    stdout = b""
    stderr = b""

    with tempfile.TemporaryDirectory(
        prefix="game_techqa_r2_"
    ) as temporary_directory:

        input_file = (
            Path(temporary_directory) / "input.csv"
        )

        input_file.write_bytes(payload)

        command = [
            sys.executable,
            str(analyzer),
            str(input_file),
        ]

        result["command"] = command

        try:
            completed = subprocess.run(
                command,
                cwd=temporary_directory,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                shell=False,
                check=False,
            )

            stdout = completed.stdout or b""
            stderr = completed.stderr or b""

            result["exit_code"] = completed.returncode

        except subprocess.TimeoutExpired as exc:
            result["timed_out"] = True

            stdout = as_bytes(exc.stdout)
            stderr = as_bytes(exc.stderr)

        except OSError as exc:
            result["classification"] = "contract_mismatch"
            result["detail"] = (
                "Cannot invoke target under the CLI "
                f"contract: {exc}"
            )

    attach_raw_evidence(
        result,
        stdout,
        stderr,
    )

    if result["classification"] == "contract_mismatch":
        return result

    if result["timed_out"]:
        return classify(
            result,
            "timeout",
            (
                f"Subprocess exceeded "
                f"{timeout} seconds"
            ),
            defect=True,
        )

    exit_code = result["exit_code"]

    # FIX r2-2:
    # Parse JSON before interpreting CLI-related text.
    # A JSON field containing "usage:" is ordinary data.
    document, json_error = parse_json_output(stdout)

    verdict = None
    verdict_reason = None
    verdict_fields = []

    if json_error is None:
        (
            verdict,
            verdict_reason,
            verdict_fields,
        ) = recognize_verdict(document)

    result["verdict"] = verdict
    result["verdict_fields"] = verdict_fields

    stderr_text = result["raw_stderr"]

    # Genuine argparse mismatch:
    # exit 2 + non-JSON stdout + usage error on stderr.
    if is_argparse_cli_error(
        exit_code,
        json_error,
        stderr_text,
    ):
        return classify(
            result,
            "contract_mismatch",
            (
                "Argparse-style CLI usage failure; "
                "no alternative invocation attempted"
            ),
        )

    is_baseline = (
        case["case_id"] == "C01_baseline"
    )

    if is_baseline:
        return classify_baseline(
            result,
            exit_code,
            json_error,
            verdict,
            verdict_reason,
            stderr_text,
        )

    return classify_adversarial(
        result,
        exit_code,
        json_error,
        verdict,
        verdict_reason,
        stderr_text,
    )


# ------------------------------------------------------------
# Run suite, max 15 cases per target
# ------------------------------------------------------------

def run_suite(analyzer, cases):
    if not cases:
        raise ValueError("At least one case is required")

    if len(cases) > MAX_CASES:
        raise ValueError(
            f"Maximum {MAX_CASES} cases per target"
        )

    if cases[0]["case_id"] != "C01_baseline":
        raise ValueError(
            "First case must be C01_baseline"
        )

    case_ids = [
        case["case_id"]
        for case in cases
    ]

    if len(case_ids) != len(set(case_ids)):
        raise ValueError(
            "Duplicate case identifiers"
        )

    results = []

    for index, case in enumerate(cases):
        result = evaluate_case(
            analyzer,
            case,
        )

        results.append(result)

        classification = result["classification"]

        # A genuine CLI contract mismatch is terminal.
        if classification == "contract_mismatch":
            break

        # Do not execute 14 more cases after an
        # unrecognized or rejected baseline.
        if index == 0:
            if classification != "baseline_pass":
                break

    counts = dict(
        Counter(
            item["classification"]
            for item in results
        )
    )

    defect_cases = [
        item["case_id"]
        for item in results
        if item["defect"]
    ]

    baseline_state = results[0]["classification"]

    if "contract_mismatch" in counts:
        status = "contract_mismatch"
        exit_code = 2

    elif defect_cases:
        status = "defects_found"
        exit_code = 1

    elif (
        baseline_state == "schema_unrecognized"
        or "schema_unrecognized" in counts
    ):
        status = "schema_unrecognized"
        exit_code = 4

    elif baseline_state != "baseline_pass":
        status = "inconclusive"
        exit_code = 4

    else:
        status = "no_definitive_defects"
        exit_code = 0

    executed_ids = {
        item["case_id"]
        for item in results
    }

    skipped_cases = [
        case["case_id"]
        for case in cases
        if case["case_id"] not in executed_ids
    ]

    report = {
        "task_id": TASK_ID,
        "version": VERSION,
        "window": WINDOW,
        "canon_version": "not_applicable",
        "status": status,
        "exit_code": exit_code,
        "analyzer": str(analyzer),

        "synthetic_data": True,
        "actual_performance_measurement": False,
        "full_scene_performance_certified": False,
        "target_source_modified": False,

        "thresholds": LIMITS,
        "percentile_method": "target_defined_unverified",

        "timeout_seconds": TIMEOUT_SECONDS,
        "max_cases_per_target": MAX_CASES,

        "cases_planned": len(cases),
        "cases_executed": len(results),
        "cases_skipped": skipped_cases,

        "counts": counts,
        "defect_cases": defect_cases,
        "results": results,

        "limitations": [
            "All input data are synthetic",
            "This is black-box contract QA, not profiling",
            "Only explicitly listed overall verdict paths are recognized",
            "Unknown and conflicting verdict fields are inconclusive",
            "Nonzero exit without explicit PASS is not automatically a defect",
            "CSV subset PASS cannot establish full-scene PASS",
            "Percentile interpolation remains unverified",
            "Target-specific aggregation semantics remain unverified",
            "The harness does not sandbox a target's internal network or child processes",
            "No definitive defects is not formal product acceptance",
        ],
    }

    return report, exit_code


# ------------------------------------------------------------
# Built-in fake analyzers for regression self-test
# ------------------------------------------------------------

BASELINE_DETECTION_SOURCE = """
import csv
import sys
from pathlib import Path

with Path(sys.argv[1]).open(
    "r",
    encoding="utf-8",
    newline=""
) as stream:
    rows = list(csv.reader(stream))

expected_header = [
    "frame_ms",
    "script_ms",
    "ram_gib",
    "vram_delta_gib",
    "draw_calls",
    "triangles",
]

expected_row = [
    "8.0",
    "1.0",
    "0.5",
    "0.2",
    "100",
    "50000",
]

is_baseline = (
    len(rows) == 101
    and rows[0] == expected_header
    and all(row == expected_row for row in rows[1:])
)
"""


def write_fake(root, name, source):
    path = root / f"{name}.py"

    path.write_text(
        source,
        encoding="utf-8",
    )

    return path.resolve()


def find_result(report, case_id):
    for item in report["results"]:
        if item["case_id"] == case_id:
            return item

    return None


def check_result(
    name,
    condition,
    report,
):
    return {
        "name": name,
        "passed": bool(condition),
        "report_status": report["status"],
        "report_exit_code": report["exit_code"],
        "cases_executed": report["cases_executed"],
        "defect_cases": report["defect_cases"],
    }


def self_test():
    cases = build_cases()

    checks = []

    with tempfile.TemporaryDirectory(
        prefix="game_techqa_r2_selftest_"
    ) as temporary_directory:

        root = Path(temporary_directory)

        # --------------------------------------------------
        # S01: Original r1 wrong-PASS self-test
        # Fake always returns PASS / exit 0.
        # --------------------------------------------------

        fake_wrong_pass = write_fake(
            root,
            "fake_wrong_pass",
            (
                "import json\n"
                'print(json.dumps({"status": "PASS"}))\n'
            ),
        )

        report, code = run_suite(
            fake_wrong_pass,
            [cases[0], cases[1], cases[11]],
        )

        c02 = find_result(
            report,
            "C02_frame_p50",
        )

        c12 = find_result(
            report,
            "C12_nan",
        )

        condition = all([
            code == 1,
            report["status"] == "defects_found",
            c02 is not None,
            c12 is not None,
            c02 is not None
            and c02["classification"] == "wrong_pass",
            c12 is not None
            and c12["classification"] == "wrong_pass",
        ])

        checks.append(
            check_result(
                "S01_wrong_pass_exit0",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S02: Original r1 timeout self-test
        # Baseline passes; adversarial case sleeps 6 seconds.
        # --------------------------------------------------

        fake_timeout = write_fake(
            root,
            "fake_timeout",
            (
                BASELINE_DETECTION_SOURCE
                + "\nimport json\n"
                + "import time\n"
                + "if not is_baseline:\n"
                + "    time.sleep(6)\n"
                + 'print(json.dumps({"status": "PASS"}))\n'
            ),
        )

        report, code = run_suite(
            fake_timeout,
            [cases[0], cases[1]],
        )

        timeout_case = find_result(
            report,
            "C02_frame_p50",
        )

        condition = all([
            code == 1,
            report["status"] == "defects_found",
            timeout_case is not None,
            timeout_case is not None
            and timeout_case["classification"] == "timeout",
            timeout_case is not None
            and timeout_case["timed_out"] is True,
            timeout_case is not None
            and timeout_case["defect"] is True,
        ])

        checks.append(
            check_result(
                "S02_timeout",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S03: r2 regression 1
        #
        # Baseline: PASS / exit 0.
        # Other 14: PASS / exit 1.
        #
        # Must detect 14 wrong_pass defects.
        # --------------------------------------------------

        fake_nonzero_pass = write_fake(
            root,
            "fake_nonzero_pass",
            (
                BASELINE_DETECTION_SOURCE
                + "\nimport json\n"
                + 'print(json.dumps({"status": "PASS"}))\n'
                + "sys.exit(0 if is_baseline else 1)\n"
            ),
        )

        report, code = run_suite(
            fake_nonzero_pass,
            cases,
        )

        adversarial_results = report["results"][1:]

        condition = all([
            code == 1,
            report["status"] == "defects_found",
            report["cases_executed"] == MAX_CASES,
            len(report["defect_cases"]) == 14,
            len(adversarial_results) == 14,
            all(
                item["classification"] == "wrong_pass"
                and item["exit_code"] == 1
                and item["verdict"] is True
                and item["defect"] is True
                for item in adversarial_results
            ),
        ])

        checks.append(
            check_result(
                "S03_nonzero_explicit_pass",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S04: r2 regression 2
        #
        # Valid JSON includes "usage:" in an ordinary note.
        # Must not be classified as CLI mismatch.
        # --------------------------------------------------

        fake_usage_note = write_fake(
            root,
            "fake_usage_note",
            (
                "import json\n"
                "print(json.dumps({\n"
                '    "status": "PASS",\n'
                '    "note": "usage: metrics"\n'
                "}))\n"
            ),
        )

        report, code = run_suite(
            fake_usage_note,
            cases,
        )

        baseline = find_result(
            report,
            "C01_baseline",
        )

        condition = all([
            code == 1,
            report["status"] == "defects_found",
            report["cases_executed"] == MAX_CASES,
            len(report["defect_cases"]) == 14,
            baseline is not None,
            baseline is not None
            and baseline["classification"] == "baseline_pass",
            all(
                item["classification"] == "wrong_pass"
                for item in report["results"][1:]
            ),
            "contract_mismatch" not in report["counts"],
        ])

        checks.append(
            check_result(
                "S04_json_usage_note",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S05: Known but not approved analyzer schema
        #
        # measured_subset_status is not overall status.
        # status=incomplete is not PASS.
        # full_scene_pass=false must not be upgraded.
        # --------------------------------------------------

        fake_unknown_schema = write_fake(
            root,
            "fake_unknown_schema",
            (
                "import json\n"
                "print(json.dumps({\n"
                '    "status": "incomplete",\n'
                '    "measured_subset_status": "PASS",\n'
                '    "full_scene_pass": False\n'
                "}))\n"
            ),
        )

        report, code = run_suite(
            fake_unknown_schema,
            cases,
        )

        condition = all([
            code == 4,
            report["status"] == "schema_unrecognized",
            report["cases_executed"] == 1,
            not report["defect_cases"],
            report["results"][0]["classification"]
            == "schema_unrecognized",
            report["results"][0]["verdict"] is None,
        ])

        checks.append(
            check_result(
                "S05_unknown_subset_schema",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S06: Conflicting overall verdict fields
        #
        # Baseline: status=PASS.
        # Invalid: status=PASS, passed=false.
        #
        # Contradiction must not be guessed as PASS.
        # --------------------------------------------------

        fake_conflicting_schema = write_fake(
            root,
            "fake_conflicting_schema",
            (
                BASELINE_DETECTION_SOURCE
                + "\nimport json\n"
                + "if is_baseline:\n"
                + '    print(json.dumps({"status": "PASS"}))\n'
                + "else:\n"
                + '    print(json.dumps({'
                '"status": "PASS", '
                '"passed": False}))\n'
            ),
        )

        report, code = run_suite(
            fake_conflicting_schema,
            [cases[0], cases[1]],
        )

        conflicting_case = find_result(
            report,
            "C02_frame_p50",
        )

        condition = all([
            code == 4,
            report["status"] == "schema_unrecognized",
            not report["defect_cases"],
            conflicting_case is not None,
            conflicting_case is not None
            and conflicting_case["classification"]
            == "schema_unrecognized",
            conflicting_case is not None
            and conflicting_case["detail"]
            == "conflicting_verdict_fields",
            conflicting_case is not None
            and conflicting_case["verdict"] is None,
        ])

        checks.append(
            check_result(
                "S06_conflicting_verdict_fields",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S07: Genuine argparse CLI mismatch
        #
        # CLI expects --required, not a positional CSV.
        # argparse exits 2 and prints usage/error on stderr.
        #
        # Must stop after baseline, exit 2.
        # --------------------------------------------------

        fake_argparse = write_fake(
            root,
            "fake_argparse_mismatch",
            (
                "import argparse\n"
                "parser = argparse.ArgumentParser()\n"
                "parser.add_argument(\n"
                '    "--required",\n'
                "    required=True\n"
                ")\n"
                "parser.parse_args()\n"
            ),
        )

        report, code = run_suite(
            fake_argparse,
            cases,
        )

        condition = all([
            code == 2,
            report["status"] == "contract_mismatch",
            report["cases_executed"] == 1,
            report["results"][0]["classification"]
            == "contract_mismatch",
            report["results"][0]["exit_code"] == 2,
            not report["defect_cases"],
        ])

        checks.append(
            check_result(
                "S07_argparse_contract_mismatch",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S08: Normal rejection with nonzero exit
        #
        # Baseline: PASS / exit 0.
        # Invalid: FAIL / exit 1.
        #
        # This is not an established functional defect.
        # --------------------------------------------------

        fake_normal_rejection = write_fake(
            root,
            "fake_normal_rejection",
            (
                BASELINE_DETECTION_SOURCE
                + "\nimport json\n"
                + "if is_baseline:\n"
                + '    print(json.dumps({"status": "PASS"}))\n'
                + "    sys.exit(0)\n"
                + 'print(json.dumps({"status": "FAIL"}))\n'
                + "sys.exit(1)\n"
            ),
        )

        report, code = run_suite(
            fake_normal_rejection,
            [cases[0], cases[1]],
        )

        rejection_case = find_result(
            report,
            "C02_frame_p50",
        )

        condition = all([
            code == 0,
            report["status"] == "no_definitive_defects",
            not report["defect_cases"],
            rejection_case is not None,
            rejection_case is not None
            and rejection_case["classification"] == "rejected",
            rejection_case is not None
            and rejection_case["exit_code"] == 1,
            rejection_case is not None
            and rejection_case["verdict"] is False,
        ])

        checks.append(
            check_result(
                "S08_nonzero_normal_rejection",
                condition,
                report,
            )
        )

        # --------------------------------------------------
        # S09: Nonzero exit with unknown JSON schema
        #
        # Do not label unknown JSON as valid PASS,
        # and do not report success without understanding it.
        # --------------------------------------------------

        fake_nonzero_unknown = write_fake(
            root,
            "fake_nonzero_unknown",
            (
                BASELINE_DETECTION_SOURCE
                + "\nimport json\n"
                + "if is_baseline:\n"
                + '    print(json.dumps({"status": "PASS"}))\n'
                + "    sys.exit(0)\n"
                + 'print(json.dumps({"custom_result": "OK"}))\n'
                + "sys.exit(1)\n"
            ),
        )

        report, code = run_suite(
            fake_nonzero_unknown,
            [cases[0], cases[1]],
        )

        unknown_case = find_result(
            report,
            "C02_frame_p50",
        )

        condition = all([
            code == 4,
            report["status"] == "schema_unrecognized",
            not report["defect_cases"],
            unknown_case is not None,
            unknown_case is not None
            and unknown_case["classification"]
            == "schema_unrecognized",
        ])

        checks.append(
            check_result(
                "S09_nonzero_unknown_schema",
                condition,
                report,
            )
        )

    all_passed = all(
        item["passed"]
        for item in checks
    )

    report = {
        "task_id": TASK_ID,
        "version": VERSION,
        "window": WINDOW,
        "mode": "self_test",
        "status": (
            "self_test_pass"
            if all_passed
            else "self_test_failed"
        ),
        "exit_code": 0 if all_passed else 3,
        "synthetic_data": True,
        "actual_performance_measurement": False,
        "target_source_modified": False,
        "checks_total": len(checks),
        "checks_passed": sum(
            bool(item["passed"])
            for item in checks
        ),
        "checks": checks,
    }

    return report, 0 if all_passed else 3


# ------------------------------------------------------------
# Machine-readable output
# ------------------------------------------------------------

def emit_report(report):
    print(
        json.dumps(
            report,
            ensure_ascii=False,
            indent=2,
            allow_nan=False,
        )
    )


# ------------------------------------------------------------
# CLI entrypoint
# ------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description=(
            "Independent adversarial performance "
            "analyzer contract QA / r2"
        )
    )

    parser.add_argument(
        "--analyzer",
        type=Path,
        help="Path to the target Python analyzer",
    )

    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run built-in fake-analyzer regression tests",
    )

    arguments = parser.parse_args()

    if arguments.self_test:
        report, exit_code = self_test()
        emit_report(report)
        return exit_code

    if arguments.analyzer is None:
        parser.error(
            "--analyzer is required unless --self-test is used"
        )

    analyzer = (
        arguments.analyzer
        .expanduser()
        .resolve()
    )

    if not analyzer.is_file():
        report = {
            "task_id": TASK_ID,
            "version": VERSION,
            "window": WINDOW,
            "status": "contract_mismatch",
            "exit_code": 2,
            "analyzer": str(analyzer),
            "detail": (
                "Analyzer path is not a regular file"
            ),
            "cases_executed": 0,
            "synthetic_data": True,
            "actual_performance_measurement": False,
            "target_source_modified": False,
        }

        emit_report(report)
        return 2

    cases = build_cases()

    report, exit_code = run_suite(
        analyzer,
        cases,
    )

    emit_report(report)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())

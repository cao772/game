# GAME-WEB-TECHQA-ADAPTER-001 / r1 — schema adapter candidate

Status: **NOT_RUN**. Code and tests have not been executed in this request. Canon: not applicable.

## Exact read-only source pins

- r2 runner: Draft PR #5, commit `413a9e9ded41bf7694ed5d1265c5932d3e6fa60a`, `tools/test_perf_analyzer_contract_candidate.py`, Git blob `cbb692d806e05de2b5c31cde3b3921a88a738edb`.
- CSV analyzer: Draft PR #2, commit `cb0026ec668b96832efed5bf452a90548bc31c20`, `tools/perf_analyze_candidate.py`, Git blob `ba43a88df07f7e56d9d5f7e9bf436d4d821d3b1a`.

This is a **stacked Draft PR** based on `codex/techqa-r2` at the pinned PR #5 HEAD, not a change to either existing source file. Do not merge `main`.

## Grounded output contract

From the pinned analyzer source, stdout is a JSON object with
`task_id=GAME-WEB-PERF-002`, `version=r1`, `scope="CSV measured subset only"`,
`source`, `sample_count`, `stats`, `checks`, `not_measured`,
`measured_subset_status`, `status`, `full_scene_pass`,
`error_count`, and `errors`.

1. `measured_subset_status` is `PASS`, `FAIL`, or `INCOMPLETE`. It applies **only** to the eight measured CSV checks (frame P50/P95/P99, script P95, peak RAM, VRAM delta, draw calls, triangles). The analyzer uses nearest-rank percentiles; the remaining metrics use maxima.
2. `status` remains `incomplete`; `full_scene_pass` remains **false**, regardless of the measured subset. `not_measured` contains five fields: cold load, scene switch, dynamic lights, shadow lights, active NPCs, each with `value=null` and `status=NOT_MEASURED`.
3. On any bad CSV input, `error_count > 0`, measured values and `checks[*].value` remain null, check status is `INCOMPLETE`, and subset status is `INCOMPLETE`. Invalid measurements must not be filled with zero.
4. Exit code semantics are 0 (measured subset PASS), 1 (measured subset FAIL), 2 (invalid/missing CSV or file error). These are **not** the scene's acceptance status.

## Candidate behavior

- Uses the pinned r2 QA's `build_cases()` and `evaluate_case()`. It neither edits the runner nor the analyzer. Each of the original 15 synthetic cases invokes the analyzer **once**, inside a per-case temporary directory, with a 5-second timeout and no shell.
- Keeps the entire r2 case result under `original_qa_evidence`, including raw stdout/stderr, their base64 forms, exit code, timeout and input SHA256.
- Validates exact schema fields, eight checks, thresholds, stats/check internal consistency, null semantics for data gaps, unmeasured fields, and separate subset/full-scene semantics.
- Compares successful measured values with independently calculated nearest-rank/peak expectations from synthetic CSV, and flags a coherent but erroneous subset PASS as `wrong_subset_pass`, even with nonzero exit.
- An unknown schema, contradictory fields, missing evidence, mismatched values, or unsupported aggregate verdict is `inconclusive` (exit 4), never a full-scene PASS. Genuine CLI contract mismatch exits 2 without guessing alternate flags. Identified defects exit 1.
- A zero QA exit, `no_definitive_subset_defects`, says only that no definitive defect was found in the synthetic subset cases. It is **not a game benchmark** and **never certifies the full scene**.

## Codex acceptance plan — NOT_RUN

Run only after author permits execution:

```sh
python -m py_compile tools/test_perf_analyzer_schema_adapter_candidate.py
python tools/test_perf_analyzer_schema_adapter_candidate.py --analyzer /absolute/path/to/perf_analyze_candidate.py > adapter_report.json
```

Review evidence and verify all 15 cases, the baseline subset PASS, six bad-input INCOMPLETE results, eight measured over-budget FAIL results, full-scene incomplete/false for every case, and unchanged original stdout/stderr/base64/exit codes. Repeat with fake analyzers for contradictory check/status values, unknown fields, JSON formatting errors, timeouts, wrong subset PASS despite exit 1, and argparse exit 2; each must remain conservative.

Validation: **NOT_RUN**. Python 3.12 syntax: **NOT_RUN**. Target analyzer execution: **NOT_RUN**. Acceptance: **NOT_RUN**. CI: **NOT_RUN**. No real performance measurement or user-facing scene evaluation was performed.

## Limitations

The adapter is an intentionally pinned candidate for the PR #2 schema; updates require explicit review, not guesswork. It assumes that a deliberately supplied analyzer is trusted: Python standard library subprocess isolation does not prohibit target-internal network calls or child processes. The adapter reads no private novel, story, scene, or gameplay data, creates no shared interface, and does not alter canonical content.

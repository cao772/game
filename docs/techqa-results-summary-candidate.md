# GAME-WEB-MODULE-TECHQA-001 / r1

**Status: NOT_RUN**. No Python code, test, analyzer, CI or game was executed for this development task. Canon not applicable. Public technical material only.

## Read and pinned sources

- Draft PR #5, HEAD 413a9e9ded41bf7694ed5d1265c5932d3e6fa60a, tools/test_perf_analyzer_contract_candidate.py. Root summary fields: task_id/version/status/exit_code/synthetic_data/cases_planned/cases_executed/cases_skipped/defect_cases/results. Case evidence includes raw_stdout/raw_stderr, stdout_base64/stderr_base64, exit_code, timed_out, input_sha256, classification and defect.
- Draft PR #7, HEAD 482802ce44e2b14d5461969a7fb58d48c9bd8615, tools/test_perf_analyzer_schema_adapter_candidate.py. Each adapter result embeds original_qa_evidence (the r2 case) and adds measured_subset_status, full_scene_status, full_scene_pass, data_quality, error_count and schema_issues. Report source_pins also identify the analyzer HEAD cb0026ec668b96832efed5bf452a90548bc31c20.
- From the pinned analyzer source: eight CSV measured checks and five NOT_MEASURED scene gaps. Measured subset may be PASS/FAIL/INCOMPLETE. Full-scene status is always incomplete; full_scene_pass is always false. Exit 0/1/2 means measured subset pass/fail/input error, NOT full-scene approval.

## Deliverables

1. tools/perf_qa_results_summary_candidate.py: independent offline, standard-library JSON report aggregator. Does not import or invoke either PR's tool. Read-only on inputs; no shell, subprocess, network or game API. Optional output is an exclusively created new file (no overwrite).
2. tools/test_perf_qa_results_summary_candidate.py: 25 future synthetic unit acceptance cases, NOT_RUN.
3. This document: source pins, candidate contract, limitations and acceptance conditions.

The branch is stacked on Draft PR #7 (which itself is stacked on PR #5), not merged into main. No existing analyzer, QA runner, adapter, scene, novel, canon, or shared interface was edited.

## Candidate input and output semantics

Future CLI (not run): python tools/perf_qa_results_summary_candidate.py --report /path/to/qa-r2.json --report /path/to/schema-adapter.json --output /path/to/new-summary.json

Accept 1-32 UTF-8 JSON inputs, each at most 16 MiB. Duplicate JSON keys and nonstandard NaN/Infinity constants are rejected. Without --output the JSON summary goes to stdout. Only explicitly listed PR #5 r2 and PR #7 r1 structures are recognized. Other structures and malformed/missing files yield INCONCLUSIVE report units.

The summary has independent report units and per-case evidence, with observed counts, unresolved cases, report-level contradictions, separate confirmed defects, data-quality status, measured-subset status and coverage gaps. Same case IDs from two reports are **not** silently correlated as one execution. Original raw stdout/stderr, base64, exit code and SHA256 strings remain embedded and available for reviewers. Base64 bytes are checked against raw strings; input SHA256 can only be syntax-checked because the original CSV bytes are absent.

Synthetic baseline-subset PASS is not game performance; QA runner's generic verdict is not automatically translated to measured-subset PASS. Subset FAIL is not a whole-scene failure claim. Missing scene metrics, schema-unknown fields, contradictory statements, untrusted evidence and skipped cases cannot be filled with zeros or promoted to a success. Full-scene result is always NOT_ESTABLISHED/false in this summary.

Definitive defects are evidence-consistent wrong_pass/wrong_subset_pass, timeout, exception or format_error; uncertainties remain inconclusive and are counted independently. Report-level contradictions keep aggregate status inconclusive even when credible defect case counts are retained. A completed no-defect synthetic QA summary never constitutes a product performance certificate.

## Future acceptance cases (ALL NOT_RUN)

T01 baseline subset PASS but scene stays not-certified, five missing measurements present;
T02 missing NOT_MEASURED field stays inconclusive;
T03 false scene PASS claim rejected;
T04 raw/base64 disagreement blocks certainty;
T05 unknown task/version inconclusive;
T06 PR5 nonzero exit with explicit wrong PASS remains a defect;
T07 invalid-data quality distinct from measured results;
T08 PR7 wrong-subset PASS despite exit 1 remains a defect;
T09 unknown class inconclusive;
T10 schema_issues not ignored;
T11 identical case IDs from two reports remain separate;
T12 duplicate JSON keys rejected;
T13 JSON NaN rejected;
T14 non-synthetic claim inconclusive;
T15 corrupt evidence cannot prove defect;
T16 contradictory exit/status inconclusive;
T17 partially executed suite cannot report complete success;
T18 unknown extension fields preserved;
T19 claimed full-scene certification rejected;
T20 PR5 schema_unrecognized denotes uncertainty, not target failure;
T21 timeout requires explicit timeout evidence;
T22 format_error requires genuinely invalid JSON stdout;
T23 exception requires trace or signal evidence;
T24 CLI mismatch stays uncertainty, never an invented functional defect;
T25 malformed verdict/classification objects do not crash or become a PASS.

Future Codex commands only after explicit authorization (NOT_RUN now):
- python -m py_compile tools/perf_qa_results_summary_candidate.py tools/test_perf_qa_results_summary_candidate.py
- python tools/test_perf_qa_results_summary_candidate.py
- python tools/perf_qa_results_summary_candidate.py --report /path/to/report.json

## Limitations

All generated acceptance fixtures are synthetic, not actual game telemetry. No real run logs or private materials are included in this PR. Reports may carry private stdout/stderr: future operators must not publish real diagnostic content without authorization. Byte-integrity consistency does not independently authenticate provenance. The pinned JSON field semantics must be re-reviewed before any adaptation to newer analyzers. No connection to Notion, Drive, game scene runtime, CI gate or shared interface is approved. Python syntax check, 25 tests, smoke runs, analyzer execution, CI and archive are **NOT_RUN** for this request.

## Independent follow-on, GAME-WEB-MODULE-TECHQA-002 r1

New additive offline view candidate: `tools/perf_qa_results_views_candidate.py`; future 30-case synthetic acceptance module: `tools/test_perf_qa_results_views_candidate.py`; scope/filters/evidence-index rules: `docs/techqa-results-views-candidate.md`. This does not change the existing aggregator contract, source parser, prior tests, target analyzer or any shared interface. All execution and acceptance statuses: **NOT_RUN**. Do not infer full-scene performance from filtered measured-subset records.

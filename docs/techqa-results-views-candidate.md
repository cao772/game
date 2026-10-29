# GAME-WEB-MODULE-TECHQA-002 / r1 — QA report views and missing-evidence index

**Development status: NOT_RUN.** Only source authoring and GitHub read/write have occurred. No Python execution, unit tests, analyzer, QA runner, CI, or actual game telemetry. Canon does not apply.

## Provenance and scope

Read Draft PR #16 at HEAD `3570d7721a9ad142038471d6facc8a9c37ff2ee8` before authoring. Its original 3 files are retained. Changes are additive **on the same independent branch** `codex/techqa-results-summary-r1`, without modifying PR #5, PR #7, PR #2, main, game scenes, shared interfaces or private story materials.

Original PR #16 summarizer: `tools/perf_qa_results_summary_candidate.py`. It derives conservative per-case verdicts from synthetic JSON reports, retains embedded raw evidence, and does not certify full-scene performance. This enhancement imports only that existing offline Python module; it **never executes** the analyzer or old QA tools.

New files:
- `tools/perf_qa_results_views_candidate.py`: offline query/report-view CLI, evidence indexes, structured summary.
- `tools/test_perf_qa_results_views_candidate.py`: **30 future synthetic acceptance cases**, all NOT_RUN.
- This document.

## Future invocation (NOT_RUN)

```sh
python tools/perf_qa_results_views_candidate.py \
  --report /private/location/qa-report.json \
  --report /private/location/adapter-report.json \
  --evaluation inconclusive \
  --missing-metric cold_load_s \
  --output /private/location/new-result.json
```

Other repeatable filters (use kebab-case flags): `--subset`, `--quality`, `--classification`, `--case-id`, `--report-type`, `--reason`, `--missing-state`, `--evaluation`. The reason filter matches an **exact** code from `issues`, `report:<issue>` or `schema:<issue>`; it is not a fuzzy search. Within one filter, repeated values are OR; separate filters compose as AND.

Maximum 32 input reports. The original summarizer independently bounds each report to 16 MiB. No untrusted output formats are guessed into PASS. `--output` creates a new file exclusively; no overwrite. By default, stdout contains a JSON view. Private input filenames are replaced by stable aliases (`input_01`, etc). **Never supply real private logs to GitHub.**

## Structured output (candidate, not a shared interface)

- `status` and `source_summary`: source-wide verdict, **never reclassified from filtered rows**, along with total observed cases, confirmed defects, inconclusive cases, unresolved source reports, report-level issues and skipped cases.
- `selection_summary`: counts only the filtered set, including evaluation, measured-subset verdict, data quality, source type, missing-state and missing-metric distributions. An empty selection is `empty_selection`, not a new PASS.
- `selected_cases[]`: case classification, evaluation, explicit quality signal, measured-subset value, per-scene gap descriptors, evidence integrity confidence, evidence pointer and hashes.
- `evidence_index.unmeasured[]`: **five entries per selected case** for cold-load, scene switch, dynamic lights, shadow lights and active NPCs. These are documentary gaps, **not measured values**. `documented_not_measured` is recorded only if the pinned adapter's analyzer stdout explicitly contains `value:null` and `status:NOT_MEASURED`. Generic PR #5 QA reports instead produce `not_reported`. Contradictions yield `inconsistent` or `unknown_evidence`.
- `evidence_index.data_quality[]`: invalid/unknown input, error count and error **codes** (no raw diagnostic detail by default), separate from failed measured performance checks.
- `evidence_index.uncertainty[]`: inconclusive case reasons and their stable pointers. `evidence_index.confirmed_defects[]`: evidence-consistent identified defects, separate from uncertainties.
- `full_scene.certification=NOT_ESTABLISHED` and `full_scene.full_scene_pass=false` always. All inputs are **synthetic QA artifacts**, never proof of actual game performance.

**Evidence references** are JSON Pointers such as `/reports/0/cases/1/evidence/original_qa_evidence/stdout_base64`, addressing the **unfiltered** original aggregation structure from PR #16. Filtered case positions are not used to redefine these pointers. Because default views omit sensitive raw content, reviewers can reprocess the same source reports or explicitly use `--include-evidence` when working privately. This opt-in embeds full original case evidence and may include private stdout/stderr; it must not be posted publicly.

`stdout_sha256` is calculated over decoded stdout bytes, when present. It verifies a byte-string representation, not its origin; `input_sha256_claim` is **not recomputed** because original CSV data are not included. No screenshots, full-scene metrics, private scene files or hidden data are generated.

The distinction between source-wide and filtered counts is mandatory: requesting only successful cases cannot hide unresolved cases/defects in the overall verdict. Selection distributions describe **what was selected**, not independent acceptance decisions.

## Future acceptance cases — NOT_RUN

The dedicated test module defines T01–T30 covering:

1. Global defect status untouched by successful-row filter; subset-only PASS never becomes scene PASS.
2. Combined OR/AND filters by subset, evaluation, type, case ID, reason, quality, missing metric and evidence state.
3. Five indexed unmeasured scene metrics, PR #5 unknown coverage, missing keys and contradictory NOT_MEASURED entries.
4. Data-quality error code extraction without raw private details, empty selection semantics and unexecuted cases.
5. Default raw evidence exclusion and explicit opt-in preservation.
6. Evidence pointer stability, stdout SHA256 verification, two reports containing the same case ID remaining distinct.
7. Uncertainty index and source-wide uncertainty preservation, including an unrecognized report.

Detailed case names and assertions are in the test module. Future Codex commands **only when execution is authorized**:

```sh
python -m py_compile tools/perf_qa_results_views_candidate.py tools/test_perf_qa_results_views_candidate.py
python tools/test_perf_qa_results_views_candidate.py
```

Do not report any test PASS until run evidence exists. Acceptance status for every listed case: **NOT_RUN**.

## Limitations and review requirements

1. This is a new independent candidate, not an approved shared schema or product API. PR #16 and its pinned PR #5/#7 inputs may change; re-review the binding whenever they do.
2. No actual scene sample data is available. Measured-subset statuses refer exclusively to synthetic CSV test outputs. The five missing scene indicators are evidenced only as missing / unreported / contradictory, not zero.
3. Internal evidence checks cannot authenticate a report. Missing or inconsistent evidence remains inconclusive. Case evidence and hash strings are preserved or referenced, not inferred.
4. Filters cannot make an uncertain source successful. The module never changes the global QA verdict based on the filtered selection.
5. Input files may contain secrets. Raw evidence is omitted by default, diagnostic error details are excluded from the quality index, and input paths are represented as aliases. The opt-in to raw evidence must be handled privately.
6. The parent summarizer has its own conservative limitations, and neither module is a network sandbox for any other tool. This views module itself does not run subprocesses or access the network.
7. Testing, Python syntax checks, CI, analyzer execution, real benchmark and Notion/Drive archival: **NOT_RUN** for this development request. No main merge.

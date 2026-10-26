# Performance analyzer QA candidate r2

This standalone standard-library harness runs `python analyzer.py input.csv` in an isolated temporary directory for each synthetic case. It limits each target to15 cases with a5-second per-case timeout and retains raw stdout/stderr/exit evidence.

The r2 fixes prevent explicit overall PASS on invalid or over-budget input from being hidden by a nonzero target exit. Valid JSON containing a `usage:` note is parsed as data instead of being mistaken for a CLI usage failure. Unknown or contradictory verdict fields remain inconclusive.

Validation on Windows/Python3.14.3: all9 embedded fake-analyzer regression checks passed, exit0, with DeprecationWarning treated as an error. All6 independent acceptance scenarios passed, including both exact r1 defect reproductions, unknown-schema and actual-schema conservative stopping, always-PASS detection and CLI mismatch. The actual analyzer's source hash was unchanged before/after. Source also parses using Python3.12 grammar; Python3.12 runtime was not executed in this round.

The current analyzer's `measured_subset_status`, `status=incomplete`, and `full_scene_pass=false` schema is deliberately not guessed. It returns schema_unrecognized/exit4 after the baseline. This is not target functional acceptance, a benchmark, or full-scene certification. A future explicit schema adapter and separate real performance capture remain outstanding.

Run `python tools/test_perf_analyzer_contract_candidate.py --self-test` for the embedded checks. Use `--analyzer` only with a reviewed trusted target; the harness does not sandbox a target's own network or child processes.

Original source SHA256:87da1765ae6b8615cbc46f5188ba54c18e83b26eb45f2a0adb7c8a1a4961ea9b. Raw web evidence and execution reports remain in authorized private archives. The response's trailing prose was interrupted by a site challenge after the complete executable code block had been received; no retry or challenge solving was performed.

# Candidate prototype validation

These files are isolated technical candidates, not an approved game architecture or shared interface.

- `prototypes/save_candidate.py`: local Python execution returned `PASS: 3 tests`; 177 physical lines; all 12 assertion expressions from the prior candidate retained. Pausing the free-world clock during a historical chapter remains an experimental policy.
- `tools/perf_analyze_candidate.py --self-test`: local execution returned `SELF_TEST_OK: synthetic inputs only; not a benchmark`. Invalid or incomplete CSV inputs do not receive a passing measurement status. Missing whole-scene measurements remain unmeasured.

Run from the repository root:

```text
python prototypes/save_candidate.py
python tools/perf_analyze_candidate.py --self-test
```

No real scene performance benchmark has been run. Godot scene and event candidates remain in the authorized private evidence archive; they are not included in this public change. This change is submitted for review and must not be automatically merged.

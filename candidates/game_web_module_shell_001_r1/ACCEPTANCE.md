# GAME-WEB-MODULE-SHELL-001 r1 — future acceptance inventory

**Every case below: NOT_RUN.** Test source is authored but not executed.
Do not report PASS, visual correctness, CI or source compatibility from file
presence. Execution requires a separate author/Codex instruction.

| ID | Future test / method | Expected result | Status |
|---|---|---|---|
| S01 | Instantiate standalone scene | Initial page = home | NOT_RUN |
| S02 | Select round via shell method | Page and text switch | NOT_RUN |
| S03 | Select unknown page | Return false, retain previous | NOT_RUN |
| S04 | Select prompt/profile/bindings | Four slots navigable | NOT_RUN |
| S05 | Inspect local synthetic adapter presence | Known slots present | NOT_RUN |
| S06 | Navigate back to home | Overview without preview action | NOT_RUN |
| S07 | Attempt to register unknown slot | Reject without side effect | NOT_RUN |
| S08 | Attempt to inject adapter missing methods | Reject without replacing old adapter | NOT_RUN |
| S09 | Remove round slot | Missing slot reported, no fallback to real PR | NOT_RUN |
| S10 | Open removed slot | Preview button disabled; missing status | NOT_RUN |
| S11 | Install fresh synthetic round adapter | Preview button enabled and view refreshed | NOT_RUN |
| S12 | Return to home | Preview button hidden | NOT_RUN |
| S13 | Activate mock request on each slot | Only local response, no real action/snapshot change | NOT_RUN |
| S14 | Press Tab / Shift+Tab, Space, Enter | Usable keyboard menu focus and actions | NOT_RUN |
| S15 | Escape on any page or prompt-like view | No unapproved cancellation/priority change | NOT_RUN |
| S16 | Pause scene; attempt mock request | Blocked, no simulated_request emission | NOT_RUN |
| S17 | Remove native window focus | Mock action blocked; regain focus safe | NOT_RUN |
| S18 | Resizing 1024x640, 960x680 and narrow viewport | Readability/no critical clipping | NOT_RUN |
| S19 | Inject bogus preview reply | Fallback text; no crash and no game write | NOT_RUN |
| S20 | Inspect Git diff against main | Only new files under candidate folder | NOT_RUN |
| S21 | Inspect Godot project import paths | No refs to other Draft PRs or external assets | NOT_RUN |
| S22 | Compare future combined focus policy against #6/#10/#15 | Do not combine until author approves arbitration | NOT_RUN |
| S23 | Inspect filesystem / InputMap before and after demo | No snapshot/config write and no global mapping changes | NOT_RUN |
| S24 | Inspect source / UI strings | Only synthetic text, no manuscript or character lore | NOT_RUN |

S01–S12 are *intended* to be covered by `verify_shell_candidate.gd` when
authorized. The rest require additional native/manual checks or future tests.
Even for S01–S12, an authored assertion is NOT evidence it works.

### Proposed future proof bundle

- Exact commit SHA / reviewed PR refs and Godot 4 minor/platform.
- Command and sanitized stdout/stderr, exit status, with date/operator.
- Native screenshots for overview, each page, missing-slot view, keyboard focus,
  narrow viewport and focus loss; no captured private information.
- Evidence of no file writes / InputMap mutations, and absence of side effects.
- Record each result separately as PASS/FAIL/BLOCKED *after* execution, with
  exact GitHub commit and test version. Until then **NOT_RUN**.

### Status

`task_id=GAME-WEB-MODULE-SHELL-001`;
`version=r1`; `input=Draft PRs #6/#10/#14/#15 (unapproved)`;
`scope=standalone shell candidate`; `validation=NOT_RUN`;
`author_review=PENDING`; `main_merged=NO`;
`Notion=NOT_WRITTEN`; `Drive=NOT_WRITTEN`.

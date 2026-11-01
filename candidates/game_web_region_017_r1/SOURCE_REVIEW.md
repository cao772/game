# GAME-WEB-REGION-017 r1 — exact source review note (read-only)

- Repository: `cao772/game` (public). Main: `533b11f50c0d359cd0a5424d5216b0145727699a`; repository main contains only README at initial baseline.
- Actual open Draft PR #23: `codex/game-web-flow-region-004-r1`, HEAD `553c9093a2b9cd54cb6fb4a1c8928472035141b0` at review, target `main`. Read live PR metadata/changed-file list, README, REGION_006_DESIGN/INTEGRATION/ACCEPTANCE, `flow_demo.gd`, `flow_model_candidate.gd`, `navigation_candidate.gd`, `focus_recovery_candidate.gd`, `feedback_journal_candidate.gd`, `synthetic_targets.json`, `project.godot`, `main.tscn`.
- Distinct baseline semantics: PR #23 is a separate Godot 4 synthetic 3D three-cube interaction/navigation and focus trial. It explicitly lacks approved real collision/occlusion maps, real scene, shared input/save/event or canonical game assets. No runtime tests were reported there.
- This candidate adds **grid occlusion and BFS routes, scene switcher, record-correction and fallback** in a standalone directory. It does not import/modify/approve PR #23 or its pinned prompt. It makes no claims about the original novel or unfinished/private N-series narrative.
- All route dimensions, visuals, source claims, character set and keybinding choices are public synthetic design assumptions. Source upload does not establish runtime behavior.
- PR #23's HEAD may change later. Only the exact reviewed SHA is evidence for this note; review again before any integration.
- NOT_RUN by user request: no Godot/parser/tests/CI/GUI/performance execution.

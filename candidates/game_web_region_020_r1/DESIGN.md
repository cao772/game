# DESIGN｜N20 static reasoning, actions and limitations

## Why separate from PR #27
[PR #27](https://github.com/cao772/game/pull/27) is a *state evidence card / recovery guidance UI*. N20 instead validates **source catalog structure before any scene is loaded**. It does not read PR #27 data, depend on PR #27 branches or implement evidence-card behavior. It writes only a new isolated folder.

## Static review of PR #26
PR #26's `region_model.gd` has an internal `_valid_catalog(raw)` that returns a **Boolean**. It checks a root Dictionary, exact version, three entries, distinct A/B/C IDs, title length, two Boolean claims, row dimensions, allowed glyphs, perimeter walls, one start and one target. The loading path tries optional `res://synthetic_regions.json`; invalid or missing data is replaced wholesale with an embedded A/B/C dictionary and a generic warning. It does **not** emit which field failed or a suggested fix. Source file does not assert route reachability or true visibility as structural requirements; its separate model uses BFS and an approximate line-of-sight sample after loading.

## N20 candidate architecture
- `region_validator.gd` is a **RefCounted pure structural checking component**, with `validate_variant` and `validate_json_text`; no filesystem, game state, user identity, network, telemetry, or time dependencies. Parsing code is authored for future use but **not executed in this task**.
- Each issue is a Dictionary `{severity, code, path, message, action}`; results return `ok/status/errors/warnings/suppressed/issues/catalog/verification`. The `catalog` is a deep copy **only when accepted**; on rejection it is empty. The explicit `verification: NOT_RUN` field denotes this authored artifact's untested status, not game runtime truth.
- Syntax errors use the Godot JSON parser's future error-line/message reporting; structure errors are grouped with precise paths and repair instructions. Warnings do not block acceptance; errors and suppression do.
- `catalog_recovery.gd` wraps a **fixed local optional source** with recovery modes `SOURCE_ACCEPTED`, `FALLBACK_SYNTHETIC`, `BLOCKED`. Bad source does not get silently reshaped; the original problem report is preserved while a known synthetic fallback is used. No original source overwrite.
- `synthetic_boundary_cases.gd` creates *only in-memory invented failures*. These are specimen candidates, not a test runner, and no execution was performed.
- `diagnostics_demo.gd` is an isolated Control panel for future human viewing of errors/fixes; it does not expose file upload or real path selection.

## Choice rationale
1. **No auto-repair:** arbitrary filling a missing T, closing a wall, or coercing `"true"` to Boolean would destroy evidence of malformed input. Show the error, then use clearly labeled synthetic fallback.
2. **Nonfatal extra-key warning:** source Boolean validator ignored unrecognized fields. Rejecting them would silently introduce a breaking change; flag typo risk instead.
3. **Do not certify C as navigable:** a valid scene may have an isolated goal. Structural checking is not path validation or player safety certification.
4. **Bounded inspect/error count:** designed to avoid runaway reports on bad input; current caps are hypotheses, not measured safe capacities.
5. **Keep source pinned:** `synthetic_regions.json` is the same PR #26 public blob. The embedded fallback is structurally equivalent A/B/C content, marked as fallback rather than claiming an exact file restoration.
6. **No integration:** changes to a shared loader, an event format, main, another PR or world state would exceed authorization. This code cannot be assumed to be drop-in or compatible with currently unapproved interfaces.

## Explicit unresolved risks
- Not runtime-checked: script syntax/API, JSON parse error reporting, Control layout/labels, return types and optional file behavior. No compatibility version other than Godot 4 candidate.
- Structural validation cannot establish BFS correctness, visibility, physics collision, memory use, accessible UI, safe map layout or actual script readiness.
- The candidate 16000-character cap and maximum 48 issues are assumptions, not telemetry or observed benchmarks.
- Some malformed inputs may yield multiple dependent diagnostics (e.g. grid row length and missing target); remediation must follow actual field path, not diagnostic count alone.
- The `notice` field is not a secured free-text provenance claim. This standalone demo ships only public synthetic notices; integrating arbitrary user text would require separate safeguards and approval.

**All tools to run the generated project are intentionally unused. Status: NOT_RUN.**

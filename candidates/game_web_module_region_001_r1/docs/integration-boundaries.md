# Isolation contract & review notes — proposed, NOT approved

## Origin and scope

Public Godot 4 technical candidate for a generic prompt widget, based on
the request GAME-WEB-MODULE-REGION-001 r1. The only purpose is displaying
and hiding UI for an **externally supplied placeholder target**. This
candidate does not resolve real interactables, move a character, open a
door, mutate a timeline, persist state, or explain narrative phenomena.

Source review performed against the independent Draft PR #6:
`candidates/game_web_integrate_001_r1/input_router_candidate.gd`
and `integration_candidate.gd`, using the exact draft branch instead of
the `main` branch (which contains only README). No code copied into the
new module. Existing Draft PRs are not modified.

## Module ownership

- `interaction_prompt_candidate.tscn`: visual component and Button focus.
- `interaction_prompt_candidate.gd`: current placeholder, focus
  restoration, explicit visibility, escape when prompt-focused, emitted
  signal, native window/pause guard and test seam.
- `demo.*`: publicly safe *fake targets*; never game content.
- Future production host, **not provided**, owns target discovery,
  interaction range, collision, narrative, event consequences, and input
  arbitration. The host may ignore or reject a signal.

Signals and callable functions are **candidate-local**, not a shared
interface. A future host must not assume any compatibility guarantee.

## Input and focus rules

- The prompt has two focusable Buttons. Godot handles Enter/Space on
  focused Buttons and Tab focus navigation through explicit neighbor paths.
- A shown prompt requests action Button focus; when hidden it restores
  preexisting outside focus only if that Control remains valid and visible.
- If no valid prior focus owner exists, it does not fabricate one.
- Escape is read from `_unhandled_key_input` only while the prompt holds
  focus, and is marked handled. This may require arbitration with the
  separate Draft PR #6 Escape-to-cancel behavior; no binding is approved.
- There is no 1/2/3/R key binding here. Existing INPUT r1 routes remain
  untouched. This module does not directly call PR #6's integration
  coordinator.
- Request emission is blocked while hidden, paused or without native
  window focus; the injectable test override is not a security boundary.

## Reuse boundaries

- Target ID is a StringName provided by caller; labels are plain Label
  text, with empty/very long captions rejected.
- No asset/plugin/network dependency. Native Godot 4 Control and signals.
- The component is a local overlay, not a singleton or autoload.
- Repeated show swaps target; repeated hide is safe; a request does not
  auto-hide, leaving lifecycle decisions with the caller.
- UI position/size are demonstration defaults, not author-approved product
  style or a final accessibility design.
- Multiple concurrent prompt instances and modal stack focus ownership
  are not supported or validated; host must arbitrate.
- No claim about actual screen reader announcements, IME, viewport scaling,
  pause UI behavior or pixel-perfect renderer output until native QA.

## Provenance, restrictions and unresolved decisions

Input: this user request plus inspected public technical PR #6 sources.
No personal manuscript, existing scene file, or private Notion/Drive asset
is included; nothing is written outside the additive `candidates/`
directory. The branch and PR are Draft, no merge to main.

Unresolved owner decisions:
1. Exact focus priority between game controls and prompt when both appear.
2. Whether the prompt should be modal and whether Escape dismisses or
   delegates to an overarching input router.
3. Visual style, localization, accessibility and high-DPI requirements.
4. Whether a future official target-discovery API should exist.
5. Whether action signal should auto-close (candidate defaults to no).

All automated/manual results are **NOT_RUN** pending Codex verification.

---
## Extension boundary — GAME-WEB-MODULE-REGION-002 r1

- The multi-target list is explicitly passed as generic placeholders; no
  discovery of real scene instances, collider IDs, character names or lore.
- List selection changes UI only. `interaction_requested` remains local
  and contains only the currently selected generic target ID.
- Theme configuration is isolated to the prompt's per-node overrides;
  there is no global theme, InputMap, project setting or external asset
  modification. Style is ephemeral and not persisted to disk.
- Keyboard focus states reflect the live Viewport owner; no claim about
  screen-reader support or OS-level native focus before manual validation.
  Escape / PageUp / PageDown are consumed only while this prompt owns focus.
- Integration priorities with Draft PR #6 INPUT/STATE routing, modal
  stacking, IME, localization and accessibility remain owner decisions.
  No shared interface is ratified by adding these callable functions.
- This follow-on changes only files in the existing PR #10 candidate path;
  main and all other PRs/candidates are untouched. NOT_RUN.

---

## GAME-WEB-CONTINUE-REGION-003 r1 scope note — NOT_RUN

Only a new local `synchronize_targets` method, read-only UI snapshots,
deferred change notification and public placeholder fixtures were added.
The existing scene/signal behavior remains **candidate-local** rather
than a formal shared interface. Reordered IDs are retained by exact
placeholder identity; removal falls back to index, not narrative meaning.
External direct editing of `visible`, child button focus/labels or
multiple simultaneous instances is outside the current method contract.

The demonstration's JSON contains only generic A–E placeholders.
It has no unpublished text, character, parentage, story conditions,
event bus, save core, file upload, telemetry or global InputMap hooks.
The module does not read real scene targets.

Focus return on the native window and actual Tab routing, screen-reader
accessibility, DPI/IME behavior and possible keyboard ownership conflicts
with separate Draft PR #6 remain unresolved for later Codex/owner QA.
Do not merge `main` or interpret the new symbols as an approval.

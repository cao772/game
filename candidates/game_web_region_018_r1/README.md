# GAME-WEB-REGION-018 r1 — Synthetic A/B/C accessibility & input candidate

**DRAFT / NOT_RUN / PUBLIC SYNTHETIC FIXTURES ONLY / NOT CANON / NO SHARED INTERFACE APPROVAL**

This is a complete, standalone **Godot 4 GDScript** project proposal built from a *read-only inspection* of [Draft PR #25](https://github.com/cao772/game/pull/25), `codex/game-web-region-017-r1` at commit `8372c1fe5f6471ec6af788b65b68fa54fe7db65a`. All source is placed in a **new** `candidates/game_web_region_018_r1/` folder and branch, based on `main` `533b11f50c0d359cd0a5424d5216b0145727699a`. The branch neither updates PR #25 nor imports it at runtime. No existing file/main/shared interface is changed. **This is not a tested prototype.**

## Fully included sources
- `project.godot`, `main.tscn`: standalone project entry.
- `synthetic_regions.json`: **identical pinned public blob** from PR #25, with synthetic A/B/C and schema `public-synthetic-region-017-v1`. Keeping its version is intentional; this candidate adds presentation behavior without asserting a new shared fixture schema.
- `region_model.gd`: prior synthetic grid/reachability/line-of-sight/record correction model, extended with bounded local undo for movement and correction, explicit route-preview clear.
- `map_view.gd`: synthetic grid drawing with **non-color symbols** `# . : S T P`, bold current/focus outlines, optional purely decorative player-outline pulse (default **OFF**).
- `region_demo.gd`: independent GUI with A/B/C selector, text-size selector (100/125/150%), motion selector (Off/Slow/Normal), complete keyboard-operable movement/inspect/correct/undo/reset controls, text map and recovery messages, visible current-focus label and window blur guard.
- `DESIGN.md`, `KEYBOARD.md`, `SOURCE_REVIEW.md`, `ACCEPTANCE.md`: design decisions, provenance, precise keyboard/recovery paths, future-only tests.

No fictional characters, geographic names, actual story text, unpublished world data, privately sourced coordinates, pictures, sound, external fonts, custom shaders, real game scene, event bus, save integration or third-party service.

## User flow (future behavior, NOT_RUN)
1. Select **A**, **B** or **C** with the native choice control. Switching resets **only local synthetic state**, including undo and correction history.
2. **Tab / Shift+Tab** through native controls. The four visible movement Buttons make the complete loop possible without a mouse or map focus. Alternatively explicitly focus the grid, then press WASD/arrows one cell per non-repeating key event. **Escape** releases grid focus. The current focus is named in text; a white outline is extra, not the only cue.
3. **Preview to T**, **Preview to S**, or click an open tile. The route is both drawn with ':' markers and rendered in a full textual row map. Preview never moves the marker.
4. **Inspect** derives path reachability and grid-sampled line of sight. The original claim is shown separately. **Correct local record** is a second explicit action; it never changes JSON. **Undo last movement or correction** restores only the locally reversible fields and forces reinspection.
5. If T is blocked (C), explicit text says it is unreachable, and **Return-to-S preview** remains accessible. Wall hits leave the marker in place and show a recovery hint.
6. Text scale and decorative motion are independent. Dynamic outline animation adds **no information** and defaults to **off**. Static chars and public status text are authoritative.

## Missing resources / conservative downgrade
The PR #25 model supports versioned JSON input validation with atomic fallback to an **embedded equivalent synthetic A/B/C catalog**, clearly surfaced as a warning. A bad, unreadable, absent or schema-mismatched JSON cannot trigger importing real content or partial records. This project needs no custom font, texture, audio or animation asset. If **required** `.gd` scripts, `main.tscn` or Godot runtime itself are missing, the project cannot honestly recover in-app: this is a **hard blocker** for future import rather than a silent fake success. Default text size and motion are in code; there is no optional settings file.

## Keyboard quick guide
- `Tab` / `Shift+Tab`: move among standard controls; `Enter` or `Space`: activate focused Button.
- Four on-screen **move** Buttons: full no-mouse path while UI owns focus.
- Map owns focus only on explicit click or **Focus grid** Button: `W A S D` / arrows move one passable tile; `Esc` leaves map focus.
- Native window loses focus: movement is blocked. On return, release **all eight** mapped movement keys once; the system never resumes movement or confirms correction automatically.
- `Undo` reverses the last successful movement or explicit claim correction (up to 16 local snapshots). `Reset` resets local state but retains current text/motion preference for that session.

See [KEYBOARD.md](KEYBOARD.md) for a complete keyboard-only scenario and limitations.

## Source/run status
**NOT_RUN by author instruction:** no Godot binary/editor/import, parser, code execution, headless/UI test, native keyboard/focus check, screenshots, screen reader audit, CI, benchmarks or performance work. GitHub source/PR readback only establishes submitted code, not Godot compatibility or accessibility conformance. Source is subject to owner/Codex review, and must remain Draft.

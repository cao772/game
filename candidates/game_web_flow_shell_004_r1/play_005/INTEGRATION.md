# Module integration decisions — PLAY-SHELL-005 r1

**Proposal only / NOT_RUN / author final acceptance pending.**

## Composition and navigation

```text
Godot project.godot (this PR branch only)
  └─ play_005/play_entry.tscn → PlayShell005 (Control)
       ├─ FlowEntry: existing PR #24 shell, unchanged
       │    └─ fixed sidebar + appended five explicit navigation buttons
       └─ Play005Screen (one visible at a time; closes to main menu)
            ├─ region   → SubViewport → pinned #23 Node3D graybox
            ├─ event    → local fixed-fixture PR #18 *demonstration* model
            ├─ saves    → pinned #20 read-only SnapshotBrowser Control
            ├─ chars    → pinned #21 list/detail Control
            └─ input    → pinned #19 backend, memory-only form
```

The original PR #24 `FlowEntry` remains the sole menu shell. It is
hidden only during an explicitly opened play module; reopening restores
it. The outer wrapper does **not** inject into its private module
registry or assert compatibility with a shared interface. New buttons
are attached to a verified sidebar node in its own source snapshot.
If that node cannot be found, the original shell remains intact
and the extra destinations are unavailable (not guessed).

The overlay owns the child lifetime; each navigation unmounts the last
instance, then creates one new fixed resource. Any missing resource,
wrong root type or missing callable interface gets a visible BLOCKED
fallback. It does not attempt remote fetch, filesystem-wide discovery,
implicit save restoration or fallback to game state.

## Region → event → save decisions

- **Region confirmation gate:** only a PR #23 `flow_snapshot()` with
  `loaded=true`, `confirm_count>=1`, non-empty `last_confirmed`
  permits explicit transition. This does not interpret the target ID.
- **Event selection:** PR #18 fixture records are exactly EVENT_START,
  EVENT_NEXT, EVENT_END. The local GDScript model verifies those
  local files and follows an explicitly selected action or configured
  `@ignore`. Terminal/null is represented locally as terminal, not
  an actual world state transition. Original PR #18 Python checker
  is not imported; this demo is **unchecked** by PR #9 and is labeled
  so in the UI and event state.
- **Save browser:** separate explicitly opened PR #20 scene; never
  creates or stores a snapshot from event choices. No automatic scan.
  A real `user://` path is not provided or inferred; users may
  manually provide one during future authorized native tests.

## Why these choices

| Decision | Reason | Alternative rejected |
|---|---|---|
| Keep PR #24 shell and add outer navigation overlay | Avoid rewriting its candidate-only APIs/behavior | Editing existing shell menu and shared contracts |
| Pin and copy public source into isolated vendor subdirs | Standalone resource closure; original Drafts stay unchanged | Assuming all unmerged branches are in one working tree |
| Host #23 Node3D in a bounded SubViewport | Allows visual connection without rewriting its graybox scene | Converting a 3D scene to a 2D screenshot |
| Require explicit region confirmation and event navigation | There is no approved target→event mapping | Guessing story/production event relationships |
| Read original #18 fixture graph in Godot, label checker NOT_RUN | Python checker depends on PR #9; no Python inside Godot | Pretending checker parity or executing external Python |
| Mount #20 only as read-only UI | Its own model exposes guarded, explicit manual inspection | Creating or importing actual saves |
| Reuse #21 list/detail component | Its public fixture loader and profile contract exist | Inventing profile metadata or identity |
| Expose only PR #19 backend's memory methods | Its full UI has save/migrate actions; input owner not approved | Exposing accidental disk persistence |
| Fail visibly and preserve return navigation | No silent success when resources/interfaces are absent | Creating fake mock proof of integration |
| Source-only acceptance | User explicitly prohibits running any code/tests | Claiming runtime/CI PASS |

## Explicit design gaps for author final review

- Whether target confirmations should have an event mapping, and who
  owns that mapping. No mapping exists in this submission.
- Which version of an event checker should become a common runtime
  input, and how signed/validated fixtures enter the game.
- Any real save format/lifecycle, author-approved character data
  permissions, keyboard priority, and Godot version targets.
- Native UI behavior, viewport scaling, accessibility, resource import,
  keyboard focus, and performance. Every one remains NOT_RUN.


## Amendment — SHELL-006 r1: explicit *candidate* mapping, not canon

The earlier statement "no mapping exists" described PLAY-SHELL-005
before SHELL-006. The new `play_006/synthetic_target_event_map.json`
**proposes** three relationships only between public placeholder IDs and
existing public EVENT_* fixture IDs. These relationships remain unapproved,
non-canonical and have no gameplay or save effects.

The region→event button now uses strict fixed-file validation, an actual
`flow_snapshot()` confirmation and atomic staging of a fresh local event
preview; invalid candidates are BLOCKED with no default substitution.
Back-navigation reconstructs region, preserves event trace only when
returning from saves, and clears mapping state upon main-menu return.

Implementation and rationale:
[play_006/DESIGN.md](../play_006/DESIGN.md). **NOT_RUN**.

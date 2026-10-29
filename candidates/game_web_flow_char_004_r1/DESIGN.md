# GAME-WEB-FLOW-CHAR-004 r1 — implementation and decisions

**Independent technical candidate / Draft / NOT_RUN / no approved shared interface or story data.**

## What is implemented

A standalone Godot 4 project containing a functional source-level list/detail
flow around the **exact unmodified public technical rendering components**
reviewed from Draft PR #14. This flow has no gameplay, save, original text,
camera, character model, or canonical persons.

Structure:

\`\`\`
flow_demo.tscn (self-contained synthetic demo)
  └── profile_flow_candidate.tscn   [Control, embeddable]
        └── profile_flow_candidate.gd
              ├── profile_flow_model_candidate.gd (atomic in-memory route/model)
              ├── list UI + filter + focusable record buttons
              ├── back / exit-to-host signals
              ├── dynamic detail loading / fallback / retry
              └── pinned PR #14 character_profile_panel.tscn
                     └── pinned profile validator + text/scroll helpers
\`\`\`

New implementation:
- \`profile_flow_model_candidate.gd\`: authoritative in-memory list/detail
  state, read-only summaries, ID lookup, filtering, validation, deep copies.
- \`profile_flow_candidate.gd\` and \`profile_flow_candidate.tscn\`: responsive
  master/detail UI, keyboard-accessible native controls, safe panel mount,
  retry/error status, explicit back and exit-request signal.
- \`flow_demo_candidate.gd\` and \`flow_demo.tscn\`: independent demo using only
  the pinned local fixture; displays an exit notice when a host exit is requested.
- \`shell_profile_adapter_candidate.gd\`: metadata/mock adapter matching the
  _observed_ #17 shell-private RefCounted signature; no live UI dispatch.
- \`verify_profile_flow_candidate.gd\`: future-only automated assertions.
- \`project.godot\`: standalone demo project.
- \`README.md\`, \`DESIGN.md\`, \`ACCEPTANCE.md\`, \`SHELL_HANDOFF.md\`:
  installation, decisions, test design, integration limitations.

Pinned unmodified technical sources/fixtures copied within this directory:
\`character_profile_panel.gd\`, \`character_profile_panel.tscn\`,
\`profile_contract_candidate.gd\`, \`profile_scroll_navigation.gd\`,
\`profile_text_layout_candidate.gd\`, \`preview_panel_resource_candidate.gd\`,
\`placeholder_fixture_loader_candidate.gd\`, \`placeholder_profiles.json\`,
\`data_contract.schema.json\`. Each copy is the same Git blob as PR #14
head \`ce88e48c2056c887232b98ebf73f4d61ab58ace2\`, so no behavior from
that source is silently rewritten here.

## Source evidence actually read

- Draft PR #14 metadata, full changed-file list, actual current panel scene,
  panel script, text/scroll helpers, schema validator, fixture loader, fixture
  JSON and design \`CHAR_003_DESIGN.md\`.
- Draft PR #17 metadata and shell source: \`shell_candidate.gd\`,
  \`module_registry_candidate.gd\`, \`placeholder_adapter_candidate.gd\` and
  \`DESIGN.md\`. Shell HEAD at inspection:
  \`5ed0602cfb7498900dee13936194bac69d7c9737\`.
- Main baseline \`533b11f50c0d359cd0a5424d5216b0145727699a\` contains only
  public repository collaboration instructions. No approved UI or
  shared event-transport contract is present there.

## Design decision 1 — truly independent branch and unmodified pinned copies

Because the #14 PR is not merged into main, importing \`res://\` resources from
its PR directory would make a new project fail to resolve its dependencies.
The #14 scenes use root-relative \`res://\` script paths. The flow therefore
creates its **own standalone project** and includes verified, **byte-identical**
public #14 files at that project's root. This yields a new PR based directly on
\`main\`, whose file diff is restricted to this new candidate directory; it
does **not** edit PR #14 or any other branch.

Tradeoff: source duplication will drift if PR #14 changes. Integration must
later decide whether to deduplicate/retarget dependencies. No claim of
ongoing auto-sync or approved dependency API is made.

## Design decision 2 — state model isolated from widget/event implementation

The new model accepts a full array of exact #14-compatible validated records,
with a provisional 24-record in-memory upper bound. It rejects malformed
records and duplicate IDs **atomically**, leaving the prior list intact.
A successful replacement clears the previous filter and selection.
An empty valid collection yields a discoverable empty state. The collection
and selected profile are never saved; getters return deep copies.

The route can only be \`list\` or \`detail\`, with selection by stable
\`profile_id\`, not UI row index. Unknown and filtered-out IDs are refused,
so stale buttons cannot open hidden/removed entries. Search is case-folded
literal substring match over display name, subtitle, status and tags only.
It does not search entire long narrative fields or use a model/index.
Changing the query closes any selected detail to avoid showing a result
which no longer appears in the list. No historical graph, time, story choice,
profile mutation or in-world meaning is created.

## Design decision 3 — explicit navigation and shell-owned exit

Wide view (at least 700px) keeps list and detail regions side by side.
Narrow view shows only the list or detail, preserving the underlying model.
Native \`LineEdit\` and \`Button\` controls enable typing, Tab/Shift+Tab and
button activation; **no global Escape/Alt-Left input handler** is added.
This avoids colliding with unapproved shell/INPUT focus arbitration.

\`BackButton\` in detail returns to list. \`ExitButton\` emits
\`exit_requested\` but **never** changes the shell route itself. The external
host may connect this signal after review. Detail changes emit
\`route_changed("list"|"detail", profile_id)\`; changing source emits
\`collection_replaced(count)\` or \`collection_rejected(reason)\`. Those
are local, unapproved prototype signals, not game-wide interfaces.

In the existing shell PR #17 the \`profile\` page is **not** a Control
mount point: it renders plain-text \`preview()\`/simulation from a
trusted local RefCounted adapter. Therefore a compatible mock-only
\`shell_profile_adapter_candidate.gd\` is provided; it returns the
required \`ok,title,body\` and \`simulated\` fields without running
a panel. A real embedded UI would require a separately reviewed
shell-side Control host, not invented here. See \`SHELL_HANDOFF.md\`.

## Design decision 4 — fail closed without dropping list navigation

The new flow loads the detail PackedScene only when needed, from a **fixed**
local \`res://character_profile_panel.tscn\` path. It reuses the pinned #14
factory which checks root type, candidate methods and required navigation
children. A missing or invalid panel shows an error, retains the list/back
controls, and exposes a retry button; it never treats failed resource load
as an accepted detail. Source/script loading may still produce Godot
console errors on malformed assets; this is not a sandbox.

The demo's only file read is the pinned fixed-path synthetic fixture,
through the pinned #14 64KiB/12-record atomic UTF-8 loader. If it fails,
the visible list remains (initially empty), no private data is substituted,
and the status explains the blocker. A host may call \`set_profiles()\`
to inject its own *approved* dictionaries, but this task supplies none.

## Design decision 5 — restrained layout and focus scope

List buttons use native focus, minimum 44 px row height, clear text labels
and hover tooltips. On entering detail, the flow focuses the Back button;
returning to list focuses the filter. The detailed reading region and its
section navigation are supplied by the unchanged #14 panel, including
long-token wrapping and its own keyboard scroll. Preview screenshots,
actual screen-reader output, large font/clipping and keyboard behavior
remain unverified until the author requests testing.

## Limitations / future integration gate

- Exact Godot 4.x minor and supported desktop/mobile OS unknown.
- No theme tokens, accessibility acceptance matrix or fixed navigation API.
- PR #14 and #17 remain independent unmerged Drafts; there is no approved
  live UI handoff between them.
- The supplied shell adapter is only a **synthetic** mock for #17's
  *observed private contract*. It is not evidence of actual cross-PR
  integration; mounting it must be reviewed in the shell workspace later.
- No private manuscript, chat transcript, true character roster, lore,
  identity, relationships, appearance, third-party image or real asset.
- No code execution, Godot editor, unit test, GUI, CI or benchmark was
  performed here. All source/checks **NOT_RUN**. Codex or owner should
  record measured evidence before merging any branch or approving an API.

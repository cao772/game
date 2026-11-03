# Development and Windows delivery roadmap

Current instruction: source implementation, independent static review and logs; no local deployment/demo, no execution of game code/tests, no CI or build. Eventual target is Windows x86_64 on the owner's RTX 5060 system. GPU name alone does not establish CPU, memory, OS or performance requirements. No performance claim is made.

## Milestones and exit evidence

1. **Runtime foundation (batches 001–002 source-authored and reviewed):** quest progression, isolated mode ownership, versioned save records, bounded loop-erased history and explicit archive/recovery in one source tree. Exit evidence is reviewed source, provenance, resource-reference checks and a Draft PR. Runtime status remains NOT_RUN.
2. **One complete quest in source (in progress):** batch 002 adds world-observation and dialogue adapters with revision checks and save-before-switch. Still needed: the scene owner, playable space, movement/targeting, quest journal, visible consequence and recovery controls. Approved narrative stays in a private content package. Author one bounded location and a return visit, not a collection of disconnected viewers. Exit is a source-complete route from entry through choice to outcome, with static state/ownership review.
3. **Playable chapter in source:** third-person movement/camera, interaction targeting, pause/settings, scene transitions, full save ownership, chapter/free transitions and content integration. Audit legacy input/state components at pinned versions before adapting them. Use the same `game/` tree and implementation branch lineage rather than repeatedly forking another candidate for every change.
4. **Content expansion:** complete the initial chapter before expanding the first region; then later narrative regions. Runtime code and public synthetic examples remain separate from private authored content and licensed assets.
5. **Windows packaging:** pin Godot and matching export templates, Windows architecture, assets and licenses; create an export preset and source/content manifest; produce a versioned executable/data package, changelog and recovery instructions. This stage is planned, not executed. Existing technical source packagers do not produce a Windows executable.
6. **Owner playtest:** record actual Windows startup, input/focus, save/recovery, mode isolation, game completion, frame time and memory observations. Keep defects and version-specific results. Static review does not become runtime PASS. Packaging is not acceptance.

No local runtime acceptance is scheduled by this document. Packaging/runtime work must be distinguished from the current source-only batch. Do not re-enable stopped browser automations or merge main implicitly.

## Windows-specific acceptance queue (all NOT_RUN)

- Matching engine/export-template version and architecture; no development-only absolute paths.
- Non-resource JSON included in exported data; scene and script references resolved from the export.
- Actual keyboard/mouse and focus loss, high DPI, text scaling, Unicode path and user-data permissions.
- Save directory creation, interrupted staging, corrupt most-recent generation, missing files, full disk, stale/incompatible definition, old save preservation.
- Chapter replay cannot alter free session or award free resources; restored UI reflects restored state.
- Target-machine frame-time distribution and peak working set in representative scenes. No estimates presented as measurements.

Official references consulted during source design: [Godot Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html), [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html), [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html). Recheck these against the engine version eventually selected for packaging.

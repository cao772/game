# Development and Windows delivery roadmap

Current instruction: source implementation, independent static review and logs; no local deployment/demo, no execution of game code/tests, no CI or build. Eventual target is Windows x86_64 on the owner's RTX 5060 system. GPU name alone does not establish CPU, memory, OS or performance requirements. No performance claim is made.

## Milestones and exit evidence

1. **Runtime foundation (batches 001–002 source-authored and reviewed):** quest progression, isolated mode ownership, versioned save records, bounded loop-erased history and explicit archive/recovery in one source tree. Exit evidence is reviewed source, provenance, resource-reference checks and a Draft PR. Runtime status remains NOT_RUN.
2. **One synthetic quest connected in source (batch 003):** batch 002 adds world-observation and dialogue adapters with revision checks and save-before-switch. Batch 003 now authors a persistent scene owner, bounded synthetic space, movement/nearby targeting, quest journal, visible delivery consequence and confirmed recovery controls. Source integration is present; runtime usability and compilation remain unverified. Approved narrative stays in a private content package. Author one bounded location and a return visit, not a collection of disconnected viewers. Exit is a source-complete route from entry through choice to outcome, with static state/ownership review.
3. **Explorable area and free interaction (priority updated 2026-11-06):** improve third-person movement and camera, connect the existing locations with routes that offer different uses, then add movable objects, usable seating and lighting. Persist the relevant object and area state. Acceptance should show that players can explore and arrange a space from the beginning.
4. **Characters and world activity:** give residents visible routines, interests, relationships and useful responses to player actions. Begin with a small area and a few time periods. Follow with further traversal, abilities and activities as their underlying interactions become usable. Narrative content can draw on the resulting world and character behavior.
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

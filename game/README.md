# Game runtime foundation

The consolidated source includes a quest runtime, a free/chapter session owner, an immutable save store and an application boundary for world interaction and dialogue. It is **not a playable game or exported Windows build**. The project has no main scene yet. Godot import, compilation, execution, tests and export are **NOT_RUN**; development has been limited to source authoring and static review.

## Components

| File | Responsibility |
| --- | --- |
| `runtime/quest_runtime.gd` | Bounded quest graph validation, explicit start/choice, observable facts, AND/OR gates, terminal state and staged restoration |
| `runtime/session_coordinator.gd` | Active-mode ownership, independent chapter replay, free state retention, explicit per-mode save/load |
| `runtime/save_store.gd` | Immutable JSON save generations, content digest, bounded reads and corrupt-record diagnostics |
| `runtime/quest_application.gd` | Validated observation mapping, dialogue presentation, revision-bound commands and save-before-mode-switch |
| `world/quest_observation_area.gd` | Explicit interaction from a body overlapping the configured Area3D |
| `ui/quest_dialogue_panel.gd` | Reusable plain-text panel, explicit start/choice and stale-callback rejection |
| `content/synthetic_delivery.json` | Public, non-canonical sample with alternate prerequisites and a retry loop; not the private game quest |
| `content/synthetic_presentation.json` | Complete synthetic text and observation bindings for that sample |

Use `game/` as the eventual Godot project root. A future scene controller will preload `res://runtime/quest_application.gd`, parse its approved definition and presentation, and call `configure`. Route player interactions through registered world bindings; the UI must not grant itself an expected condition merely because it knows the quest schema. `start` and `choose` are explicit commands. `present` is read-only and supplies text, actions and a revision for subsequent commands. Definitions and facts are per session, not a global knowledge table. See the [application integration contract](../docs/development/application-integration-v2.md).

`enter_chapter` creates a fresh chapter instance. `leave_chapter` discards it and returns to the unchanged in-memory free instance. `save_active` and `load_active` address only the active mode's fixed slot. To resume a chapter, explicitly enter it before loading. A storage-valid but semantically incompatible save is rejected with the live session retained. Neither a hash nor a successful save proves gameplay correctness.

At the lower coordinator layer, mode changes do not write files. At the application boundary, entering or leaving a chapter first saves the current mode and rejects the switch if saving fails. A chapter record still contains only chapter data; it is not a full-session checkpoint. An explicit `load_archived` restores only the current mode after the same semantic validation as an active save.

## Current boundaries

- One quest definition per coordinator. This milestone does not claim a multi-quest journal, full world save, inventory, currency, reward delivery, chapter clock or content migration.
- Observation calls are trusted application input. Saves are not authenticated against tampering, and snapshots cannot reconstruct when an externally observed fact was learned.
- Structural reachability is checked; it is not a proof that the world can supply every required fact. Content/world mapping still needs review.
- Completed quests reject further choices. Terminal state is not an implemented exactly-once reward system.
- Single-writer saves retain previous generations. No cross-process locking, automatic retention, antivirus interaction guarantee or power-loss durability claim.
- Quest history is a loop-erased route of at most 63 edges, not a full action audit log. Loops do not consume a lifetime action budget; old histories up to 256 entries are fully validated before normalization. Monotonic facts survive compaction.
- Save archival is explicit and nondeleting, retains at least the newest two valid active records, and reports partial movement. It is not automatic cleanup, unlimited storage, or a multi-process transaction. See [save retention](../docs/development/save-retention-v2.md).
- Saved quest definition IDs/versions must match. No silent migration of old candidate schemas.
- No unpublished names, plot, dialogue, manuscript or private URLs are shipped in this public source tree.

See [candidate contract](../docs/development/runtime-contract.md), [delivery roadmap](../docs/development/delivery-roadmap.md), and the component review documents for future acceptance and limitations.

The feature declaration is 4.1 because the save store uses GDScript static variables. This is an API-level requirement, not a verified minimum engine build; pin and validate the exact engine/export templates before packaging.

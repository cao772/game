# Game runtime foundation

The first consolidated source milestone is a quest runtime, a free/chapter session owner and an append-only save store. It is **not a playable game or exported Windows build**. The project has no main scene yet. Godot import, compilation, execution, tests and export are **NOT_RUN**; development has been limited to source authoring and static review.

## Components

| File | Responsibility |
| --- | --- |
| `runtime/quest_runtime.gd` | Bounded quest graph validation, explicit start/choice, observable facts, AND/OR gates, terminal state and staged restoration |
| `runtime/session_coordinator.gd` | Active-mode ownership, independent chapter replay, free state retention, explicit per-mode save/load |
| `runtime/save_store.gd` | Immutable JSON save generations, content digest, bounded reads and corrupt-record diagnostics |
| `content/synthetic_delivery.json` | Public, non-canonical sample with alternate prerequisites and a retry loop; not the private game quest |

Use `game/` as the eventual Godot project root. A future scene controller will preload `res://runtime/session_coordinator.gd`, parse its approved content definition, and call `configure`. Call `observe` only from validated world interactions; the UI must not grant itself an expected condition merely because it knows the quest schema. `start` and `choose` are explicit commands. Consume `view` to present text keys and available actions. Definitions and facts are per session, not a global knowledge table.

`enter_chapter` creates a fresh chapter instance. `leave_chapter` discards it and returns to the unchanged in-memory free instance. `save_active` and `load_active` address only the active mode's fixed slot. To resume a chapter, explicitly enter it before loading. A storage-valid but semantically incompatible save is rejected with the live session retained. Neither a hash nor a successful save proves gameplay correctness.

Entering a chapter does **not** automatically save free progress. A chapter record contains only chapter data. The future application owner must explicitly offer/save free progress before switching; a chapter save cannot be advertised as a full-session checkpoint.

## Current boundaries

- One quest definition per coordinator. This milestone does not claim a multi-quest journal, full world save, inventory, currency, reward delivery, chapter clock or content migration.
- Observation calls are trusted application input. Saves are not authenticated against tampering, and snapshots cannot reconstruct when an externally observed fact was learned.
- Structural reachability is checked; it is not a proof that the world can supply every required fact. Content/world mapping still needs review.
- Completed quests reject further choices. Terminal state is not an implemented exactly-once reward system.
- Single-writer saves retain previous generations. No cross-process locking, automatic retention, antivirus interaction guarantee or power-loss durability claim.
- A quest can store at most 256 actions. At that limit further choices stop, including a long-running retry loop. History compaction or an explicit recovery policy is a release blocker, not a finished player experience.
- Saved quest definition IDs/versions must match. No silent migration of old candidate schemas.
- No unpublished names, plot, dialogue, manuscript or private URLs are shipped in this public source tree.

See [candidate contract](../docs/development/runtime-contract.md), [delivery roadmap](../docs/development/delivery-roadmap.md), and the component review documents for future acceptance and limitations.

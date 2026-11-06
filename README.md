# Game project

This repository tracks technical prototypes and their review history.

Implementation changes are submitted on `codex/` branches through draft pull requests. The project owner reviews changes before they are merged into `main`.

Unpublished manuscripts, story canon, private design notes, and raw chat evidence are stored in the project's authorized private documentation and asset archives rather than this public repository.

The consolidated source-development entry is [game/README.md](game/README.md).
It implements quest progression, mode-separated sessions and save records, with
world-observation/dialogue adapters, loop-erased quest history, explicit save archival,
and a bounded synthetic delivery scene. Collect a parcel, take it to the lamp-lit desk
and speak to the animated clerk. The door beside the desk leads to a records room.
The archivist can discuss the slip the player finds in the trays.
It is source-reviewed only: runtime, tests and Windows packaging are NOT_RUN.
See [development roadmap](docs/development/delivery-roadmap.md) for the next milestones.

The configured entry now opens a regional exploration source candidate: camera-relative
movement, three connected areas, six directed crossings, persistent movable crates,
landmark discovery and scheduled resident positions. It keeps its own `world_free`
save slot and can enter the earlier desk scene. See [world foundation](docs/development/world-foundation-v8.md)
for the precise implemented scope, adopted open-source code and pending acceptance.

The next source slice adds [residents on the road](docs/development/resident-activities-v9.md):
two authored daily itineraries, walking models, optional conversation, live directions
and cancellable manual companion markers. Route changes preserve the 008 atlas and
world save identity. Runtime acceptance is still pending.

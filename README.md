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

A separate [modern residential street](docs/development/modern-street-v10.md) adds
first-person and close third-person source controls, human-scale apartment blocks,
looping street/alley paths and three bundled CC0 PBR materials. It can be entered
from the regional explorer after saving. This is a source-only scale/material study;
rendering, collision and performance remain unverified.

The [enterable workshop](docs/development/urban-workshop-v11.md) now connects one
street frontage to its rear yard. Nearby visible shutters, a lamp and a movable
toolbox can be used freely; their layout persists in an independent `urban_free`
slot. This source increment keeps old world and quest saves unchanged.

A [workshop resident](docs/development/urban-resident-v12.md) now has a scene-local
work/shelf/yard routine, gate-aware routes and optional conversation about the
current layout. This reuses a licensed staging character and keeps the five-field
urban save unchanged; it is not a full-day city simulation or final character art.

The [public terrace](docs/development/urban-terrace-v13.md) adds an elevated yard
loop reached by stairs or a switchback ramp, plus optional seated observation.
The same layout save is retained; posture and temporary movement remain unsaved.

The same [resident now visits the terrace](docs/development/urban-life-v14.md)
independently, using the stair route to a separate standing lookout before returning
to work. Optional small talk varies by the actual resting place, with older
conversation configurations retained. This remains source-only development.

The [yard workbench](docs/development/urban-yard-work-v15.md) gives toolbox placement
an additional use: the resident can work outside and choose that destination on
departure. A hinged lid and work-specific conversation reflect the same conditions;
the existing layout save and earlier dialogue configurations remain compatible.

The [public reading room](docs/development/urban-reading-room-v16.md) opens the
southwest ground floor as a second street-to-alley passage, with two routes around
a shelf, optional reading, a light and a seat. Reading state lasts for the visit;
legacy saves and the existing resident routine remain unchanged. Source only.

A [movable reading tray](docs/development/urban-reading-tray-v17.md) lets the player
choose the desk, bench-side table or covered frontage. Book and toolbox pickups
share one hand slot. Pages follow the tray; seated reading retains range/occlusion
checks. Tray layout lasts for the visit and does not alter legacy save schemas.

018 adds a finite reading-room visitor with a personal sketchbook, tray-aware observation and checked retreat/routing. See [source behavior and limits](docs/development/urban-reading-visitor-v18.md). This remains a source-only candidate, without Godot/gameplay execution.

019 adds a west-lane wash shelter with one movable basin, timed filling, preparation and draining. The three held object types are mutually exclusive; legacy saves stay unchanged. See [behavior and source-only validation](docs/development/urban-wash-shelter-v19.md).

020 adds a visitor who brings personal cups to the dry end of the wash counter and takes them home. [Visit and controls](docs/development/urban-cup-visitor-v20.md).

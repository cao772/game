# Regional world foundation — source candidate 008

The new entry lets a player pursue exploration and rearrangement without starting
a quest. The regional graph and stable object identities are intended to support
later expansion. The present authored content is three 64 × 64 local areas, not a
completed large open world. All content in this repository is synthetic.

## Included source

- Third-person camera-relative walk/run/jump, orbit and zoom, focus recovery and a
  SpringArm excluding the player's body. Animated CC0 staging model.
- YARD ↔ RIDGE ↔ SHORE ↔ YARD: six explicit directed crossings with arrival pose
  and travel time. Replace the active area's geometry on crossing.
- Two crates: take, carry between areas, quarter-turn and place on six fixed pads.
  Only one carried object; occupied pads and remote actions reject the request.
- Six discoveries and two residents projected into three daily schedule periods.
  One game minute per five focused seconds; map/restore dialog pause the clock.
- Strict world snapshot identity, finite/bounded positions, occupancy checks and
  staged restoration. Snapshot commits only after every field validates.
- Separate `world_free` slot through a SaveStore subclass. Existing `free` and
  `chapter` record formats and original configure signatures are unchanged.
- Optional scene wrapper saves the explorer before desk entry and the active quest
  before returning. Failed writes block the scene change. Entry restores saved free
  quest data; historical chapter records still require explicit chapter entry/load.

## Reuse

The camera-basis movement conversion comes from
[Godot's 4.1 platformer player](https://github.com/godotengine/godot-demo-projects/blob/6ecf265637d66104fbfa83da4af956681313436e/3d/platformer/player/player.gd),
MIT notice in `game/third_party/godot-platformer/`. The remaining controller and world
state implementation are local. KayKit Knight geometry and six clips are CC0;
source and license are in `game/art/explorer_actor/`. NPCs reuse earlier CC0 assets.

## Verification and limits

Offline grammar, JSON/reference/geometry inspections and independent source review
are the current evidence. Godot import/type checking, rendering, gameplay, tests and
Windows export are **NOT_RUN**. No third-party installer/demo has run. Engine feature
declaration remains 4.1; this is not a verified runtime version.

Resident projection changes location at time boundaries; there is no simulated
cross-region walk. Crates occupy marked pads and have no crafting/stacking system.
The map is a route/discovery summary; there is no general fast travel. Daylight uses
sun intensity, not a full weather/astronomy simulation. These are explicit next-step
boundaries, not claimed features. Quest progress and world clock remain separate.

## Pending runtime acceptance

1. Run each route both ways, including while carrying a crate. Arrival must face
   into the destination; save and restore in all three areas and on the overlook.
2. Move a crate onto another area's empty pad, rotate it and return after restoring.
   Attempt occupied-pad placement and distant interaction; neither may mutate state.
3. Walk both paths, run/jump, climb the overlook ramp and orbit near walls. Verify
   camera clipping, model orientation/animation, slope contact and recovery.
4. Observe 08:00 and 17:00 schedule boundaries, midnight, focus loss, map and load
   dialogs. Desk visits and chapter replay must not advance the explorer clock.
5. Restore corrupt/incompatible world records without replacing live state. Save
   failure must keep the current scene. Old quest-only records must still restore.
6. Inspect Chinese HUD at 1280 × 800 and high DPI. Verify held-object rotation,
   visible landmarks, view from the overlook and all resource imports on Windows.

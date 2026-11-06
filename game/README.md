# Game runtime foundation

The regional explorer also has a modern-street entry. It saves before departure and
returns to the saved world. `scenes/modern_street.tscn` provides a separate first-person
walking area; V switches to a close shoulder camera, hold RMB to look, release it to
use the UI. WASD walks, Shift runs and Space jumps. The street includes human-scale
residential blocks and three CC0 material sets. One workshop now has usable front/rear
shutters, a light and a toolbox movable between three supports. Approach and look
at a target, then press E. F5 saves; F9 confirms a restore. The independent
urban_free slot saves these interactions; player position resets to the entrance.
Returning normally saves first, with a separate confirmed no-save exit available.
The southwest reading room is also enterable; driving remains unavailable.
Engine/rendering acceptance is NOT_RUN.
See `../docs/development/modern-street-v10.md` for scope and verification boundaries.

The consolidated source includes a quest runtime, a free/chapter session owner, an immutable save store and an application boundary for world interaction and dialogue. It is **not a playable game or exported Windows build**. A bounded synthetic main scene now connects movement, nearby interaction, quest choices, visible delivery feedback and explicit save recovery; it has not been imported or run. Godot import, compilation, execution, tests and export are **NOT_RUN**; development has been limited to source authoring and static review.

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

Use `game/` as the eventual Godot project root. The sample scene controller preloads `res://runtime/quest_application.gd`, parse its approved definition and presentation, and calls `configure`. Route player interactions through registered world bindings; the UI must not grant itself an expected condition merely because it knows the quest schema. `start` and `choose` are explicit commands. `present` is read-only and supplies text, actions and a revision for subsequent commands. Definitions and facts are per session, not a global knowledge table. See the [application integration contract](../docs/development/application-integration-v2.md).

`enter_chapter` creates a fresh chapter instance. `leave_chapter` discards it and returns to the unchanged in-memory free instance. `save_active` and `load_active` address only the active mode's fixed slot. To resume a chapter, explicitly enter it before loading. A storage-valid but semantically incompatible save is rejected with the live session retained. Neither a hash nor a successful save proves gameplay correctness.

At the lower coordinator layer, mode changes do not write files. At the application boundary, entering or leaving a chapter first saves the current mode and rejects the switch if saving fails. A chapter record still contains only chapter data; it is not a full-session checkpoint. An explicit `load_archived` restores only the current mode after the same semantic validation as an active save.

## Current boundaries

- One primary quest and one optional side quest per coordinator. The journal displays each independently. The market tracks the choice and its visible consequences. Inventory and currency are outside this scene.
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

## Using the delivery scene

The configured main entry is now `scenes/world_explorer.tscn`. WASD moves relative to
the camera, Shift runs, Space jumps, right-drag or arrow keys turns the view and
the wheel changes distance. E uses a nearby crossing, landmark, resident or crate;
Q rotates a carried crate. Empty marked pads accept it. M opens the route map.
The world advances one minute per five focused seconds and pauses with the map or
restore confirmation open. Rest advances one hour. F5 saves, F9 requests restoration.

The three regions form a reversible triangle. One region's geometry is present at a
time; crossings are explicit transfers, not seamless streaming. Crates can cross
regions and persist at fixed anchors; arbitrary construction, crafting, voxel terrain
and systemic reactions are future work. Residents follow two authored daily paths, with positions derived from the world
clock. Optional conversations pause time; directions and manual companion markers
help the player travel with them. Autonomous needs and obstacle-aware pathfinding
are not implemented. See ../docs/development/resident-activities-v9.md.
The explorer uses `world_free`; existing free/chapter quest snapshots are unchanged.
The optional desk wrapper restores the free quest record on entry, saves its current
mode on return, and leaves the explorer clock stopped while away.

Movement direction uses a small adaptation of the MIT Godot 4.1 platformer demo.
The new CC0 Knight stand-in retains six clips. Source and licenses are bundled.
All of this remains **source-only / NOT_RUN**, including import, rendering and collision.

`scenes/sample_location.tscn` is the earlier delivery scene, reachable through the explorer's optional desk entry. `world/sample_location.gd` owns one application for the scene lifetime; `world/sample_player.gd` supplies WASD movement with a fixed elevated camera. E interacts with the nearest overlapping station. Dialogue freezes movement; Esc closes it. A scrolling sidebar exposes the journal, mode, manual save, latest restore, explicit archive and restore by generation. User-facing sample text is Chinese and remains wholly synthetic.

At the collection station: start and collect, inspect either route or speak to the helper, then return to choose a route. WAIT/RETRY remains available. Carry the green-banded parcel to the lamp-lit desk; E opens the clerk's dialogue in a closer view. Handing it over moves the parcel onto the desk and shows the clerk's reply. Dismiss the receipt, then interact again for a different greeting. Before the parcel is ready the clerk directs you to collection. The desk sign, journal and parcel are derived from quest state, including after restore. Restoring a save never initiates the handover animation.

The signed outcome determines which tray contains a slip behind the records-room door. Visit early to meet the archivist, then enter after delivery. Inspect the trays with E. The archivist's follow-up line requires examining the tray that holds the slip during this visit. Esc returns to the room overview. The brass threshold leads back to the yard.

Both locations share one quest owner and one player. A successful restore or mode switch places the player at the yard entrance and rebuilds the desk and tray displays from the current quest. The room and the inspection during a visit are transient. Restores warn before replacing unsaved progress. Mode switches save first. Save failures retain the active location and mode. Archival reports moved generations even after partial failure.

The CC0 clerk uses three clips from [KayKit Adventurers](art/counter_actor/SOURCE.md); the desk, ledger and lamp come from [KayKit Furniture Bits](art/dispatch_counter/SOURCE.md). The clerk is a staging model. For asset checks and the pending Windows walkthrough see [counter review](../docs/development/counter-review-v4.md); [scene review](../docs/development/scene-review-v3.md) describes the earlier blockout.

The second clerk uses the [unhooded Rogue model](art/records_actor/SOURCE.md). The [filing cabinets](art/records_room/SOURCE.md) and readable slips are staged for the visit. Windows verification should cover the doorway in both directions, each tray before and after delivery, a close-up from the desk edge, and a restore initiated inside the room.


At the southeast stall the player can start an optional errand at any point during delivery. Picking a replacement resolves it there. Tracking the original closes the stall and leads to the southwest workbench, the shelf east of the counter and back to the workbench. On return the stall offers either prices or a shared-tool register. Each stop checks proximity and the active revision before accepting a choice.

Both quests are stored in one generation for the selected mode. A schema 1 save opens with its original delivery progress and a fresh side quest. A schema 2 save restores both quests after validating both snapshots. Open these newer generations with this version. Pending Windows checks include saving between the shelf and workbench, reloading a prior delivery-only generation, and completing a different market route in chapter replay.


## Meeting residents on the road

Approach within three meters and press E to greet a resident. Two optional topics
reveal ordinary interests; “接下来去哪？” reads their actual next destination.
“我跟你走一段” closes the conversation and marks their current distance or exit;
walk manually, or cancel the marker at any time. While the resident is at an
activity point, “等到出发” shows how many game minutes it will advance before
starting a shared walk. It changes the world clock for everyone.

The atlas and world snapshot contract are unchanged from 008. Restoring reconstructs
residents at the saved whole minute and clears temporary conversation/companion
state. Routes and optional dialogue are in separate content files. Each resident
keeps Idle, Walking_A, Interact and Cheer with its CC0 source notice; the previous
merchant apron is preserved. Source only; no import, animation or collision runtime
acceptance has been performed.

## A resident using the modern workshop

The workshop resident uses the bench, shelving, yard and terrace. Walking
uses an authored graph and physical collisions: closed shutters change available
routes, and player obstruction pauses progress. E opens optional conversation
nearby and in sight; Esc says goodbye. Replies reflect the current toolbox and
lamp state. No task, payment, relationship score or inventory transfer is required.

The routine pauses with conversation, confirmation UI or lost input focus. Its
bench/shelf/yard/terrace dwell times are 25/12/20/24 active seconds plus walking time, not a
day/night schedule. Entry and successful F9 restoration restart it at the bench;
only the existing five-field layout is saved. Gate protection includes both the
player and resident. Existing region residents and their schedules are unchanged.

The current character is a licensed animated proxy, not the photorealistic concept
image. See ../docs/development/urban-yard-work-v15.md for current scope and pending runtime
acceptance; no Godot import, gameplay or game tests have been executed.

## The public terrace

In the east yard, stairs and a switchback ramp reach a 3 m public terrace. The
ground rear lane remains open underneath. Approach its bench on the same level
and press E to sit; use right-drag to look and V to change camera mode. E gets up
only when a supported, unobstructed exit is available. WASD and Space do not move
the seated player. A carried toolbox remains carried, displayed in front of the
body. Resident activity continues while sitting.

Posture is not part of the save. A successful layout restore returns the player
standing at the street entrance; cancelled or failed restore preserves the pose.
The existing save-before-return and failed-write behavior remain. The existing
resident now visits a separate standing lookout via the stair route; the bench
stays available to the player. No task unlock is required. The seated player
is a geometric proxy. See ../docs/development/urban-terrace-v13.md; slopes, seams,
seating and camera behavior remain source-only and need runtime acceptance.

At each resting place, optional small talk can reflect the surroundings. Moving
or blocked conversations use general copy instead of implying the next stop has
already been reached. Existing three-destination dialogue files remain supported.

## Working indoors or in the yard

The yard anchor is now a standing-height workbench. Place the same toolbox there
to make outdoor tool organizing available when the resident arrives. Indoor work
needs the box at the bench and its lamp on; yard work does not use that switch.
Taking the box stops work and closes its hinged lid. Work and rest have distinct
optional small talk. There are no repair orders, crafted products or rewards.

After the indoor bench or terrace dwell, a box in the yard selects the yard as
the next destination; otherwise the previous shelf/bench continuation remains.
Shelf leads to yard and yard leads to terrace. Moving the box does not interrupt
an active walk or remove the resident's rest. Box-lid pose is not saved; the same
five-field layout remains. Details and pending acceptance are in
`../docs/development/urban-yard-work-v15.md`.

## Public reading room

Enter the southwest ground floor from the street or rear alley. Walk on either side
of the central shelf; E flips the reading booklet, switches its light or sits at the
bench. E stands up; RMB and V retain their usual view controls. Light and pages are
temporary for this visit and are not included in F5 saves; re-entry or a successful
F9 layout restore resets them. Failed/cancelled restores preserve the current room.
The existing workshop resident continues independently. See
`../docs/development/urban-reading-room-v16.md`. All runtime acceptance is NOT_RUN.

## Move the reading tray

R picks up the public tray or places it on an aimed support. E retains reading and
seating; while carrying, E can also place the tray. F reads the held booklet or an
aimed nearby tray. While seated E stands, R refuses movement and F reads. Only one
item can be carried: put down the toolbox before taking the tray, or vice versa.
The desk, bench-side table and covered-frontage ledge are the three supports.
Page number follows the tray. Its position is visit-local and resets to the desk
on re-entry or successful F9 restore; it is not part of F5 saves. See
`../docs/development/urban-reading-tray-v17.md`. Source-only; runtime NOT_RUN.

018: 一名阅览来客会自行看公共册、画自己的本子、经后巷回廊下。近处看向来客按E了解当前活动，时间继续；不抢玩家椅或公共盘。来访进度不入旧档，重进/成功恢复重新开始，失败/取消保留。角色、册/笔为代理表现，Godot/游戏仍未运行验收。

019：从阅览室后门沿西后巷向北可到公共洗择棚。R拿放盆，E在接水槽开关水、择洗台处理菜、沥水台倒水；F仍读书。空盆在水槽连续接2活动秒水，龙头最多6秒；用过的水要先倒掉。盆/书盘/工具箱只能拿一件。盆水/菜不入旧档，重进或成功恢复复位；失败/取消保留。可携盆在原长椅坐着，E起身、R禁用。Godot/游戏尚未运行验收。

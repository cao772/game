# Reading visitor · source slice 018

One visitor makes a finite trip through the existing reading room: pause on the frontage, observe the current public booklet if available, draw in a personal notebook, close it, walk through the rear lane and return to the frontage. This does not require a quest, a conversation or the player staying nearby. It does not restart until scene reconstruction or a successful explicit layout restore.

## Observable behavior

- The initial frontage pause is8 active seconds, public observation up to12, personal drawing30, and closing3. Actual walking adds its own time. These are source tuning values, not measured pacing or world-clock minutes. Per-frame steps are capped at0.1 seconds; pause/focus/modal periods do not catch up later.
- The visitor chooses the tray's current desk/side/porch location. A moved tray can redirect them once at a confirmed route node; a carried or repeatedly moved tray skips observation. If the tray leaves during observation, the root stops observation in the same physics frame after player input. The visitor never picks up, turns, returns or reserves the public tray.
- Reading requires actual supported arrival, the selected tray remaining there, distance within2.6m, and an unobstructed ray. A blocked view waits at most4 active seconds before the visitor continues with their own notebook. Player page changes are reflected in the next observation update and do not extend the12-second budget.
- The window drawing point is separate from the player's seat and all three get-up routes. A blocked approach can select a quiet interior fallback, whose description says it is checking an existing sketch rather than looking outside.
- The visitor keeps their own single notebook and pencil visual. Paper and marks appear during drawing; five small marks accumulate, then the notebook switches closed and travels with the visitor. This is a procedural proxy, without hand-bone attachment, precise grip, head gaze or dedicated drawing/closing animations.
- E on the nearby visitor shows current activity and a brief remark. It is a passing observation, not a modal conversation: movement and remaining time continue. No task, reward, friendship state or inventory transfer is added.

## Route and obstruction

The authored graph has19 ground-level nodes and21 undirected edges around the existing shelf, entrances and south outdoor loop. Weighted routing prefers short available segments. Return initially targets the rear lane before the frontage; a blocked return can target the frontage through the front opening instead.

A conservative capsule checks start overlap, swept motion and end overlap against world, player and resident layers. Actual movement uses CharacterBody3D movement and floor support; route completion requires horizontal proximity, matching height and grounded state. Only initialization/successful restore explicitly assigns a position. A blocked edge waits6 active seconds (4 when approaching a drawing spot), then is excluded for30 active seconds. The visitor first physically retreats along the traversed segment to the last confirmed node, with the same occupancy checks. If retreat is blocked too, they wait; no timer teleports through the blocker. Both entrances blocked can prevent completion indefinitely.

The old workshop resident remains on its separate east-side route and retains its existing interface. This is not a general crowds/navigation system. Resident layer4 is already included by player movement and sitting queries. The root now includes the new visitor's current/predicted feet when placing the tray; interaction rays allow only the intended resident body, not a different person as an occlusion exception.

## Ownership and restoration

ReadingRoom.visitor_view returns a detached anchor/page snapshot. The visitor receives no room object or public-item mutation authority. It writes no save data. Original urban_free five fields, quest/world files and mode isolation are preserved.

Modal dialogs, workshop conversations and focus loss suspend the visitor and its animation. Route, remaining time, notebook progress and blocked-edge timing are preserved. Failed/cancelled/no-record restore leaves the visit untouched. Successful restore resets the visitor to the frontage, closes the notebook and starts a new finite visit; save/restore/leave copy states this boundary. Normal scene exit ends the scene-local visit.

## Validation and limits

30 scripts passed offline grammar parsing (gdtoolkit4.3.4, not Godot4.1 semantic compilation). Static resource resolution, source review, conservative fixed geometry and graph connectivity were checked. Counts and review conclusions are recorded with the delivery. Godot import, gameplay, game tests, save I/O, builds, rendered appearance and dynamic collisions remain NOT_RUN.

Godot4.1 API references checked: [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/4.1/classes/class_physicsdirectspacestate3d.html), [CharacterBody3D](https://docs.godotengine.org/en/4.1/classes/class_characterbody3d.html), [PhysicsBody3D](https://docs.godotengine.org/en/4.1/classes/class_physicsbody3d.html). Start/end overlap checks accompany cast_motion because an already overlapping shape is ignored by the sweep. Existing licensed merchant asset and its Idle/Walking_A clips are reused; no new external art dependency.

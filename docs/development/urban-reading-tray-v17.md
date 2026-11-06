# Read where you choose

The single public booklet now lives in one movable tray. Its mesh, heading and
bookmark move together between the reading desk (-21.4,.76,10.1), a low table
beside the bench (-19.5,.58,20.5) and the covered-frontage ledge (-13.35,.82,17.4).
No old booklet remains on the desk. The tray is a fixed-anchor visual object,
not a physics projectile, stepping stone or additional inventory system.

| Context | E | R | F |
| --- | --- | --- | --- |
| Looking at the placed tray | Read next page | Pick up, if hands are free | Read next page |
| Carrying tray, looking at a valid support | Place | Place | Read held booklet |
| Seated | Attempt checked stand-up | Refuse; stand first | Read held or aimed/reachable tray |

A toolbox in hand rejects tray pickup. A tray in hand rejects toolbox pickup.
Neither rejection changes ownership or duplicates an object. Page number follows
the tray, independent of the reading light. Residents continue their existing
routine. The existing seated fixed-forward carry pose avoids orbiting the tray
around the avatar while looking around. Visual hand contact is still a proxy.

Only an occupied support is a reading target. When carrying the tray, all three
supports become placement targets. Targets retain the physics-frame 2.6 m range,
facing and world/resident occlusion checks. Seated surface reading uses the real
1.20 m eye height; E still stands up before any other action. Placement checks
current and predicted player/resident occupancy before changing the anchor.
A single physics tick handles either E or one secondary action, never both;
modal dialogs, lost focus and pause clear queued inputs.

This remains visit-local state. Walking outside the room within the same street
keeps the tray location/page; leaving the modern scene or successfully restoring
its layout resets the tray to the desk and resets reading light/page. Failed or
cancelled restore, missing-save restore and failed scene transition preserve it.
F5 saves the original five-field workshop layout only. Restore/leave confirmation
and save feedback state the tray's reset boundary. Restoring a saved carried
toolbox resets the tray before projecting the restored hand state, preserving
the single-hand invariant.

Legacy runtime, save stores, workshop resident, controller and private candidate
files remain unchanged. This slice adds no NPC, downloaded asset, quest or schema.
The bench-side support avoids the west route and all three original stand paths.
Fixed geometry and six eye-to-target rays (including seated reading) were checked
as source arithmetic. No game script was executed. Offline grammar parsing is not
Godot semantic compilation. Godot import, gameplay, tests, save I/O, rendering and
builds remain NOT_RUN. Runtime acceptance must cover simultaneous keys, both
pickup orders, all three placements, held/seated reading, focus/modal transitions,
restore success/failure/cancel and exit failure, plus camera/hand intersections.

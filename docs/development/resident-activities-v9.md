# Residents on the road — source candidate 009

Residents now have a continuous authored daily route between their activity points.
A player can meet them on the road, pause for an optional conversation, ask where
they are going, and keep a cancellable companion marker while walking independently.
An explicit wait-until-departure option makes a journey available without waiting
through a long real-time idle period. No quest start, reward or relationship score
is required by these interactions.

## Source behavior

- `resident_schedule.gd` validates and compiles two ten-segment daily routes.
  The existing world day/minute plus the current fractional minute determines
  location and facing by cumulative path length. Exactly one region owns each
  resident at a time, including boundary instants and midnight.
- Every same-region segment joins its neighbor. Region changes use an existing
  atlas exit/spawn pair. Those raw XYZ values are checked first; the explicit
  `portal_ground_y=0` then removes the player's one-meter spawn clearance from
  resident feet. These paths stay on the three existing flat road planes.
- Morning, late-afternoon and night trips end at 08:00, 17:00 and 23:00.
  Walking durations imply approximately 0.91–1.08 world meters per real second
  under the five-second game-minute clock; these are source calculations, not
  measured movement or animation results.
- `world_resident.gd` retains four CC0 clips and the existing merchant apron.
  An AnimatableBody3D on layer 4 follows the route; the explorer player mask is 5.
  New instances seed their pose before collision activation. Scene changes and
  deliberate time skips reconstruct residents instead of sweeping them across town.
- Ordinary crate/discovery refreshes preserve resident nodes. Interaction finds
  the current body position and rechecks the three-meter distance on opening.
- Conversations pause player movement and world time. Greeting/idle animation
  continues; closing resumes the daily route. Map, load confirmation and lost
  focus also stop time. Rest is rejected while talking.
- Each resident offers two optional topics. Directions use the live route rather
  than hard-coded text. Following closes the conversation and adds a distance or
  region-crossing hint; it is manual walking, not automatic player navigation.
- Waiting until departure explicitly advances the world clock, closes the chat,
  reconstructs the actors and starts the companion marker. Failed time advances
  leave the current conversation and world intact.

## Compatibility

`world_atlas.json`, `world_state.gd`, `world_save_store.gd`, the original SaveStore
and quest/session APIs are unchanged from 008. Routes and conversation copy live
in separate files, so these changes do not alter the saved world config hash.
There is no resident save field or new slot. Existing `world_free` records continue
to restore under the same map definition.

Snapshots retain the existing whole-minute clock. A restore reconstructs residents
at that minute, clears temporary conversation/companion UI, and may rewind less
than one game minute of movement. Failed restores preserve the current state and
UI. Companion markers, topics read and animation frames are not persisted.

## Evidence and remaining limits

Offline grammar parsing, data/scene references, route coverage and portal checks,
geometric clearance, model payload/clip inspection and an independent source review
are the available evidence. Godot import/type checking, runtime animation/collision,
game tests and Windows export remain **NOT_RUN**.

These are authored paths, not autonomous needs, NavMesh pathfinding or crowd AI.
Moving bodies can influence the player; they do not plan detours around the player.
Crossings replace active region scenery as before. The animation gait, moving-body
contact and camera clearance require an actual engine walkthrough.

Pending walkthrough: wait for each resident's departure; intercept mid-path and
resume; follow through all three regions; move/rotate a crate while a resident
walks nearby; open map/load dialogs; restore both old and current world records;
check midnight, cross-day waiting, failed restore and failed scene-save paths.

API reference checked: [Godot 4.1 AnimatableBody3D](https://docs.godotengine.org/en/4.1/classes/class_animatablebody3d.html).
The resident assets' original CC0 notices and exact provenance accompany the models.

# A public reading room and passage

The southwest block's ground floor is now an open reading room. Its front door
at (-14.2,0,11.3) and rear door at (-24,0,24) connect the main street to the alley.
Both are always open, 2.4 m wide and 2.5 m high, with no threshold. The existing
upper floors and frontage columns remain. Approach through the gap between
columns (for example z12.2), then turn toward the doorway: a straight line from
the road along z11.3 would hit a retained column.

A 1.3 m high central shelf separates two routes, while a desk and bench sit off
the through paths. The outdoor route around the south of the building remains.
A closed, transparent rear window provides an optional alley view. Dimensions
are authored game geometry, not measurements or building-compliance claims.

Approach a target and press E to cycle through three short generic reading pages,
toggle the reading light, or sit. The physical page heading and bookmark change
alongside the readable HUD text. Reading remains available with the light off.
The bench reuses the existing checked seat/stand controller, including standing
path, supporting floor and dynamic occupancy queries. While seated, E stands up;
RMB looks around and V changes camera. The workshop resident continues the
previous four-place routine during reading or sitting. No new NPC is introduced.

The reading light and page cursor are temporary visit state. Re-entering the
scene or successfully restoring an urban layout resets them; saving, failed
restore, missing-save restore and cancellation do not. They do not affect the
layout dirty flag or write to the five-field urban_free payload. The restore
confirmation explicitly includes this reset. The original world, quest and
private candidate files and save directory remain unchanged.

`urban_reading_room.gd` owns only its geometry and temporary presentation.
`modern_street.gd` composes its targets with workshop/terrace/resident targets and
handles them before the toolbox branch. Target checks retain distance, facing and
world occlusion. There is no book inventory, economy, mandatory task, hand animation,
extra collision exemption, downloaded asset or navigation replacement.

Validation is offline only: GDScript grammar parsing, resource resolution,
conservative fixed-geometry samples, seat exit paths and three eye-to-target rays,
plus source review. The grammar parser is not Godot's semantic compiler. Lighting,
glass sorting, glyphs, dynamic collision, camera and feel require later runtime
acceptance. **Godot import, gameplay, game tests, save I/O and builds: NOT_RUN.**

API references: [Godot 4.1 OmniLight3D](https://docs.godotengine.org/en/4.1/classes/class_omnilight3d.html)
and [Label3D](https://docs.godotengine.org/en/4.1/classes/class_label3d.html).

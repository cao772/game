# Enterable workshop and persistent street interactions

The modern street now has one workshop in the east/south block. Its hollow ground
floor connects the covered frontage to the rear lane through two independent
shutters. Nearby, visible targets expose E actions: open/close a shutter, switch
the interior lamp, pick up the single toolbox or place it on the bench, shelf or
yard support. No quest is required.

The other three blocks remain exterior scenery. Geometry is authored in metres;
door openings are 2.4 m wide and 2.5 m tall. The workshop replaces the selected
block's old solid ground floor and shopfront meshes while retaining its upper
floors and frontage pillars. Furniture stays clear of the through route.

## Interaction and ownership

`urban_workshop.gd` owns geometry and displays a state projection. The street owns
input, state and save operations. `urban_state.gd` holds five exact fields:
`schema_version`, `front_open`, `back_open`, `lamp_on`, `toolbox_anchor`.
The single anchor is one of `bench/shelf/yard/carried`. Taking and placing reject
invalid preconditions. Restores validate all fields before replacing the live
dictionary. Failed restore leaves current state intact.

Targets are chosen again in the physics frame that consumes E. They must be within
2.6 m of the eye, in the current viewing cone and visible to a physics ray. Only
the corresponding shutter body can count as a hit on its own handle; other walls
and furniture block interaction. Closing checks the player's current and next
projected capsule footprint with a safety margin. Placement rejects overlap with
the player. The toolbox uses authored supports, not arbitrary placement or rigid
body simulation; carried presentation is a proxy without hand IK or wall collision.

## Saving and returning

`urban_save_store.gd` reuses the existing immutable record protocol with only the
`urban_free` slot allowed. It never writes `world_free/free/chapter`, and the old
atlas and quest data are untouched. All slots still share the original bounded
directory and disk capacity; the new slot is not a separate quota.

F5 saves the five fields. Returning normally saves first; failure keeps the scene
open. The explicit no-save return requires confirmation. F9 asks before replacing
current changes. A successful restore resets the player to the street entrance so
restored shutters cannot appear inside the player. Carried state restores exactly
one held toolbox. Modern position and camera mode are not saved.

An initial `NO_SAVES` starts a new writable layout. Other read/semantic failures
block writes, preserving the old records; the player can retry or explicitly leave
without saving. Recovering an older valid store record is reported. Archival is
explicit and keeps the most recent 32 records without deleting older files.

## Review and pending acceptance

Offline GDScript grammar, resource resolution, preserved-file hashes, geometry and
cross-author source review are the permitted checks. They do not run GDScript or
establish Godot static typing, imported assets, actual collisions, lighting, input
feel or save I/O. Godot, game, tests and Windows build remain NOT_RUN.

Later runtime acceptance should cover both sides of both doors, diagonal approach,
blocked close while moving/jumping, full front-to-yard traversal, all toolbox
supports and a carried save/reload. Check failed writes, invalid payloads, missing
records, older-record recovery and canceled confirmations. The prior street
materials and urban visual direction are preserved; this remains source candidate
geometry, not final photorealistic art.

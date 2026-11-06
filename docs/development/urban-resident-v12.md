# Urban workshop resident: source candidate

This increment adds one optional conversation for a workshop resident. The public
name is the original, generic “工坊住户”; the short lines describe a person who
sorts screws carefully, notices small changes around the yard and enjoys familiar
workshop sounds. These are public proxy lines, not a private story character or
an adaptation of a copyrighted character.

## Panel and integration contract

`game/ui/urban_resident_panel.gd` extends `PanelContainer`. Add it below a
`CanvasLayer` or a full-viewport `Control`, not a layout container that overrides
its position. It hides first in `_ready`, uses centre anchors and viewport-sized
offsets, caps its size at 680 by 620 UI units, and leaves a 12-unit screen margin.
The full contents scroll vertically on smaller viewports. Labels wrap plain text;
there is no BBCode parser. The street provides the CJK font/theme.

Public methods:

- `configure(data: Dictionary) -> Dictionary`: validates the complete fixed
  configuration, then deep-copies it atomically. It returns `ok/code`; failure
  preserves the previous configuration. Reconfiguration while open is rejected.
- `open_resident(status: Dictionary, view: Dictionary) -> bool`: rejects invalid
  input, an unready/unconfigured panel or a second open. On success it deep-copies
  both inputs, fills the name, activity and greeting, and only then shows the panel.
- `close_panel()`: releases GUI focus owned by the panel or its descendants before
  hiding, clears the conversation snapshots, then emits
  `closed` once if it was open. Escape and the farewell button call this method.
  A repeated close is a no-op, including from a `closed` listener.

The root owns nearby E interaction, visibility/raycast checks and actor/player
pause. While the panel is visible the root must freeze the resident routine and
player movement, release mouse capture and suppress world interactions/save/load
hotkeys. A `closed` listener resumes them only if no other modal is open. The panel
processes UI while paused, but does not pause the whole tree itself or mutate doors,
lights, toolbox, quests, relationships, rewards or save records.

`status` has exactly `id`, `activity`, `goal`, `moving`, `blocked`, `phase`.
`id` is `workshop_resident`; `goal/phase` are `bench/shelf/yard`. While stopped,
`goal` names the next stop; while moving it names the active destination. `moving` is a
Boolean; `blocked` is empty or `gate/player/obstacle`. `activity` is single-line
plain text up to 96 characters. `view` is the unchanged urban state's exact five
fields, including `schema_version: 1`.

Buttons offer the next destination, toolbox placement, a three-line rotating
small-talk topic, the lamp and farewell. All replies use the opening snapshots.
Door detours/waiting are described only when `blocked == gate`; player and obstacle
blocks receive their own replies. Toolbox replies distinguish all four anchors,
including `carried`. Lamp-off greetings, toolbox replies and lamp replies state
that fine repair is deferred. A stationary bench activity is also replaced with a
lamp-off description to avoid showing a contradictory repair caption.

## Copy configuration

`game/content/urban_resident_lines.json` has exactly these top-level fields:
`schema_version`, `resident_id`, `display_name`, `greetings`, `destination_names`,
`route_replies`, `toolbox_replies`, `lamp_replies`, `small_talk`. The script defines
the exact required keys for each text map. Small talk contains exactly three
strings; reply/greeting limits are 240 characters, destination names 24 and display
name 40. Empty/whitespace-only strings and control characters other than permitted
line feeds are rejected. Schema accepts integer 1 or finite JSON number 1.0, but
rejects Booleans and other values. Configuration cannot add commands or callbacks.

An authorized private display-name overlay can replace `display_name` on a copied
dictionary before `configure`; the root owns that overlay and its source. This
public file contains no private names or personal identifiers. Validation limits
the copy structure; it does not establish the truth of arbitrary replacement prose.

## Routine and verification boundaries

The associated scene design is a single local loop: approximately 25 seconds by
the bench, 12 by the shelf and 20 in the yard, with independent movement between
stops. A closed rear door allows the front/south route when available; both closed
means waiting, and the player can block the route. The resident reacts to the lamp
and toolbox but never takes the box or opens a door. Actor implementation and root
integration are separate from the three files covered here.

The routine is not an all-day schedule or a city population simulation. NPC
position/phase and conversation progress are scene-local. Re-entering or a successful
urban layout restore resets the resident to the bench. The panel must already be
closed before restoring the urban layout; its small-talk cursor may remain at its
current position. Re-entering the scene creates a fresh panel and starts the cursor
from the first line. The five-field `urban_state` save schema remains unchanged.
The rotating topic cursor is private UI state, not a saved relationship or quest.

The panel passed offline GDScript grammar parsing. Its JSON passed duplicate-key,
exact-field, enum-map and text-length checks, including exactly three small-talk
lines. These are static source checks. No Godot
engine, GDScript execution, game tests, builds or save I/O were run. Layout,
focus/Escape, Chinese font display, path blocking and simultaneous door changes
still need runtime acceptance. The resident is a proxy presentation and source
candidate, not final character art or an independently verified playable feature.

# Moving work into the yard

The original yard support is now a standing workbench at a top height of 0.9 m.
It retains the `yard` toolbox anchor identity, so existing five-field layout saves
need no migration. The resident stands at (27,0,19.3), faces the table at z=20.5,
and can organize tools there when the box is present. Workshop lighting remains
an indoor requirement; the modern study currently has fixed daylight outdoors.

## Observable consequences

At a completed workbench stop, the box on `bench` and an enabled work light allow
indoor work. At the yard stop, the box on `yard` allows outdoor work independently
of that indoor switch. Taking the box stops the corresponding work immediately;
replacing it at the current stop allows work to resume. Shelved or carried tools
do not grant remote access. Dwell time continues without work conditions.

The sole surface box has a hollow body, hinged lid, handle and internal tool
proxies. The lid opens only during eligible work at its actual location. Moving
or hiding the box, losing indoor light, leaving the activity or pausing closes it.
Lid state is derived presentation, not a second box or new save field. The carried
proxy and existing pick/place controls remain unchanged. The tabletop details
leave the box slot and its interaction ray clear.

## Choosing the next destination

Destination changes happen only on departure from a completed dwell:

| Completed stop | Next stop |
| --- | --- |
| Indoor bench | Yard if the box is there; otherwise shelf |
| Shelf | Yard |
| Yard | Terrace |
| Terrace | Yard if the box is there; otherwise indoor bench |

Current route edges and selected phase do not change in response to a moved box.
The same next-phase function supplies real departures, conversation directions
and the close-door prediction. Gate-aware routes, slope arrival checks and player
obstruction remain. This is an authored conditional routine, not needs AI or an
instruction for the player to maximize productivity.

## One work rule across presentation

`runtime/urban_work_rules.gd` is a pure eligibility helper used by the resident,
workshop and conversation. It requires the six-field status to project a completed
dwell (`goal != phase`, not moving, no blocker), a matching toolbox location and,
for the indoor bench only, a boolean enabled lamp. Reset and transit states do
not qualify. The scene separately suppresses work presentation during modal/focus
pauses and conversation.

After layout input, `refresh_work_view()` updates work animation and description
without physics queries, movement, route changes or time advancement. The box is
then projected from that same layout. Successful restore clears arrival eligibility
until physics confirms the new pose; failure or cancellation preserves the scene.

## Dialogue compatibility

Schema 1 and the original three/four destination forms remain supported.
`work_small_talk` is independently optional alongside `location_small_talk`.
When supplied, it must contain exactly `bench` and `yard`, each with two validated
lines. While working it takes precedence; legacy configurations fall back to
general topics so old resting copy is not presented as a current work activity.
Unknown keys, malformed maps and invalid text still reject before replacing copy.

No save, quest, inventory or economy contract changes. There are no new models,
third-party dependencies, products, repair orders, rewards, weather or night-time
lighting rules. Geometry and licensed staging animation remain provisional.
The resident probe and modern-street camera directions use `global_transform.basis`,
the supported [Godot 4.1 Node3D](https://docs.godotengine.org/en/4.1/classes/class_node3d.html)
transform API, instead of relying on a newer `global_basis` convenience property.
Offline grammar, fixed geometry and source review do not prove live behavior.
**Godot import, gameplay, tests, save I/O and Windows builds are NOT_RUN.**

Runtime acceptance should cover all toolbox locations and light states, side access
while the resident works, mid-route box moves, box pickup during a work clip,
modal/focus pauses, restoration at both work sites and older dialogue configurations.

# Public terrace and reversible seated observation

The modern street gains a fixed public terrace at a floor height of 3 m in the
east yard. A short staircase and a longer switchback ramp form two ways up and
down. The original workshop, resident graph, parked vehicles and ground rear lane
remain. This is a one-storey public platform, not access to the six-storey homes.

## Space and movement

The main platform occupies x=28..36, z=6..13, with its slab underside at y=2.75
and cross-beam underside at y=2.60. A
2 m wide stair route rises from (37.2,0,3) to (37.2,3,11), then meets the east side
through an upper landing. It uses visible treads over a continuous collision
slope of approximately 20.6 degrees, within the existing walking controller's
floor limit. The treads do not introduce individual collision risers.

The longer route starts at (44,0,-3), rises to a half-height landing at z=9..11,
returns along x=40..42 to y=3, then connects through a bridge at z=-1..1 and a
walkway at x=32..34. Its two sloped segments are approximately 7.1 and 10.6
degrees. Rail openings follow those connections. These dimensions are authored
level parameters; actual traversal and construction appearance remain unverified.

The protected rear-lane band x=26.5..31.5 stays clear at ground level. Columns
sit outside it, while elevated deck clearance allows the original player through.
The resident's ground route around the south end and the yard toolbox support
are unchanged. New fixed scenery does not affect the existing layout save.

## Sitting and getting up

Approach the terrace bench and press E. Selection still requires a nearby visible
target; seating additionally requires the player to be grounded, on the same
level and within reach. Before moving the player to the seated pose, the controller
checks body clearance, supporting floor, a full standing-height sweep to the seat
and at least one usable exit. The seat surface is visual-only with a clear body
slot; the back and side frame retain collision. No entire world body is ignored
to make the check pass.

While seated, WASD and Space do not move or launch the character. Right-drag and
V still look around and switch between first person and close third person.
The sitting eye height is 1.20 m instead of 1.68 m. A separate bent-leg clothing
proxy displays the pose; this is not a finished rigged animation or final art.
E requests standing up and does not select workshop objects while seated.

Every stand request rechecks candidate positions, their support and the complete
path from the seat. Blocked exits leave the player seated. Same-level candidates
are bounded to 2 m, so the feature cannot teleport across a rail, gap or wall.
The root calls posture queries only in its physics-frame E handler.

Carrying the toolbox is allowed. Its single existing `carried` anchor remains
unchanged; the held proxy rests in front of the seated body rather than following
the camera's yaw. The resident's scene-local routine continues while the player
sits. Conversation/confirmation UI and lost input focus retain their existing
pause behavior.

## Restore, scope and pending acceptance

Sitting, player position and camera mode are not saved. F5 still saves only the
five-field `urban_free` layout. Successful F9 restoration uses `reset_pose()` to
clear the posture and stand candidates before returning the player to the street.
Failed or cancelled restoration leaves the current posture and scene intact.
Normal return still saves first; failed saving retains the current scene.

The three-region world, its snapshots, old quests, workshop state/store and
resident graph are preserved. No new daily schedule, weather, residential interior,
climbing system or NPC terrace visit is included. The new route and rest point
can be used without a task or relationship requirement.

Permitted checks are offline grammar parsing, literal-resource resolution,
fixed geometry review, archive readback and independent source review. They do not
run GDScript. **Godot import, gameplay, tests, save I/O and Windows export remain
NOT_RUN.** Later runtime acceptance needs both ascent/descent routes, ramp/deck
seams, rail ends, first/third-person sitting, carried-box visibility, obstructed
standing, focus changes and restore/save failures while seated.

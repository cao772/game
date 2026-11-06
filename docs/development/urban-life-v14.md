# A resident's break above the yard

The existing workshop resident now visits the public terrace as part of the same
scene-local routine. No second actor or quest trigger is added. The cycle is
workbench (25 active seconds), shelving (12), yard (20), terrace (24), then back to
the workbench, with physical walking between those stops. This is an authored
routine, not a full-day schedule or autonomous needs simulation.

## Shared space

The resident takes the stair branch through the north side lane and the ground
cross-route under the upper walkway. On the platform, the route avoids the bench
frame and drying posts and ends at a separate standing lookout. The player keeps
both stair and switchback routes, the seat, and the existing stand-up choices.
The resident does not claim the bench, follow the player automatically, open gates,
or take the toolbox. There is no task or relationship prerequisite.

The original gate-aware graph still governs workshop entry and exit. Closed rear
shutters allow a front-door detour when open; no available crossing means waiting.
Both shutters being closed does not block travel between two outdoor activity
points. Player obstruction pauses walking without skipping a waypoint. Elevated
waypoints require floor contact and height agreement, as well as horizontal
proximity, before being accepted. Normal travel never assigns world position.

## Conversation in place

The optional conversation retains schema version 1. `destination_names` accepts
the original exact three destinations or the current exact four; legacy copy gets
a generic terrace name internally. The optional `location_small_talk` map has
exactly `bench`, `shelf`, `yard`, and `terrace`, each with two validated lines.
When absent, the original three general lines remain available.

Location copy is used only while stationary and unblocked at that activity point.
Walking or blocked states keep the general copy, so a destination is not described
as a current location. An unlit workshop no longer adds a work reminder to every
outdoor greeting. Explicit lamp and toolbox questions still describe the actual
layout. Configuration is validated before replacing the previous usable copy.

## Pause, restoration and scope

The same scene owns physics advancement, conversation and focus/modal pauses.
Sitting does not pause the resident. Entry and successful layout restoration reset
the routine to the workbench; cancelled or failed restoration preserves the
current scene. Resident position, activity progress and conversation remain
transient. The five-field `urban_free` layout and old world/quest saves are unchanged.

This reuses the existing licensed staging character and the unchanged 013 terrace.
It adds no assets, engine dependency, private names or unpublished story material.
Offline grammar/resource review and static route checks do not establish live
physics, slope transition behavior, animation, camera clearance or UI readability.
**Godot import, gameplay, game tests, save I/O and Windows export are NOT_RUN.**

Later runtime acceptance should follow a complete four-stop loop, enter the stair
at both ends, block the actor on a slope and near each landing, change a gate while
crossing, sit while the actor arrives, open and close conversation at each stop,
lose focus during a climb and restore from an elevated location. Verify that old
three-destination conversation files still open and that no save schema changes.

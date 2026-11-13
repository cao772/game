# Delivery counter: source review and Windows walkthrough

The desk replaces the last blockout station. The table and clerk block the player; the front edge is within the interaction area. The clerk, parcel and sign use separate anchors. The fixed overview changes to a desk view during dialogue and returns on dismissal.

The shared quest and save code has no changes in this batch. On a successful handover, the controller plays Interact once and holds the receipt. On an explicit return visit it plays Cheer and displays terminal dialogue. Restore and mode changes derive the parcel and sign from the active node; they do not issue another delivery.

**Source checks.** The three furniture models resolve their buffers and common texture. The reduced character file keeps the upstream mesh payloads, 41-joint skin, texture and three animation tracks. Independent inspection covered the asset wiring, desk/collision dimensions, quest routing, and the handover/revisit/restore distinction. The clerk collider was added after review identified that the player could walk through its footprint.

**Still to verify in Godot on Windows:** import the source project and check all three clips on the rendered rig; approach the front and sides of the desk; confirm that the label, hand gesture, parcel and choices are visible at the default resolution; dismiss and revisit; save/reload before and after handover; enter a fresh chapter and return to the completed free slot. Engine import, gameplay, tests and Windows export were not run for this batch.

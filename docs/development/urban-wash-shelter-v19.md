# Public wash shelter · source slice019

The west rear lane now leads to an open preparation shelter with an eastern entrance, southern exit and a separate outside route. One public basin can move between a sink, preparation counter and draining counter. Water and produce stay with that same basin. No quest, new resident or reward system is required.

## Actions and visible state

- R picks up the basin at its actual station or places it on an aimed valid station. Current and predicted player/resident occupancy is checked before placement. A held toolbox, reading tray or basin excludes both other items at every pickup entry. Failed actions preserve existing ownership and contents.
- E at the sink toggles a tap that runs for at most6 active seconds, even without the basin. An empty basin at the sink must receive2 continuous active seconds before its water changes to clean. Taking it away or switching the tap off discards unfinished contact time. Returning it starts again. Used water cannot turn clean at the tap.
- E at the preparation counter requires the basin there, clean water and unwashed produce. One action groups the produce, displays scraps on the counter and changes water to used. Repeating it does not create more produce or reset contents.
- E at the draining counter requires the basin there with nonempty water. It empties the water while preserving produce, then shows3 active seconds of residual drainage at the station. The residual drip stays at the station if the basin is picked up. An empty-basin action does not restart the effect.
- F remains reading. The basin can be carried while using an existing seat; E still attempts to stand and R refuses seated pickup/placement. The held pose follows the existing seated fixed forward direction. There is no hand skeleton attachment, throwing, physical stacking, spill/weight system or fluid simulation.

The same bowl node contains its sides, water surface and produce displays. Water is an opaque flat visual, clean/used have different colors, and HUD text also states their meaning. Unwashed and washed produce use alternate child groups, not extra inventory items. This is a stylized interaction proxy; final food and liquid art remain to be made.

## Time, pause and restore

Each enabled physics frame advances at most0.1 seconds. Fill uses min(step, tap_remaining) before decrementing the tap budget, so a short final flow interval cannot grant a full step of water. The root advances this interval before consuming at most one player action; pickup/stop then immediately clears unfinished fill credit. No Timer, animation callback or asynchronous operation changes the basin.

Pause, focus loss and modal panels freeze the tap/fill/drip budgets and hide flowing water immediately. Contents remain visible. On resume the remaining active time continues, without offline catch-up. This differs intentionally from closing the tap, which clears unfinished fill contact.

Basin anchor, water, produce, tap/contact/drip times and scraps are scene-local. F5 still saves the original five urban_free fields. Scene entry and successful explicit restore put the basin at the sink with no water, unwashed produce and closed flow; the tray resets before the old saved toolbox is projected. Failed/cancelled/no-record restores, save failures and failed scene changes preserve the current visit. Save/restore/leave messages state these boundaries.

## Space and preserved behavior

The shelter spans x=-46..-32.5 and z=7..14.5, with six0.18m posts, lowest beam underside2.65m and roof underside2.80m. Three solid counters use0.85/0.78/0.85m tops; basin bottom anchors sit directly on those supports. Existing grade, west lane, parked vehicles, benches, reading-room walls/targets and visitor graph remain intact. These are authored game dimensions.

Source changes are one new world module and street integration. Existing control, workshop resident, reading visitor, reading tray, runtime and old quest/world save interfaces remain unchanged. No external assets or dependencies were added.

## Validation

31 GDScripts passed offline grammar parsing (gdtoolkit4.3.4, not Godot4.1 semantic compilation);88 public literal resource references resolve. Static checks cover57 fixed boxes,17,435 path samples and12 target rays, including old reading/standing paths, visitor graph edges, eight new shelter routes, three new station rays and bowl support bounds. Separate review results are recorded in delivery evidence.

Godot import, gameplay, game tests, save I/O, builds, dynamic collisions, hand contact, rendered liquid and camera behavior remain NOT_RUN. Static space checks do not establish actual playability or rendering quality.

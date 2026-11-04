# Bounded scene source review — batch 003

Date: 2026-11-04. Author self-review; not independent review, engine validation, player testing or acceptance. Scope: new scene/player source, main-scene resource, sample presentation, existing application/session contracts. Historical component reviews remain historical.

## Design and source paths

- One root Node3D owns one application throughout this single location; mode switches do not recreate it. No competing session owner or shared-interface changes.
- Player collision layer 2; solids layer 1; observation masks layer 2. A nearest overlapping station is selected; interaction rechecks overlap. Observation zones cannot grant COLLECT or DELIVERED facts.
- Collection station is the dialogue point for unstarted/PREPARE/PLAN/REST. ARRIVE/COMPLETE use the recipient. Dialogue immobilizes the player and closes after each command, preventing a remote handover through a retained menu.
- Route A OR route B enables TAKE_ROUTE; helper independently enables ASK_HELP. WAIT returns through REST/RETRY without losing facts. Paths are synthetic choices, not separate simulated routes or a balanced risk system.
- Completed state drives recipient material AND label from present(), including after load/mode changes. No reward side effects are attached to rendering.
- Read-only objective text provides the next action. Chinese sample text replaces English presentation without changing definition identity/hash or save schema.
- Movement is normalized and disabled during dialogue, confirmations, numeric text editing and window focus loss. A fixed camera avoids capture/focus complexity. Wall/floor collision and out-of-bounds recovery are authored but not physics-tested.
- Explicit load/archive/mode commands capture the current revision. Restore warns about replacing unsaved progress. Save-before-switch remains in the existing application; rejection does not reset position or mode. Successful restore/switch returns to the entrance; player/world transforms are not persisted.
- Archival may partially succeed. UI reports moved generation IDs, failure code and warning presence without exposing receipt paths; files are not deleted by scene code.

## Paper walkthroughs (not executed)

1. Start -> COLLECT -> observe A or B -> TAKE_ROUTE -> walk to recipient -> HAND_OVER -> COMPLETE -> save -> revisit displays completed label.
2. Start -> COLLECT -> observe helper -> ASK_HELP -> recipient -> HAND_OVER. No route fact required.
3. PLAN -> WAIT -> REST -> inspect a route -> RETRY -> PLAN -> TAKE_ROUTE. Reopening collection dialogue shows current options.
4. Enter chapter saves free first; independent chapter starts. Leaving saves chapter then restores free identity. Position resets; terminal visuals are recomputed. Resume chapter requires entering then explicit load.
5. Missing/corrupt/incompatible save: existing store/coordinator rejects or skips as documented; scene reports result without resetting player. Confirm cancel does nothing. Stale revision rejects operation. No auto-load overwrites an active session.
6. Archive failure: moved records are listed even on failure; warning retained. Generation field restores only active mode. Large lists scroll rather than hiding the remaining controls.

## Remaining validation and limits

Godot parsing/import, engine compilation, physics overlap timing, input focus, actual UI fit and CJK font fallback, Windows startup/save/error injection and export: **NOT_RUN**. No screenshot, executable, performance result or playability claim. The fixed camera, static primitives and generic task are integration scaffolding, not final third-person controller, art or authored story content. No full-world persistence, multi-process lock, scene transitions, pause/settings, automatic saves, quest inventory or Windows package yet.

When execution is authorized: verify both prerequisite routes, WAIT/RETRY, wrong-station interaction, input focus loss, all recovery confirmations, failed save-before-switch, restore into completed state, archive partial failure, and chapter/free isolation on the pinned Windows engine build.

API references inspected: [Godot 4.1 CharacterBody3D](https://docs.godotengine.org/en/4.1/classes/class_characterbody3d.html) and [Input](https://docs.godotengine.org/en/4.1/classes/class_input.html). The Input documentation notes global polling bypasses Control event handling; explicit UI/focus movement gating accounts for that. Exact release engine remains to be pinned.

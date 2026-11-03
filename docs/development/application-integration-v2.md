# Quest application and interaction adapters — source contract

Task GAME-RUNTIME-FOUNDATION-002. Implementation and independent static review only; engine import, compilation, tests, game execution and Windows packaging **NOT_RUN**. These scripts have no main scene or deployed preview.

## Ownership and construction

One future scene/application owner retains a `QuestApplication` instance across scene changes. The instance owns its `SessionCoordinator`; the coordinator owns separate free/chapter runtimes and one save store. World nodes and UI receive that application instance, not a mutable quest dictionary.

`configure(definition, presentation)` validates both inputs before committing them. Reconfiguration of an existing application is rejected; it is not an implicit destructive new-game command. `synthetic_delivery.json` and `synthetic_presentation.json` form a public, non-canonical example pair. Do not substitute an unpublished narrative package into the public repository.

Presentation has exactly `intro_key`, `observations` and `dialogue`:

- `observations` maps a bounded ASCII interaction ID to a defined fact. A fact granted by any quest action cannot also be a world binding: this keeps the scene from bypassing collection/completion actions accidentally.
- `dialogue` maps every referenced introduction, node and action text key to `{speaker, text}`. Missing lines, invalid types or excess sizes reject configuration. The UI renders plain text, not markup.
- The mapping is authoritative application input. It does not itself prove player distance, identity, line of sight or that an interaction happened. The scene/controller must make those checks.

The synthetic bindings are `LOOK_AT_ROUTE_A`, `LOOK_AT_ROUTE_B` and `SPEAK_TO_HELPER`. They report route/help facts only; neither `PARCEL_COLLECTED` nor `DELIVERED` is available as a world observation binding.

## Commands and stale UI

`present()` is a read-only projection with mode, current node, started/terminal state, speaker/text, available options and `revision`. Calling it repeatedly never starts a quest, grants a fact, saves a file or changes mode.

Commands use the revision from the presentation that initiated them:

| Method | Effect |
| --- | --- |
| `start(revision)` | Explicitly starts the active quest |
| `observe_interaction(id, revision)` | Maps a registered world interaction to one defined observation |
| `choose(action_id, revision)` | Applies an available action in the active runtime |
| `save(revision)` | Saves the active slot only |
| `load_latest(revision)` | Stages and restores the newest storage-valid active-slot record; semantic mismatch is a rejection |
| `load_archived(generation, revision)` | Explicit archived-generation load through the same semantic validator |
| `archive_saves(revision, keep=32)` | Explicit nondeleting archive maintenance; no automatic call on a timer or every save |
| `enter_chapter(revision)` | Saves free progress before creating an isolated fresh chapter |
| `leave_chapter(revision)` | Saves chapter progress before returning to the retained free session |

Every successful quest mutation, load or mode switch advances the revision, including an idempotent observation. A stale command returns `STALE_PRESENTATION` without forwarding it. Save and archive do not change live quest state, so they do not advance it. Callers refresh after external world events and commands; there is no hidden polling or global signal in this module.

Mode switches fail without changing the live mode if saving fails. This does not make chapter/free saves a single disk transaction: the chapter and free records remain distinct. A chapter record cannot restore the free world. A future recovery screen must surface errors and offer explicit archive/recovery rather than silently discard progress. Scene teardown/quit autosave is also still a future owner responsibility.

## World observation area

`world/quest_observation_area.gd` is an `Area3D` adapter with an exported `interaction_id`. Its explicit `interact(actor, application, revision)` rejects invalid/out-of-tree objects, a paused tree, disabled monitoring and non-overlapping bodies. No body-enter callback automatically awards a fact.

The future scene must attach a collision shape, configure collision layers/masks, supply the authorized player body, enforce any targeting/line-of-sight rule and choose the interaction deliberately. An overlapping body alone is not player identity authorization. Area overlap lists update with physics steps; the adapter does not claim immediate geometric truth after a teleport. See the official [Area3D API](https://docs.godotengine.org/en/4.5/classes/class_area3d.html).

## Dialogue panel

`ui/quest_dialogue_panel.gd` is a reusable `VBoxContainer`. `bind_application` builds/reuses speaker/body/notice labels and an options container, then refreshes the read-only projection. It exposes explicit start and current available-choice buttons with keyboard focus enabled. World observations are never inferred from missing prerequisites or button labels.

Callbacks capture the application's revision and a panel binding epoch. Revision protects progress changed by observation/load/mode switch; epoch protects rebinding the same panel to a different application whose numeric revision might coincide. Detached, hidden, paused or busy panels do not submit. Old buttons are removed before the completion signal is emitted, so a navigation listener cannot retain a live stale menu through the normal panel path.

`command_finished(result)` lets the scene owner update related UI. The panel does not contain save/archive/mode controls yet. Theme, layout in a real viewport, first-focus selection, long-text scrolling, localization and accessibility verification remain scene/UI work. Source construction of controls does not prove they display correctly.

## Static walkthroughs, not test results

1. **Start and observation:** configuration produces revision 1 and introduction text without starting. Clicking start applies the start command and refreshes. At PLAN, TAKE_ROUTE is unavailable until a registered route interaction reports its fact. Refreshing alone cannot reveal it.
2. **Stale choice:** a menu captures revision R; an observation or load advances to R+1. Clicking the old menu reaches the guard and rejects; the panel refreshes instead of executing the action against different progress.
3. **Panel rebind:** a panel holds a callback from application A at revision 2; it is rebound to B also at revision 2. The changed epoch rejects A's old callback before contacting B.
4. **Mode ownership:** enter saves free first, then switches to a fresh chapter and invalidates the old menu. Leave saves chapter first and restores the same free instance. If either save fails, the switch does not happen. No chapter action transfers free facts.
5. **Archive restore:** an explicit archived read validates record identity/hash and then stages a quest instance for mode/schema/definition/path validation. Failure keeps the live quest and revision. Success replaces only the active session and invalidates prior options.

All five need later permitted engine/runtime verification. Other release blockers include a full scene route, world persistence, authenticated reward ownership if introduced, process-level save writer exclusion, archive capacity handling and actual Windows I/O/recovery behavior.

The project feature declaration is 4.1 because the save writer uses [GDScript static variables](https://docs.godotengine.org/en/4.1/tutorials/scripting/gdscript/gdscript_basics.html#static-variables). This corrects the earlier 4.0 declaration; it does not pin a release engine or assert all API behavior has been tested on 4.1.

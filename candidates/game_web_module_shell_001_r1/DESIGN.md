# Shell design and private adapter proposal (not approved)

## Composition

```text
Standalone project.godot
  └─ shell_demo.tscn (Control)
      └─ shell_candidate.gd
          ├─ overview, menu navigation + status
          ├─ slot round    ── local synthetic adapter
          ├─ slot prompt   ── local synthetic adapter
          ├─ slot profile  ── local synthetic adapter
          └─ slot bindings ── local synthetic adapter
```

No instantiated upstream nodes. The shell has zero `res://` dependencies
outside its own folder. The generic shell emits only `page_changed` and
`simulated_request`; a simulated_request is **not** a gameplay command.
No signal is connected to the #6 coordinator or any persistence writer.

## Proposed, shell-private contract

- `show_page(page_id: String) -> bool`: only `home`, `round`, `prompt`,
  `profile`, `bindings`; unknown IDs return false without changes.
- `current_page() -> String`: selected menu page.
- `install_adapter(slot: String, adapter: RefCounted) -> bool`: only the
  four named slots, with `preview()` and `preview_action(String)` methods;
  rejected installs preserve the previous adapter.
- `remove_adapter(slot: String) -> bool`: missing slot becomes an explicit
  "not connected" page, never silently pretends integration.
- `has_adapter(slot: String) -> bool`: local registration presence only,
  **not** upstream readiness or compatibility.
- `preview() -> Dictionary` should yield `ok: bool`, `title: String`,
  `body: String`. The shell checks types for text keys and gives a fallback.
- `preview_action("sample_request") -> Dictionary` is a **demo-only**
  request and result; the built-in adapter returns `simulated: true`.
- `simulated_request` is emitted only for accepted local demo replies;
  there is no implicit game mutation or success claim about an upstream module.

An externally injected adapter would be executable code and must be separately
reviewed and trusted. Method-presence checks do **not** sandbox arbitrary
RefCounted objects or guarantee no side effects. Do not inject a real game
adapter until author-approved contracts, permission and tests exist.

## UI behavior

- Side navigation switches Control text inside one local scene. Overview does
  not show the mock-action button.
- Each missing slot visibly degrades; registration/restoration refreshes the
  current page.
- Generic text samples and simple dark navy visuals are **design proposals**.
- Tab and native Button focus are delegated to the Godot Control UI; no custom
  Escape/1/2/3/R listener, no input remapping, no InputMap mutation.
- Mock request is blocked if the SceneTree is paused or the native window is
  unfocused, but this is UI behavior, not a security gate.
- UI text is assigned through Label.text, not interpreted as rich markup.

## Integration path after explicit author approval (future, not implemented)

1. Pin compatible revisions of each PR and resolve conflicts, especially #15
   stacked on #6 and focus/Escape handling with #10.
2. Define reviewed external contracts and a single input/action ownership model.
3. Create separate bridge candidates (outside this r1 module) that translate
   approved data for the four slots; no direct save calls from the menu.
4. Test each bridge in isolation, then combined native/window/paused scenarios;
   record SHA, Godot version, command, exit status and evidence.
5. Get author review before changing shared APIs or merging any Draft branch.

## Explicit non-goals

No narrative, characters, map, original manuscript, real interactables, game
state, history/free clock, key configuration persistence, network, runtime asset
loading, source copying, modification to main, other modules or shared scripts.

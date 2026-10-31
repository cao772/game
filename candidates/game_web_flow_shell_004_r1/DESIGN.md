# Independent flow composition — design tradeoffs (r1)

**All design choices below are proposals; author approval and execution pending.**

## Topology

```text
project.godot → flow_entry.tscn (FlowRoot)
  └─ Shell: pinned PR #17 shell_demo.tscn (unchanged copy)
       ├─ legacy menu and assembly registry, incl. missing/disabled/pending
       └─ Page VBoxContainer
           ├─ legacy page text / mock-request button (hidden only when mounted)
           ├─ dynamic IsolatedModuleStage (created by flow_root.gd)
           ├─ provenance/status notice
           ├─ Begin synthetic flow
           └─ Continue synthetic flow
                 ↓ local bridges, no shared API registration
       ├─ PR #10 pinned local prompt scene: show_for_targets, notification only
       ├─ PR #14 pinned local profile scene: set_profile(synthetic Dictionary)
       └─ PR #15 pinned settings facade: memory-only preview/rebind/reset
```

## Lifecycle

1. Root receives `page_changed` and `assembly_changed` from the local
   copy of PR #17 shell. Each change disposes the prior stage.
2. For prompt/profile/bindings pages only, require shell registry status
   `synthetic_ready`; otherwise retain the legacy visible fallback.
   The registry's status means **mock ready** and never certifies the source.
3. An adapter checks the existence and type of a **fixed local resource path**
   and the exact callable methods from the read source before mounting.
   Any error returns a visible explanation rather than an invented API call.
4. When mounted, the wrapper hides the legacy label/mock button and shows
   the actual isolated widget. Navigation to other pages disposes it.
5. Input configuration object stays in memory until the wrapper is freed.
   It is not an input router. No file persistence methods are invoked.
6. The explicit flow step transitions are prompt → profile → bindings →
   overview. A failed/missing step stays navigable and can be skipped by
   the Continue button; there is no non-consensual data mutation.

## Concrete interface choices

**Prompt:** use PR #10's current `show_for_targets`, not the obsolete
single-target-only assumption. Supply two unique synthetic IDs and labels;
its `interaction_requested` signal updates only a local status label.
`hide_prompt` is called when leaving so it can attempt focus restoration.
No automatic gameplay consequence, target discovery or external dispatch.

**Profile:** use current PR #14's strict Dictionary validator, including
`schema_version=1`, `profile_id`, `display_name`, `subtitle`,
`summary`, `status_label`, `tags` and `sections`. Provide explicit
synthetic sections/items; no actual author character/person data.

**Bindings:** use the PR #15 settings facade's preview-then-apply methods,
its real binding collision checking and its memory-only reset. The wrapper
uses fixed example keys; it does not trap keyboard input, read files, save,
autoload, create an InputMap action or forward a key into PR #6.

## Reasoned tradeoffs

| Choice | Why | Rejected |
|---|---|---|
| New branch from main, copied pinned public sources | Isolated branch; preserves old Draft code and enables reproducible source diff | Editing #17 or merging unapproved PRs |
| Wrap the shell instead of rewriting its source | Retains r1 navigation, degradation, settings and history unchanged | Replace shell with new shared navigation API |
| Fixed local ResourceLoader paths | A missing local candidate becomes a visible degraded view; no dependency hallucination | Reflective plugin scan or remote fetch |
| Real vendor UI copies behind bridges | Actually exercises target methods at source level rather than drawing mock descriptions | Only duplicating text from PR summaries |
| PR #15 configuration without #6 routing | Key collision model is useful in isolation; no authority to change game state | Integrating PR #15's keyboard router into unapproved #6 writer |
| Synthetic IDs/profile only | Public PR has zero manuscript/real character disclosure | Copying story/canon or historical conversation |
| Explicit next-step button; no auto transitions | Focus restoration, action consequence and modal priority are unapproved | Prompt interaction silently changing state |
| Failed mounts fall back to shell page | Menu and recovery remain usable | Crash or treating component absence as 'available' |
| Local preview/apply/reset only | Avoids accidental user:// writes and time/save collisions | Exposing original optional disk APIs |
| NOT_RUN evidence discipline | Source correctness and UI quality are unproven until Godot/CI executes | Claiming tests from committed verifier source |

## Known hazards / what this does NOT solve

- The vendored GDScript is not sandboxed code. The project loads **only pinned
  local public candidates**, never private resources or arbitrary paths.
  Inspect all code before approving execution.
- Source copied from separate Drafts has not been compiled or run as one
  Godot project; parser errors, duplicate classes, focus priority, renderer
  layout and signal races may exist.
- Main PR #17 menu's assembly scenarios still operate on its own **mock**
  registry. `synthetic_ready` grants this wrapper permission to try a local
  copied component, but is not an upstream health certification.
- If the local resource or interface is missing, the wrapper falls back.
  It cannot guarantee that a structurally compatible but broken method
  won't raise an error at runtime. Future negative tests and manual QA needed.
- No actual scene/character/target discovery, no save semantics, no free/historic
  clock, no network, no key-dispatch game action, no production interfaces.
- Accessibility, narrow screen, IME, keyboard focus and pause behavior remain
  native **NOT_RUN** checks, not assumptions about working software.

**Reviewer final gate:** inspect source/PR diff and exact dependency commits,
then separately authorize Godot tests, native UI evaluation and possible
future bridge specifications. No implicit author approval is asserted.

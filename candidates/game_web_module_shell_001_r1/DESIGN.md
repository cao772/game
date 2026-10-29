# GAME-WEB-CONTINUE-SHELL-003 r1 — Architecture and design decisions

All contracts in this document are **shell-private proposals**. No upstream
Draft PR is approved, validated or mounted. Every future test is **NOT_RUN**.

## 1. Actual design

```text
Standalone Godot 4 project
  shell_demo.tscn (local Control scene)
    └── shell_candidate.gd
          ├── overview + six menu pages + bounded back-history
          ├── module assembly UI (slot, scenario, apply, refresh, reset)
          ├── action guard (tree, pause, native focus)
          └── module_registry_candidate.gd (memory only)
                ├── round    → local PlaceholderAdapter OR unavailable
                ├── prompt   → local PlaceholderAdapter OR unavailable
                ├── profile  → local PlaceholderAdapter OR unavailable
                └── bindings → local PlaceholderAdapter OR unavailable
```

An adapter's `preview()` supplies a plain-text display proposal; its
`preview_action("sample_request")` can be accepted only as a local
`simulated: true` demo response. No adapter is loaded from another PR.
No actual target, state, story, character or input configuration is created.

## 2. Assembly model

Each fixed slot has one in-memory entry containing `mode`, `health`,
`reason`, optional trusted local adapter and cached preview. A slot can be
`mock`, `missing`, `disabled`, or `pending`.

Effective statuses:
- `synthetic_ready`: local preview validated; *not* upstream readiness.
- `missing`: no executable module or synthetic instance.
- `disabled`: explicitly disabled; menu remains selectable.
- `degraded`: local mock responded with missing/non-bool `ok`, non-string
  title/body, empty/oversized title, oversized body, or invalid action reply.
- `blocked_dependency`: #15 is staged while #6 is not staged.
- `pending_review`: PR reference is staged for design review only, with no
  adapter or action dispatch; even #15 + #6 together remains pending review.

Staging does not imply availability. The dependency model reflects the actual
#15 stacked Draft relation, but **does not** model real compatibility. All
four slots remain distinct despite their common display shell.

The registry exposes read-only status snapshots containing **no live adapter
objects**, and duplicates preview dictionaries before caching. Unknown slots
are rejected. Installation of an adapter missing either required method
returns false without replacing the prior entry. A broken preview changes the
slot to `degraded`; the button is disabled. Explicit `refresh(slot)` is
the only probe/recovery path besides re-entering that page or reinstalling
a local placeholder; there is no polling thread.

## 3. User paths

**Navigation:** `show_page` only accepts `home`, `round`, `prompt`,
`profile`, `bindings` or `modules`. A changed page pushes the previous
page onto a 24-entry bounded stack; same-page and invalid requests do not
add entries. `go_back` pops without pushing a reciprocal history entry.
The module menu remains navigable in missing, disabled and pending states:
failure never collapses the entire shell to a blank screen.

**Assembly page:** Choose slot → choose local simulation mode → Apply.
The input selection is validated. A result updates a readable status
label and overview. Manual refresh does not restore an intentionally
missing/disabled/pending slot. Restore All rebuilds only *synthetic*
instances and does not resurrect or auto-load real components.

**Preview:** A successful plain-text mock `preview()` is cached in memory.
Failure displays a visible fallback explaining the reason and that no
upstream code is imported. It never exposes arbitrary Dictionary content
or treats the error as gameplay success.

**Mock request:** the only action string is `sample_request`. The caller
must be on a module page, the SceneTree must be active, and the native
window focused (unless the deterministic future-test focus override is
used). An adapter response must be a Dictionary containing actual bool
`ok`, actual bool `simulated == true`, and a short String `message`.
Invalid contracts degrade the slot and suppress `simulated_request`.
An ordinary `ok: false` declines without emitting a simulated signal.

## 4. Design decisions and reasons (made by implementation, for final review)

| Decision | Why | Rejected alternative |
|---|---|---|
| Fixed four-slot catalogue | Source PRs have no approved manifest or discovery API; keeps scope reviewable | Reflection of other PR directory trees or dynamic resource imports |
| Start with valid local mocks | Usable independent demo without borrowing unapproved PR APIs | Attempting to instantiate unmerged scenes |
| Metadata-only candidate staging | Accurately distinguishes source existence from executable readiness | Treating a PR number as a loaded module |
| Fail-closed on malformed preview/action | UI stays navigable without silently issuing real actions | Falling back to an unknown live coordinator |
| Keep missing modules in menu | Allows diagnosis and recovery paths, unlike hidden/vanishing pages | Remove navigation entries when unavailable |
| #15 depends on staged #6 only for status display | Reflects actual stacked Draft history without assuming interoperability | Automatic bridge into #6's input router |
| Explicit local Reset/Refresh only | Prevents background polling and unexpected filesystem/network calls | Silent auto-reload/discovery |
| Bounded back history and native Button focus | Minimal familiar navigation and no global key interception | Reusing #6/#10/#15 Escape handlers |
| Only local synthetic request string | Prevents accidental interpretation of round/cancel keys | Forwarding user action IDs to a game controller |
| No IO/JSON settings persistence | Prevents clock, snapshot and key-config collisions | Sharing candidate `user://` paths |
| In-memory candidate status rather than durable feature toggle | Product-level lifecycle and user preference are unapproved | Inventing a production settings contract |

## 5. Threat and failure boundaries

- A caller-supplied `RefCounted` is executable. Structural inspection is
  *not* sandboxing. Only shell-owned or audited **synthetic** adapters may
  be mounted; staging external candidates uses no executable object.
- Local preview probes are called only by explicit install/refresh/navigation.
  Their behavior is not guaranteed if someone injects hostile code.
- No load(), preload(), ClassDB reflection or resource traversal of any other
  Draft candidate, no InputMap mutation, no autoload, no file or network IO,
  no save/round clock or event dispatch.
- All actual upstream PR methods, especially #6 `request_button_action`,
  #10 `show_for_target`, #14 `set_profile`, and #15
  `attach_integration`, are deliberately **not invoked**.
- Engine version, native focus/IME, accessibility, narrow window,
  controller support, event ordering and real inter-PR compatibility are
  unverified. This source-only submission cannot certify them.

## 6. Future integration gate (not performed)

1. Author approves a Godot engine version and intended hosts.
2. Pin source commits, approve data/ownership contracts and settle
   Escape/focus/pause arbitration across #6, #10 and #15.
3. Review separate typed, permission-scoped bridges; never give menu
   code direct ownership of a writer.
4. Run isolated regression, dependency order, native keyboard and
   fail-closed checks; record SHA, command, exit code and screenshots.
5. Keep Draft until final author review; only then consider changes
   to shared interfaces or any merge.

**Only this shell folder changes. No change to main or other windows.**

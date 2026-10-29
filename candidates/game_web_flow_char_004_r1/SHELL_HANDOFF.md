# Shell integration boundaries — GAME-WEB-FLOW-CHAR-004 r1

**Proposal only / NOT_RUN / no shared-interface approval.**

## Actual observed shell PR #17 boundary

Read PR #17 at \`5ed0602cfb7498900dee13936194bac69d7c9737\`:
\`shell_candidate.gd\`, \`module_registry_candidate.gd\`,
\`placeholder_adapter_candidate.gd\`, \`DESIGN.md\`.

The shell currently has menu pages including \`profile\`, but only
plain-text preview + simulated request, mediated by trusted local
RefCounted adapter methods. It does not offer an approved Control-scene
mount slot or data injection for the PR #14 panel.

Therefore this contribution makes **two separate candidate seams**:

### A. Mock-only / metadata compatibility with current shell

\`shell_profile_adapter_candidate.gd\` is a self-contained RefCounted
implementing:
- \`preview() -> {ok: bool, title: String, body: String}\`
- \`preview_action("sample_request") -> {ok: bool, simulated: true, message: String}\`

The shape matches the private shell PR #17 registry's inspected
\`mount_mock("profile", adapter)\`, \`refresh\`, and \`invoke_mock\`
requirements. Text is synthetic. The adapter does **not** instantiate
the flow, open a detail, issue gameplay requests, read disk, run network
code or modify any other project's state.

A *future* reviewed experiment may supply a trusted local adapter to
the shell's profile slot. No such mount or test occurred in this task.
Copying this script to the shell project would be a separate reviewed
change; **the shell branch is unchanged by this PR**.

### B. Real, standalone Control-scene embedding (not yet in shell PR #17)

A suitable independent host can instantiate the PackedScene
\`profile_flow_candidate.tscn\` in a Control container, then call
\`load_placeholder_profiles()\` or \`set_profiles(...)\`. The host can
listen to \`exit_requested\` and decide where to return. This flow
exposes no global key bindings and never calls the shell directly.

To embed into PR #17 later, the shell maintainer would have to add a
Control host to its \`profile\` page, manage mount lifecycle, exit focus
and degraded/disabled state, and review interactions with the shell's
bounded navigation history. This is intentionally **not implemented
inside shell PR #17** and cannot be claimed as integrated or verified.

## Reasons and explicit refusals

- **No direct calling shell.show_page()** from the flow: shell routing
  ownership and its back-history implementation are unapproved here.
- **No duplicate shell source or scenes** in this candidate: only the
  public PR #14 renderer files necessary for a standalone demonstration
  are snapshot-pinned, preserving scope and provenance.
- **No implicit link between mock and real UI**: PR #17's mock registry
  only renders strings and labels simulated requests. It cannot render
  this Control scene unchanged.
- **No arbitrary module loading**: shell warns that a RefCounted
  adapter is executable code, not a sandbox. Only reviewed local
  synthetic source should ever be passed to that private mock seam.
- **No official data adapter**: only the fixed synthetic fixture and
  strictly validated in-memory dictionaries are supplied.

All expected integration cases are described in \`ACCEPTANCE.md\` and
remain **NOT_RUN**.

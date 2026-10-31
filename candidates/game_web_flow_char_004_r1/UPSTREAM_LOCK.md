# Immutable public technical source snapshots — FLOW-CHAR-004 r1

**Read-only provenance. No canon or private material. NOT_RUN.**

Source: Draft PR #14, branch \`codex/game-web-module-char-001-r1\`,
commit \`ce88e48c2056c887232b98ebf73f4d61ab58ace2\`.

The following new files within this Flow candidate directory refer to
**exact same Git blob objects** as their #14 source, without editing them.
The source's \`res://\` paths assume the root of a Godot project, so these
root-level copies support an isolated Godot project without touching PR #14.

| Filename | Exact Git blob SHA |
| --- | --- |
| character_profile_panel.gd | eac20b7ab50052793098f7cee05783c19225e7b7 |
| character_profile_panel.tscn | c58a6ac2a0259ee7bcb3ffc1d5bff7f4ccada670 |
| profile_contract_candidate.gd | bd52576b13175206a18cba986157af4dd3e84b8e |
| profile_scroll_navigation.gd | 24bcfb02eb030a01c86098d98e6d34af64436a63 |
| profile_text_layout_candidate.gd | 61e654bc79ba12335f25fa5ecc15e6005bb3a5b3 |
| preview_panel_resource_candidate.gd | 8fa79bf6c0d5a1e021bdf73d88ea3d5733f9f8a1 |
| placeholder_fixture_loader_candidate.gd | dff5d6217355c5da444c9aad59b414be3e58a4b0 |
| placeholder_profiles.json | 269b46691511512e8203db0812dd62a49f1b6458 |
| data_contract.schema.json | 6ff1f7a3bef0fc83c080a00bc9b947d015a93733 |

Shell reference (read-only, **not copied**): Draft PR #17 head
\`5ed0602cfb7498900dee13936194bac69d7c9737\`,
files \`shell_candidate.gd\`, \`module_registry_candidate.gd\`,
\`placeholder_adapter_candidate.gd\` and \`DESIGN.md\`. The observed
profile slot is a trusted-local RefCounted mock interface; no real
Control slot is approved by that source.

**Upgrade policy (future proposal only):** if #14 changes, inspect and
pin the new exact file set, update this lock record and re-run all Flow
tests. Never auto-copy changes or silently mark them compatible.

This is a source provenance record, not a test log, private transcript,
runtime validation or author-approved integration artifact.

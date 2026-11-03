# Independent integration source review

Date: 2026-11-03. Reviewer: separate baseline/integration review agent; not the component authors. Read the three runtime source files, the contract, synthetic content, project configuration and delivery roadmap. Source reading and paper tracing only: **no engine, script, import, parser, tests, CI, build or deployment executed**.

## Result

No definite release-blocking source-level defect was identified within the reviewed foundation scope. This is not a compilation result, functional acceptance, device compatibility claim or approval to release. The runtime is a small source library with no main scene, not a finished playable chapter.

## Cross-component checks

| Check | Source evidence | Static conclusion |
| --- | --- | --- |
| Script ownership and paths | `session_coordinator.gd:5-11`; project root is `game/` | Preloads point to the runtime scripts under the declared resource root. Fields and method return types use the preloaded script aliases, not a bare RefCounted API assumed to have custom methods. Engine resolution remains NOT_RUN. |
| Configuration staging | `session_coordinator.gd:15-25`; `quest_runtime.gd:30-44` | Coordinator constructs and validates a new instance before retaining it; repeat coordinator configure is rejected. A bad new definition does not erase the active instance. |
| Mode isolation | `session_coordinator.gd:28-48,126-127` | Free and chapter use different instances. Nesting is rejected. Leaving chapter discards only chapter state and reuses free by identity. No mode aliasing via returned dictionaries was seen. |
| Save slot separation | `session_coordinator.gd:75-86`; `save_store.gd:41-42` | Coordinator controls the slot; only `free` and `chapter` are accepted. Caller-supplied paths are not part of the public store API. |
| Semantic load staging | `session_coordinator.gd:89-123`; `quest_runtime.gd:110-176` | Envelope success is followed by exact session fields/mode/schema checks and restore into a new runtime. Live instance is replaced only after all restore checks succeed. |
| Numeric JSON behavior | `session_coordinator.gd:101-103`; `quest_runtime.gd:347-353`; `save_store.gd:252-257` | Integral JSON floats are accepted where the schema expects integers. Booleans are excluded by type checks. Quest version bounds and store generation bounds are explicit. Actual Godot round-trip remains NOT_RUN. |
| Content compatibility | `quest_runtime.gd:35-38,99-102,121-128` | Definition version is normalized before hashing, complete definition fingerprint is stored and checked. Same ID/version with changed content is not silently accepted. |
| Choice atomicity | `quest_runtime.gd:68-89` | Membership/gates/history limit precede mutation; no external callback occurs between grants, history and node assignments. This does not establish a later inventory/reward transaction. |
| Recovery path validity | `quest_runtime.gd:147-175` | Unstarted saves cannot contain path progress. Started history is replayed through actual current-node actions, terminal transitions are prohibited, and final node plus granted facts must agree. Exact observation chronology remains unknown by contract. |
| Non-overwrite persistence | `save_store.gd:293-353` | Generation comes after the highest known committed filename; old records are retained. A unique temp is written/read back and promoted, with destination recheck. Promotion is not a cross-process compare-and-swap; single-writer requirement remains essential. |
| Corruption versus absence | `save_store.gd:260-270,296-300` | Read tries committed generations in descending order, with explicit skipped-record diagnostics; all-invalid records fail, and the write path does not silently replace them with a fresh game. |
| Input bounds | `quest_runtime.gd:201-257`; `save_store.gd:58-104,154-197,213-248` | Schema counts, string IDs, file bytes, recursive JSON depth/value budgets and directory entries are bounded. No arbitrary object deserialization is used. |
| Synthetic sample | `content/synthetic_delivery.json` | Contains explicit collection, two prerequisite alternatives, helper route, wait/retry and terminal hand-over. Definition remains generic and contains no unpublished narrative. |

Source line ranges refer to the files as reviewed in this batch. Later amendments require a targeted re-read. This document is not a claim that future edits automatically inherit the review.

## Paper traces (not executed)

1. **Direct route:** report `PATH_A_SEEN` before start → start at PREPARE → COLLECT grants parcel → TAKE_ROUTE satisfies parcel AND one path fact → HAND_OVER grants delivered → COMPLETE rejects further choices. This trace uses the specification and source branch conditions, not a runtime result.
2. **No available route:** start → COLLECT → TAKE_ROUTE rejected without route observations → WAIT enters REST → externally observe route → RETRY returns PLAN → route then hand-over. Missing prerequisites are not silently supplied by the runtime.
3. **Chapter separation:** progress free instance → enter chapter → chapter starts with fresh facts/history → save chapter to chapter slot → leave chapter → free instance remains its earlier in-memory object. This is session isolation, not a full-world persistence protocol.
4. **Mismatched restore:** storage returns an intact JSON payload with the wrong mode, graph fingerprint or path → coordinator/runtime return an error → old live instance remains. The store's physical fallback to an older record is separate from this semantic validation.

## Limits to carry into the next milestone

- **History capacity:** a valid nonterminal save with 256 choices cannot advance. The sample WAIT/RETRY loop can exhaust the cap. The implementation exposes the limit and fails rather than truncating history, which is appropriate for a bounded foundation. Before using it in a long-lived game, choose bounded content, a restart policy, or an explicit versioned history-compaction scheme; do not promise endless retries today.
- **Partial session saves:** entering chapter does not automatically save free state; a chapter slot does not include the suspended free instance. Leaving chapter discards unsaved chapter progress. The future application owner needs explicit save/leave UX and a complete-world persistence policy.
- **Semantic corruption:** `read_latest` recovers physical/envelope corruption, not incompatible quest definitions. If the newest intact record fails quest validation, `load_active` rejects it; it does not search every older record for one matching current content. Future recovery UI may expose explicit prior-generation selection without silent rollback.
- **Trust boundary:** all declared facts may be observed by the application; grant-only versus externally observable facts are not distinguished. Hashes detect compatibility or accidental corruption, not malicious edits or fraudulent observations. The future world adapter must emit facts only from validated interaction outcomes.
- **Bounded append-only storage:** no automatic retention/deletion is provided. The 1024-entry directory cap includes pending files and both slots, so capacity or repeated failed writes can eventually block new saves. Existing committed saves remain intact. A later explicit retention/recovery design is required for continuous play.
- **Platform behavior:** Windows rename, access denial, antivirus interference, junctions, power interruption, paths and export filters remain unverified. No claim is made about 5060 frame rate or graphics quality.

No additional local runtime work is requested by this review. The next source milestone is the application/world adapter and one complete quest flow; actual compile, runtime and Windows export evidence must be recorded separately when performed under the appropriate authorization.

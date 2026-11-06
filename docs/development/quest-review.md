# Quest runtime: implementation and static review

Date: 2026-11-03. Scope: `game/runtime/quest_runtime.gd` only. Status: **source implemented; runtime acceptance NOT_RUN**. No Godot/editor/import, project script, automated test, demo, build or deployment was executed.

## Implemented behavior

- Configuration is a bounded, exact-field quest definition with explicit start, terminal nodes and globally unique action IDs. IDs are ASCII identifiers; all node, fact and action references must exist.
- Configuration validates structural reachability from the start and reverse reachability to a terminal. Cycles are allowed only when they have an exit. This is a graph check, not evidence of enjoyable gameplay or of a game's external observation sources.
- Observations can arrive before start. Recording a fact is idempotent and does not start or advance a quest. Start is explicit and repeated start is rejected.
- A choice must belong to the current node and satisfy `requires_all AND (requires_any is empty OR at least one requires_any fact exists)`. Rejected choices leave node, facts and history untouched.
- Action grant facts, action history and target node change together without signals or external calls. Terminal nodes cannot advance.
- `view()` returns newly constructed presentation data: node text key, allowed action IDs and option text keys. It returns no mutable internal collections.
- `snapshot()` returns a detached JSON-safe record; before configuration it returns `{}`. Numeric schema/version accepts bounded whole JSON floats on restore, while booleans, fractions, nonfinite values and unknown versions are rejected.
- Fingerprints bind saves to the complete normalized definition: version is normalized to an integer, keys are sorted during JSON serialization, and the resulting UTF-8 string is hashed with SHA-256. Content changes under the same ID/version cannot silently reuse a save. Array ordering is retained and is part of the fingerprint.
- Restore is staged. It validates exact fields, identity/version/fingerprint, known unique facts, bounded action history, each path step, every action's requirements and grant facts, and the exact final node. A fabricated final node, an action from another node, a missing grant, or any history after a terminal is rejected before the commit point.

## Static review findings and decisions

| Concern | Source location | Decision / remaining boundary |
| --- | --- | --- |
| Invalid reconfiguration could erase progress | `configure`, `_validate_definition`, `_validate_graph` | Validation precedes every state assignment; only successful configuration intentionally resets the quest. The outer coordinator rejects repeated configure. |
| OR requirements could accidentally require every alternative | `_gates_pass` | AND group evaluated first; empty OR is unrestricted; nonempty OR succeeds on the first present fact. |
| Repeated observation might trigger duplicate rewards | `observe`, `choose` | Observation is idempotent; the runtime contains no reward, wallet, inventory or external side-effect hook. Such systems need a separate future transaction contract. |
| Save lists a legal-looking node without reaching it | `restore` | Replay starts at the configured start node and must end exactly at stored node. Empty history can only restore the start. |
| Save omits an earlier action's grant | `restore` history loop | Every traversed action's grants must be in the final monotonic fact set. |
| Definition changed without version bump | `configure`, `snapshot`, `restore` | Definition fingerprint now required. Saves from earlier drafts without it fail closed; no silent migration. |
| Caller changes returned snapshot/view | `snapshot`, `view` | Fact IDs, history and option dictionaries are detached; configuration is deep-copied. |
| A cycle exhausts memory | `choose`, `view`, `restore` | History capped at 256. At the cap, no further action is advertised or accepted; observation remains allowed. Content must be budgeted to complete within this cap; rollover/compaction is intentionally absent. |
| Scope accidentally changes other modes | entire module | No global singleton/class registration, static mutable state, scene/file access, clock or inventory. Each coordinator session owns a separate instance. |

## Limits that must remain visible

1. This is one quest graph per runtime instance, not a multi-quest journal, a full dialogue renderer, a scheduler, a scene controller or a finished game.
2. All defined facts may be reported by the caller before start. A snapshot has final monotonic facts, not an observation-time audit log. Replay can prove path and final-state consistency, but cannot prove when a fact was observed, whether an external witness was genuine, or whether an editor/user modified a save. The SHA-256 definition fingerprint provides compatibility detection, not authentication. If later gameplay distinguishes externally observable facts from grant-only facts, a versioned contract change is needed.
3. Structural reachability is not a proof that a future scene actually emits the required observations. The content-to-world observation adapter remains a separate deliverable.
4. A valid `configure` is destructive to this instance. Use a staged new instance for loading/replacing sessions, as the coordinator does.
5. A snapshot at a nonterminal node with 256 history entries is valid historical state but cannot advance. No implicit rewind, history deletion or load-time mutation is performed. Production content must avoid relying on unbounded loops.
6. Graph changes, including text keys or array ordering, require an explicit save compatibility/migration decision. Definition hash parity across other implementations/languages has not been established.

## Future runtime acceptance (all NOT_RUN)

| Case | Expected observation |
| --- | --- |
| Observe before start, then call start | Observation retained; no earlier implicit state transition. |
| Repeat observe / repeat start | Observe succeeds idempotently; start returns ALREADY_STARTED; no duplicate history. |
| Empty OR, one-of-two OR, missing AND | Respectively unrestricted OR, eligible action, rejected action. |
| Choice outside current node | Error and byte-equivalent snapshot. |
| Successful choice | Target, grants and one history entry visible together. |
| Terminal choice | Rejected without mutation. |
| Caller mutates original definition or query result | Runtime's later view/snapshot unaffected. |
| JSON snapshot round-trip | Whole numeric floats accepted and normalized; equivalent live state. |
| Schema/version boolean, fraction, NaN, infinity or overflow | Reject before state mutation. |
| Definition same ID/version with edited graph | Fingerprint mismatch; prior live session retained. |
| History wrong action, wrong source node, wrong final node | Reject before commit. |
| Omit grant or requirement fact from snapshot | Reject before commit. |
| Append history after a terminal | Reject before commit. |
| Unstarted snapshot with node/history | Reject; pre-start known observations alone remain allowed. |
| Extra/missing/unknown snapshot fields/facts | Reject before commit. |
| Missing target, duplicate action ID, disconnected node | Definition rejected; earlier session retained. |
| Closed cycle / cycle with terminal exit | First rejected; second structurally accepted. |
| 256 versus 257 history entries | 256 accepted if path valid; next choose blocked; 257 rejected. |
| Free and chapter instances observe different facts | No fact/history sharing; final authority is coordinator-level verification. |

These are unexecuted acceptance specifications. Static source review does not establish parse success, runtime correctness, Windows compatibility, performance or player experience.

# Quest route history v2 — bounded state without a lifetime action limit

Task: GAME-RUNTIME-FOUNDATION-002. Date: 2026-11-03.

Status: implementation and static review only. **All engine, game code, test, build and deployment execution remains NOT_RUN.** The walkthroughs below are paper reasoning over the source, not test results.

## Problem and change

The first foundation stored every successful action in `history` and stopped offering/accepting actions after 256 entries. A player repeating an intentional WAIT/RETRY loop could exhaust that budget and become unable to leave a nonterminal node.

`history` now stores a **loop-erased route from the configured start to the current node**. It is not an action counter or a complete behavior log. Monotonic facts remain the separate authoritative final fact set, including facts granted by actions removed from the route.

On every successful choice, the runtime:

1. Checks current-node action identity and its AND/OR requirements.
2. Prepares a copy of final facts with this action's grants.
3. Appends this action to a temporary copy of the current route.
4. Replays the temporary path from start. When an action reaches a node already on that route, truncates the route back to that earlier node, discarding the closed loop. Otherwise, appends its edge and node.
5. Commits final facts, the shortened route and the chosen target together.

Each route node is unique after each processed edge. With at most 64 configured nodes, stored history has at most 63 edges. There is no lifetime choice limit. A route of 63 edges can still accept a legal return edge, because that edge is compacted rather than blocked before processing.

The helper `_loop_erased_route` only accepts already validated paths. `choose` constructs one from the existing valid route plus a validated current action. `restore` validates the entire original path first; no malformed or illegal step can be hidden by compaction.

## Save compatibility

The snapshot remains schema 1 with the same fields and definition fingerprint. This is a normalized representation of already-supported monotonic state, not a migration of the quest graph. No old save file is edited by quest restore.

- Old full histories of **0–256 entries** remain accepted only after exact-field, identity, fingerprint, type, known-fact, path, gate, grant and final-node validation succeeds.
- The entire old history is validated before normalization. History after a terminal, an invalid action inside an otherwise erasable loop, and a loop's missing grant all still reject the save without mutation.
- Histories above 256 remain rejected as an input-size boundary (`RESTORE_HISTORY_LIMIT`). The constant is now `MAX_RESTORE_HISTORY`; it is not a limit on future player actions.
- On success `restore` returns `history_normalized`, `history_input_steps`, and `history_steps`, allowing the caller to record whether a legacy route changed representation. A subsequent explicit save persists the canonical snapshot; restore alone performs no file write.
- `choose` returns `history_compacted` and `history_steps`. `view` declares `history_kind = loop_erased_route`, reports current steps and capacity, and retains `history_limit_reached = false` for compatibility with the first draft's callers. That legacy flag no longer gates option visibility.
- A canonical route remains a valid path for the previous reader, but consumers must stop interpreting the array as a complete action chronology. Full telemetry, reward ledgers and security audit trails must use a separate future record; they cannot reconstruct elapsed actions from `history.size()`.
- The earlier `quest-review.md` remains a historical first-batch review. Its statements about the 256-action runtime cap are superseded by this document and the current source. The 256-entry restore-input check remains intentional.

## Paper walkthrough: repeated WAIT and later exit

Synthetic graph: START --BEGIN--> WORK; WORK --WAIT--> WORK; WORK --FINISH--> DONE (terminal). Facts and gates are otherwise unchanged.

| Action / state | Canonical route after action | Current node |
| --- | --- | --- |
| Start | `[]` | START |
| BEGIN | `[BEGIN]` | WORK |
| First WAIT | `[BEGIN]`: appended WAIT reaches existing WORK and is removed | WORK |
| WAIT repeated 300 times | Still `[BEGIN]`; each call validates its action and compacts its single self-loop | WORK |
| FINISH | `[BEGIN, FINISH]` | DONE |

The reasoning does not rely on increasing a memory bound. The repeated loop does not accumulate route entries, and the action menu is no longer disabled by an elapsed-action count. Terminal behavior is unchanged.

## Paper walkthrough: an erased loop grants a needed fact

Synthetic graph: START --VISIT--> BRANCH; BRANCH --LEARN--> SOURCE (grants TOKEN); SOURCE --RETURN--> BRANCH; BRANCH --FINISH--> DONE (requires TOKEN).

| After action | Route | Facts | Node |
| --- | --- | --- | --- |
| VISIT | `[VISIT]` | none | BRANCH |
| LEARN | `[VISIT, LEARN]` | TOKEN | SOURCE |
| RETURN | `[VISIT]` | TOKEN retained | BRANCH |
| FINISH | `[VISIT, FINISH]` | TOKEN retained | DONE |

Removing LEARN from the route does not remove TOKEN. A saved route to DONE remains compatible with the contract that known facts may be externally observed before start; restore validates FINISH's TOKEN requirement using final facts. The compacted route does not prove the source or time of TOKEN. This is the same observation provenance limit already documented for the first batch, now made explicit for removed loops.

## Paper walkthrough: legacy validation before normalization

A legacy history `[VISIT, LEARN, RETURN]` ending at BRANCH with TOKEN first passes every original step, including LEARN's grant check. It is then normalized to `[VISIT]`, with `history_normalized = true`, `history_input_steps = 3`, and `history_steps = 1`.

The same legacy history without TOKEN fails with `HISTORY_GRANT_MISSING` before compaction. `[VISIT, UNKNOWN, RETURN]` fails path/action validation. A path continuing after a terminal fails before compaction. Their live snapshots remain unchanged. Thus a loop is never discarded to conceal an invalid stored transition.

## Static invariants and pending runtime checks

- The route helper processes each edge in order and updates its current node to the actual target, even when truncating the visible route. Future edges are therefore resolved at the correct original path node.
- Truncation at prior node index `k` keeps exactly `k` actions and `k + 1` route nodes. Returning to start leaves an empty path; a self-loop leaves the prior path unchanged.
- A second loop through nodes already removed from the visible route can append them again normally; membership is checked against the current loop-erased node list, not all historically visited nodes.
- Final node and final monotonic facts are preserved. The route no longer attests that every fact was earned on its retained edges, and must never be used to replay external rewards.
- Confirm later in an authorized runtime: 300 WAITs then FINISH; multi-node cycles with grants; a 63-edge path then a backward edge; valid 256-step legacy normalization; invalid/missing-grant loop rejection; 257-step input rejection; snapshot/load roundtrip; free/chapter isolation; and detached-return behavior.

No runtime success, Windows compatibility or performance result is claimed by this change.

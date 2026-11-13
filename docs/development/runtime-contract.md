# Runtime foundation v2 (candidate; snapshot schema remains 1)

Scope: a reusable Godot 4 quest/session/save foundation for a later Windows x86_64 game. No engine launch, import, tests, build, CI or deployment is authorized in this batch. All runtime acceptance is NOT_RUN. Public fixtures are synthetic; unpublished game content is supplied separately later.

## Quest runtime: `game/runtime/quest_runtime.gd`

`extends RefCounted`, no global class registration. Methods return `{ok: bool, code: String, ...}`; no exceptions or mutation on rejection.

- `configure(definition: Dictionary) -> Dictionary`: validate and deep-copy definition; reset only on success.
- `observe(fact: String) -> Dictionary`: record a defined fact, including before start, idempotently. No transition implicit.
- `start() -> Dictionary`: explicit start, once; empty state beforehand.
- `choose(action_id: String) -> Dictionary`: apply only current-node action whose `requires_all` AND (`requires_any` empty OR at least one true) hold. Apply `grants` facts and target node together. Terminal nodes cannot transition.
- `snapshot() -> Dictionary`: deep copy `{schema:1, definition_id:String, definition_version:int, definition_sha256:String, started:bool, node:String, facts:Array[String], history:Array[String]}`. History is a loop-erased route of action IDs, replayed from definition start, not a complete chronology. Limits: 128 facts, 64 nodes, 16 actions per node and at most 63 canonical route edges. No lifetime action cap, reward or wallet side effects. Facts earned in removed loops remain in the final monotonic fact set.
- `restore(snapshot: Dictionary) -> Dictionary`: validate schema, types, bounds, identity and canonical definition SHA-256 fingerprint, known facts and history path to node; staged commit. Fully validate legacy input histories up to 256 edges BEFORE compaction; return normalization diagnostics. Must not invoke external side effects. Final facts and route cannot prove historical observation time or grant provenance. See `quest-history-v2.md` for the representation and compatibility limits.
- `view() -> Dictionary`: returns started/node/terminal and currently available action IDs, plus text keys for the current node/options. No mutable internal references.

Definition exact keys: `{id:String, version:int, start:String, facts:Array[String], nodes:Dictionary}`. Each node exact keys `{text_key:String, terminal:bool, actions:Array}`. Action exact keys `{id:String, text_key:String, target:String, requires_all:Array[String], requires_any:Array[String], grants:Array[String]}`. IDs are bounded ASCII identifiers `[A-Z][A-Z0-9_]{0,63}`; text keys are bounded strings. Require unique global action IDs, valid references, terminal nodes with zero actions, nonterminal nodes with actions; all nodes structurally reachable from start and able to reach a terminal (cycles with exits are allowed). Runtime facts/grants are per quest session, never global.

## Save store: `game/runtime/save_store.gd`

`extends RefCounted`; immutable JSON records, never overwrite existing saves. Constructor no side effects. `write_record(slot: String, payload: Dictionary) -> Dictionary`, `read_latest(slot: String) -> Dictionary`, explicit `archive_older(slot: String, keep: int = 32) -> Dictionary`, and `read_archived(slot: String, generation: Variant) -> Dictionary`.

Fixed root `user://game_runtime_v1/`; slot is exactly `free` or `chapter`. Payload is the session coordinator snapshot below, passed opaquely. JSON roundtrip must preserve its JSON-safe content; reject object/resource values, nonfinite numbers and oversized (>1 MiB) payload. Envelope `{format:1, generation:int, payload_sha256:String, payload_json:String}`; hash exact UTF-8 payload_json. Deterministic JSON serialization; generation from existing committed filenames. Single-writer candidate only; refuse reentrant write. Stage under unique temporary name and promote only after closed/readback verified. Immutable `<slot>-<generation>.json`; reads try generations descending, verify filename/envelope match, limits/hash, return newest intact record with skipped-corrupt diagnostics. If records exist but none valid, fail explicitly (never silently create a new game). Bound the root to 1024 active/unknown entries plus the one verified non-link `archive` directory, with a total bound of 1025. Temp files count toward capacity but are not committed records. Do not delete old files or promise power-loss durability. Return `{ok,code,payload?,generation?,path?,skipped?}`. No file paths supplied by callers.

Archival validates the active records, retains the newest `keep` valid records (minimum 2) and never moves a corrupt or highest-generation file. Older valid records move to `archive/<slot>/<generation>.json`, with existence checks and content readback. Existing targets are preserved. At most 4096 entries per archive slot; fail rather than silently drop history. This is non-atomic single-writer maintenance, with `partial`, `moved`, `remaining`, `retained`, `diagnostics` and `remaining_unknown`. Direct archived reads validate a fixed slot/generation path without scanning all history. See `save-retention-v2.md`.

## Session coordinator (root agent implementation)

The original `configure(definition)` opens a delivery-only session. `configure_with_side(definition, side_definition)` also creates an independent side quest. Each mode owns its own pair, and entering a chapter starts a fresh pair. The application has revision-checked commands for starting and choosing within each quest.

A delivery-only session saves `{schema:1, mode, quest}`. A session with a side quest saves `{schema:2, mode, quest, side_quest}` in one generation. Restoring schema 1 into a paired session restores the delivery and initializes the side quest in its unstarted state. Latest and archived loads validate the mode and all supplied snapshots before replacing live state. A delivery-only session rejects schema 2. Quest snapshots themselves still use schema 1.

`archive_active(keep)` delegates only the active slot; `load_archived(generation)` uses the same staged semantic restore as `load_active`. Successful restore surfaces history normalization diagnostics. The application wrapper in `game/runtime/quest_application.gd` adds command revisions, observation/presentation validation and save-before-switch behavior. Its contract and caller obligations are in `application-integration-v2.md`.

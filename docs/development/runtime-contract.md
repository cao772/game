# Runtime foundation v1 (candidate)

Scope: a reusable Godot 4 quest/session/save foundation for a later Windows x86_64 game. No engine launch, import, tests, build, CI or deployment is authorized in this batch. All runtime acceptance is NOT_RUN. Public fixtures are synthetic; unpublished game content is supplied separately later.

## Quest runtime: `game/runtime/quest_runtime.gd`

`extends RefCounted`, no global class registration. Methods return `{ok: bool, code: String, ...}`; no exceptions or mutation on rejection.

- `configure(definition: Dictionary) -> Dictionary`: validate and deep-copy definition; reset only on success.
- `observe(fact: String) -> Dictionary`: record a defined fact, including before start, idempotently. No transition implicit.
- `start() -> Dictionary`: explicit start, once; empty state beforehand.
- `choose(action_id: String) -> Dictionary`: apply only current-node action whose `requires_all` AND (`requires_any` empty OR at least one true) hold. Apply `grants` facts and target node together. Terminal nodes cannot transition.
- `snapshot() -> Dictionary`: deep copy `{schema:1, definition_id:String, definition_version:int, definition_sha256:String, started:bool, node:String, facts:Array[String], history:Array[String]}`. History is action IDs; replay starts from definition start. Limits: 128 facts, 256 history entries, 64 nodes, 16 actions per node. Every successful action consumes one history entry; no reward or wallet side effects.
- `restore(snapshot: Dictionary) -> Dictionary`: validate schema, types, bounds, identity and canonical definition SHA-256 fingerprint, known facts and history path to node; staged commit. Must not invoke external side effects. Observed/granted facts can be present before start; cannot prove historical observation time from snapshot, document this.
- `view() -> Dictionary`: returns started/node/terminal and currently available action IDs, plus text keys for the current node/options. No mutable internal references.

Definition exact keys: `{id:String, version:int, start:String, facts:Array[String], nodes:Dictionary}`. Each node exact keys `{text_key:String, terminal:bool, actions:Array}`. Action exact keys `{id:String, text_key:String, target:String, requires_all:Array[String], requires_any:Array[String], grants:Array[String]}`. IDs are bounded ASCII identifiers `[A-Z][A-Z0-9_]{0,63}`; text keys are bounded strings. Require unique global action IDs, valid references, terminal nodes with zero actions, nonterminal nodes with actions; all nodes structurally reachable from start and able to reach a terminal (cycles with exits are allowed). Runtime facts/grants are per quest session, never global.

## Save store: `game/runtime/save_store.gd`

`extends RefCounted`; append-only immutable JSON records, never overwrite existing saves. Constructor no side effects. `write_record(slot: String, payload: Dictionary) -> Dictionary`, `read_latest(slot: String) -> Dictionary`.

Fixed root `user://game_runtime_v1/`; slot is exactly `free` or `chapter`. Payload is the session coordinator snapshot below, passed opaquely. JSON roundtrip must preserve its JSON-safe content; reject object/resource values, nonfinite numbers and oversized (>1 MiB) payload. Envelope `{format:1, generation:int, payload_sha256:String, payload_json:String}`; hash exact UTF-8 payload_json. Deterministic JSON serialization; generation from existing committed filenames. Single-writer candidate only; refuse reentrant write. Stage under unique temporary name and promote only after closed/readback verified. Immutable `<slot>-<generation>.json`; reads try generations descending, verify filename/envelope match, limits/hash, return newest intact record with skipped-corrupt diagnostics. If records exist but none valid, fail explicitly (never silently create a new game). Bound directory scan to 1024 entries; fail rather than ignore overflow. Ignore uncommitted temp records. Do not delete old files or promise power-loss durability. Return `{ok,code,payload?,generation?,path?,skipped?}`. No file paths supplied by callers.

## Session coordinator (root agent implementation)

`configure(definition)` creates one free session; `enter_chapter()` creates independent fresh chapter, rejects nesting; `leave_chapter()` discards chapter only. `observe/start/choose/view` delegate to active runtime. Save payload exact keys `{schema:1, mode:"free"|"chapter", quest:Dictionary}`; `save_active()` uses corresponding fixed slot. `load_active()` rejects mismatched mode/schema/quest and leaves state untouched on failure. Free state is retained untouched while chapter runs. No clock, inventory, reward or cross-mode transfer in this milestone: those belong to later explicit implementations, not implied completed features.

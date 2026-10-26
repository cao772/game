# Scheduler reliability candidate

The local planner separates registered conversations, fresh browser observations, technical acceptance and archive state. It reserves sends under a local OS file lock, without opening browsers or sending messages. A pending reservation must be reconciled against the actual page before any retry.

Run `python -m unittest discover -s ops -p test_control.py -v`. Run `ops/probe.ps1` on Windows to sample the project disk, CPU, free RAM and optional GPU; missing required metrics fail closed. Use `python ops/control.py --write` with a private task ledger and fresh observations to generate status. `--reserve TASK_ID` marks dispatch_pending, never sent.

Each queued task requires id, version, input_sha256, inputs_ready, durable url, explicit relative write_paths and dependencies. Technical dependency acceptance is separate from archive completion. UI observations and resource samples expire. User drafts and owner decision gates are protected. Review backlog defaults to three. Time gate is Saturday/Sunday in UTC+8.

Validated locally on Windows: 18 tests covering time boundaries, unknown/stale measurements, draft preservation, duplicate/pending sends, dependency gates, conflicting writers, capacity planning, OS lock release and durable reservation. Live resource probe succeeded. Browser interaction is not implemented by this tool; current UI control availability must be checked separately. A lock on one machine cannot coordinate another machine; designate one dispatch host.

Private ledgers, drafts, chat snapshots and evidence are excluded from this public candidate. No game canon or shared interface is approved by this change. This branch must remain a Draft PR until reviewed.

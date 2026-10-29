/* GAME-WEB-PLAY-PERF-005/r1: future acceptance for multi-result comparison.
 * NOT_RUN by author instruction. Use only synthetic in-memory objects.
 * Do not mistake test definitions for executed validation.
 */
"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const model = require("../tools/perf_evidence_browser/model.js");
const cohort = require("../tools/perf_evidence_browser/cohort.js");

function sample(id, observed = 12, provenance = "SYNTHETIC", overrides = {}) {
  const metrics = model.METRICS.map(([key, name, unit, bound]) => ({
    key, label: name, unit, budget: bound, budget_status: "PROPOSAL",
    observed: key === "frame_p50_ms" ? observed : bound,
    status: key === "frame_p50_ms" && observed > bound ? "FAIL" : "PASS",
    note: "synthetic source"
  }));
  const capture = provenance === "SYNTHETIC" ? { origin: "SYNTHETIC" } :
    provenance === "DECLARED_REAL_UNVERIFIED" ?
      { origin: "DECLARED_REAL_UNLINKED" } :
      provenance === "NOT_GPU_BENCHMARK" ?
        { origin: "NOT_GPU_BENCHMARK", renderer: "dummy" } : {};
  const source = {
    task_id: "GAME-WEB-MODULE-PERF-002", version: "r1",
    sample_count: 100, measured_subset_status: "PASS",
    whole_scene_status: "INCOMPLETE", full_scene_pass: false,
    budget_approval: "UNAPPROVED_PROPOSAL",
    metrics, warnings: [], capture
  };
  if (overrides.capture) Object.assign(source.capture, overrides.capture);
  if (overrides.missing) {
    const row = metrics.find(m => m.key === overrides.missing);
    row.observed = null;
    row.status = "INCOMPLETE";
    row.note = "source did not measure this metric";
    source.measured_subset_status = "INCOMPLETE";
  }
  if (overrides.badBudget) {
    const row = metrics.find(m => m.key === overrides.badBudget);
    row.budget = 999;
  }
  const record = model.normalize("synthetic-" + id + ".json", JSON.stringify(source));
  record.browserId = id;
  return record;
}

function metric(result, key) { return result.rows.find(x => x.key === key); }

test("PB01 three reports: per-report median is not pooled frame percentile", () => {
  const result = cohort.compareMany([sample(1, 9), sample(2, 12), sample(3, 10)], 1);
  const p50 = metric(result, "frame_p50_ms");
  assert.equal(p50.median, 10);
  assert.equal(p50.min, 9);
  assert.equal(p50.max, 12);
  assert.equal(p50.nReportedUsable, 3);
  assert.equal(p50.coverage, "COMPLETE_NUMERIC");
  assert.equal(result.method.includes("no pooled frames"), true);
  assert.equal(result.fullScenePass, false);
  assert.equal(result.budgetApproved, false);
  assert.equal(result.testStatus, "NOT_RUN");
});

test("PB02 baseline can be any selected report and its delta is zero", () => {
  const result = cohort.compareMany([sample(1, 9), sample(2, 12), sample(3, 10)], 3);
  const p50 = metric(result, "frame_p50_ms");
  assert.equal(result.baselineId, 3);
  assert.equal(p50.cells[0].delta, -1);
  assert.equal(p50.cells[1].delta, 2);
  assert.equal(p50.cells[2].delta, 0);
  assert.equal(p50.cells[0].comparison, "NUMERIC_ONLY");
  assert.equal(result.context.status, "UNVERIFIED");
});

test("PB03 one missing value gives explicit coverage and null group summary", () => {
  const result = cohort.compareMany([
    sample(1), sample(2, 9, "SYNTHETIC", { missing: "script_p95_ms" }), sample(3)
  ], 1);
  const row = metric(result, "script_p95_ms");
  assert.equal(row.coverage, "PARTIAL");
  assert.equal(row.nReportedUsable, 2);
  assert.equal(row.median, null);
  assert.equal(row.missing.length, 1);
  assert.equal(row.missing[0].id, 2);
  assert.match(row.missing[0].reason, /did not measure/);
  assert.equal(result.missingOverview.untrustedOrMissing, 1);
});

test("PB04 all null does not mean zero or budget within", () => {
  const result = cohort.compareMany([
    sample(1, 9, "SYNTHETIC", { missing: "script_p95_ms" }),
    sample(2, 11, "SYNTHETIC", { missing: "script_p95_ms" })
  ], 1);
  const row = metric(result, "script_p95_ms");
  assert.equal(row.coverage, "NOT_MEASURED");
  assert.equal(row.min, null);
  assert.equal(row.median, null);
  assert.equal(row.cells[1].delta, null);
});

test("PB05 conflicting provenance prohibits numeric delta and grouped median", () => {
  const r = cohort.compareMany([
    sample(1, 9, "SYNTHETIC"), sample(2, 11, "DECLARED_REAL_UNVERIFIED")
  ], 1);
  assert.equal(r.context.status, "CONFLICT");
  assert.equal(metric(r, "frame_p50_ms").median, null);
  assert.equal(metric(r, "frame_p50_ms").cells[1].comparison, "NOT_COMPARABLE");
});

test("PB06 synthetic-only output stays classified as synthetic, never real", () => {
  const r = cohort.compareMany([sample(1, 9), sample(2, 11)], 1);
  assert.equal(r.context.allSynthetic, true);
  assert.equal(r.benchmarkVerified, false);
  assert.match(r.context.evidenceNote, /合成/);
});

test("PB07 non-GPU mode blocks cross-report deltas", () => {
  const r = cohort.compareMany([
    sample(1, 9, "NOT_GPU_BENCHMARK"),
    sample(2, 11, "NOT_GPU_BENCHMARK")
  ], 1);
  assert.equal(r.context.status, "CONFLICT");
  assert.equal(metric(r, "frame_p50_ms").cells[1].delta, null);
});

test("PB08 engine and scene hashes are not independently authenticated", () => {
  const r = cohort.compareMany([
    sample(1, 9, "SYNTHETIC", { capture: {
      engine_version: "4.7.2", scene_sha256: "a".repeat(64)
    } }),
    sample(2, 10, "SYNTHETIC", { capture: {
      engine_version: "4.7.2", scene_sha256: "b".repeat(64)
    } })
  ], 1);
  assert.equal(r.context.status, "CONFLICT");
  assert.match(r.context.reasons.join(" "), /场景哈希/);
});

test("PB09 reported numeric value with invalid budget must not be comparable", () => {
  const r = cohort.compareMany([
    sample(1), sample(2, 10, "SYNTHETIC", { badBudget: "frame_p50_ms" })
  ], 1);
  const row = metric(r, "frame_p50_ms");
  assert.equal(row.cells[1].canUse, false);
  assert.equal(row.nReportedUsable, 1);
  assert.equal(row.cells[1].delta, null);
});

test("PB10 zero baseline retains difference but percent is null", () => {
  const r = cohort.compareMany([sample(1, 0), sample(2, 3)], 1);
  const row = metric(r, "frame_p50_ms");
  assert.equal(row.cells[1].delta, 3);
  assert.equal(row.cells[1].deltaPercent, null);
});

test("PB11 rejects source-aggregated series as individual sample", () => {
  const a = sample(1), b = sample(2);
  b.kind = "series";
  assert.throws(() => cohort.compareMany([a, b], 1), /单次摘要/);
});

test("PB12 rejects fewer than two or more than twelve independent inputs", () => {
  assert.throws(() => cohort.compareMany([sample(1)], 1), /2至12/);
  const many = Array.from({length: 13}, (_, i) => sample(i + 1));
  assert.throws(() => cohort.compareMany(many, 1), /2至12/);
});

test("PB13 rejects duplicate browser IDs and invalid baseline selection", () => {
  assert.throws(() => cohort.compareMany([sample(1), sample(1)], 1), /重复/);
  assert.throws(() => cohort.compareMany([sample(1), sample(2)], 9), /基线/);
});

test("PB14 compare output includes provenance and reported origin metadata", () => {
  const a = sample(1, 10, "DECLARED_REAL_UNVERIFIED", {capture: {
    engine_version: "4.7.2", renderer: "opengl3", scene_sha256: "a".repeat(64)
  }});
  const b = sample(2, 11, "DECLARED_REAL_UNVERIFIED", {capture: {
    engine_version: "4.7.2", renderer: "opengl3", scene_sha256: "a".repeat(64)
  }});
  const r = cohort.compareMany([a, b], 1);
  assert.equal(r.context.status, "UNVERIFIED");
  assert.equal(r.records[0].renderer, "opengl3");
  assert.equal(r.records[0].sceneHash, "a".repeat(64));
  assert.equal(r.benchmarkVerified, false);
});

test("PB15 model enforces duplicated summary metrics and missing values", () => {
  const a = sample(1), b = sample(2);
  b.metrics[0].diagnostic = "INCOMPLETE";
  b.metrics[0].usable = false;
  b.metrics[0].reason = "duplicate keys";
  const r = cohort.compareMany([a, b], 1);
  assert.equal(metric(r, "frame_p50_ms").nReportedUsable, 1);
  assert.equal(metric(r, "frame_p50_ms").cells[1].delta, null);
});

test("PB16 rendered browser has opt-in multi-select and only local scripts", () => {
  const root = path.join(__dirname, "..", "tools", "perf_evidence_browser");
  const html = fs.readFileSync(path.join(root, "index.html"), "utf8");
  const js = fs.readFileSync(path.join(root, "app.js"), "utf8");
  assert.match(html, /cohort\.js/);
  assert.match(html, /id="multi-compare"/);
  assert.match(html, /connect-src 'none'/);
  assert.ok(!js.includes("innerHTML"));
  assert.ok(!js.includes("localStorage"));
  assert.ok(!js.includes("fetch("));
});

test("PB17 numeric statistics do not alter input report objects", () => {
  const a = sample(1, 9), b = sample(2, 12);
  const before = JSON.stringify([a, b]);
  cohort.compareMany([a, b], 1);
  assert.equal(JSON.stringify([a, b]), before);
});

test("PB18: importer serializes async local file batches and avoids accidental repeat-selection", () => {
  const app = fs.readFileSync(
    path.join(__dirname, "..", "tools", "perf_evidence_browser", "app.js"), "utf8"
  );
  assert.match(app, /state\.busy/);
  assert.match(app, /seenFiles/);
  assert.match(app, /signature/);
  assert.match(app, /finally/);
});

test("PB19: UI explains missing metrics and retains per-run provenance warnings", () => {
  const app = fs.readFileSync(
    path.join(__dirname, "..", "tools", "perf_evidence_browser", "app.js"), "utf8"
  );
  assert.match(app, /addMissingExplanation/);
  assert.match(app, /r\.sceneHash/);
  assert.match(app, /r\.renderer/);
  assert.match(app, /缺测与口径说明/);
  assert.match(app, /另有 /);
});

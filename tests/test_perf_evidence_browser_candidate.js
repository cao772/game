/* GAME-WEB-FLOW-PERF-004/r1 — future-only acceptance cases.
 * NOT_RUN. Do not execute during authoring. Node built-in assert/test only.
 * All evidence objects below are SYNTHETIC SHAPES, not game benchmarks.
 */
"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const m = require("../tools/perf_evidence_browser/model.js");

function fakeAnalyzer(options = {}) {
  const checks = {}, stats = {
    frame_ms: { p50: 12, p95: 16.7, p99: 24 },
    script_ms: { p95: 2 }, ram_gib: { peak: 1.2 },
    vram_delta_gib: { peak: 1 }, draw_calls: { peak: 200 },
    triangles: { peak: 150000 }
  };
  for (const [key, , , bound] of m.METRICS) {
    checks[key] = { value: bound, upper_inclusive: bound, status: "PASS" };
  }
  return Object.assign({
    task_id: "GAME-WEB-PERF-002", version: "r1",
    sample_count: 100, error_count: 0, errors: [],
    percentile_definition: "nearest-rank: ascending, rank=ceil(p*n), p in {0.50,0.95,0.99}; no interpolation",
    status: "incomplete", full_scene_pass: false,
    measured_subset_status: "PASS", stats, checks
  }, options);
}
function fakeSummary(options = {}) {
  const metrics = m.METRICS.map(([key, name, unit, bound]) => ({
    key, label: name, unit, budget: bound, budget_status: "PROPOSAL",
    observed: bound, status: "PASS", note: "only budget"
  }));
  return Object.assign({
    task_id: "GAME-WEB-MODULE-PERF-002", version: "r1",
    sample_count: 100, measured_subset_status: "PASS",
    whole_scene_status: "INCOMPLETE", full_scene_pass: false,
    budget_approval: "UNAPPROVED_PROPOSAL",
    metrics, capture: { origin: "SYNTHETIC", engine_version: "4.7.2" },
    warnings: []
  }, options);
}
function fakeSeries(options = {}) {
  const makeMetrics = () => m.METRICS.map(([key, , , limit]) => ({
    key, n_total: 2, n_observed: 2, n_missing: 0,
    min: limit, median: limit, max: limit, budget: limit,
    budget_status: "UNAPPROVED_PROPOSAL", coverage: "COMPLETE_NUMERIC",
    missing_runs: []
  }));
  const group = {
    name: "current", n_runs: 2,
    runs: [
      { id: "A", sample_count: 100, source_origin: "SYNTHETIC",
        analyzer_subset_status: "PASS" },
      { id: "B", sample_count: 100, source_origin: "SYNTHETIC",
        analyzer_subset_status: "PASS" }
    ],
    metrics: makeMetrics()
  };
  return Object.assign({
    task_id: "GAME-WEB-CONTINUE-PERF-003",
    version: "r1",
    schema: "perf-series-report-v1",
    status: "INCOMPLETE",
    budget_approval: "UNAPPROVED_PROPOSAL",
    whole_scene_status: "INCOMPLETE",
    full_scene_pass: false, groups: [group],
    missing_run_details: [], group_comparison: null
  }, options);
}
function importSynthetic(x) { return m.normalize("synthetic.json", JSON.stringify(x)); }
function getMetric(r, key) { return r.metrics.find(x => x.key === key); }

test("FB01: raw analyzer budget vs observation are separate, not whole-scene PASS", () => {
  const r = importSynthetic(fakeAnalyzer());
  assert.equal(r.kind, "analyzer");
  const p50 = getMetric(r, "frame_p50_ms");
  assert.equal(p50.observed, 12);
  assert.equal(p50.budget, 12);
  assert.equal(p50.diagnostic, "WITHIN_PROPOSAL");
  assert.equal(r.fullScenePass, false);
  assert.equal(r.budgetApproved, false);
  assert.equal(r.provenance, "UNVERIFIED");
});

test("FB02: incomplete analyzer values do not become zeros or approved", () => {
  const src = fakeAnalyzer();
  src.checks.script_p95_ms.value = null;
  src.checks.script_p95_ms.status = "INCOMPLETE";
  src.stats.script_ms.p95 = null;
  src.measured_subset_status = "INCOMPLETE";
  const r = importSynthetic(src);
  const value = getMetric(r, "script_p95_ms");
  assert.equal(value.observed, null);
  assert.equal(value.diagnostic, "NOT_MEASURED");
  assert.equal(r.fullScenePass, false);
});

test("FB03: analyzer error_count invalidates claims", () => {
  const r = importSynthetic(fakeAnalyzer({ error_count: 2, errors: [{ code: "BAD" }] }));
  assert.ok(r.metrics.every(x => !x.usable));
  assert.ok(r.warnings.length > 0);
});

test("FB04: contradictory checks/stats cannot imply within budget", () => {
  const src = fakeAnalyzer();
  src.stats.frame_ms.p99 = 3;
  const r = importSynthetic(src);
  assert.equal(getMetric(r, "frame_p99_ms").diagnostic, "INCOMPLETE");
});

test("FB05: one-run summary declares synthetic not real", () => {
  const r = importSynthetic(fakeSummary());
  assert.equal(r.kind, "single");
  assert.equal(r.provenance, "SYNTHETIC");
  assert.equal(r.gpuBenchmarkVerified, false);
  assert.equal(r.metrics.length, 8);
});

test("FB06: declaration of non-synthetic remains unverified", () => {
  const s = fakeSummary();
  s.capture = { origin: "DECLARED_REAL_UNLINKED", renderer: "opengl3" };
  const r = importSynthetic(s);
  assert.equal(r.provenance, "DECLARED_REAL_UNVERIFIED");
  assert.equal(r.provenanceVerified, false);
});

test("FB07: headless/dummy is not a GPU benchmark", () => {
  const s = fakeSummary();
  s.capture = { origin: "NOT_GPU_BENCHMARK", renderer: "dummy" };
  const r = importSynthetic(s);
  assert.equal(r.provenance, "NOT_GPU_BENCHMARK");
  assert.equal(r.gpuBenchmarkVerified, false);
});

test("FB08: synthetic contradicting explicit non-synthetic is CONFLICT", () => {
  const s = fakeSummary();
  s.capture = { origin: "SYNTHETIC", is_synthetic: false };
  assert.equal(importSynthetic(s).provenance, "CONFLICT");
});

test("FB09: source metric with missing budget cannot become PASS", () => {
  const s = fakeSummary();
  delete s.metrics[0].budget;
  const r = importSynthetic(s);
  assert.equal(getMetric(r, "frame_p50_ms").diagnostic, "INCOMPLETE");
});

test("FB10: null/negative/boolean/string observation never substituted", () => {
  for (const value of [null, -1, false, "12"]) {
    const s = fakeSummary();
    s.metrics[0].observed = value;
    const r = importSynthetic(s);
    assert.equal(getMetric(r, "frame_p50_ms").observed, null);
    assert.equal(getMetric(r, "frame_p50_ms").usable, false);
  }
});

test("FB11: malformed JSON and unsupported shape rejected", () => {
  assert.throws(() => m.normalize("bad.json", "{oops"), /JSON无效/);
  assert.throws(() => m.normalize("bad.json", JSON.stringify({ project: "secret" })), /不支持/);
});

test("FB12: series metrics use run-level median, not pooled percentile", () => {
  const r = importSynthetic(fakeSeries());
  assert.equal(r.kind, "series");
  assert.equal(r.groups[0].metrics[0].median, 12);
  assert.equal(r.groups[0].metrics[0].coverage, "COMPLETE_NUMERIC");
  assert.equal(r.provenance, "SYNTHETIC");
  assert.equal(r.fullScenePass, false);
});

test("FB13: partial series missing metric stays partial and null if entirely missing", () => {
  const s = fakeSeries();
  const x = s.groups[0].metrics[0];
  Object.assign(x, { n_observed: 0, n_missing: 2, min: null, median: null,
    max: null, coverage: "NOT_MEASURED", missing_runs: [
      { run_id: "A", status: "NOT_MEASURED", reason: "no data" },
      { run_id: "B", status: "NOT_MEASURED", reason: "no data" }
    ] });
  const r = importSynthetic(s);
  assert.equal(r.groups[0].metrics[0].median, null);
  assert.equal(r.groups[0].metrics[0].coverage, "NOT_MEASURED");
  assert.equal(r.groups[0].metrics[0].missingRuns.length, 2);
});

test("FB14: invalid series counts and ordering do not receive numeric coverage", () => {
  const s = fakeSeries();
  s.groups[0].metrics[0].n_observed = 4;
  s.groups[0].metrics[0].median = 500;
  const r = importSynthetic(s);
  assert.equal(r.groups[0].metrics[0].coverage, "INCOMPLETE");
  assert.equal(r.groups[0].metrics[0].median, null);
});

test("FB15: source series with mixed provenance is not real benchmark", () => {
  const s = fakeSeries();
  s.groups[0].runs[1].source_origin = "DECLARED_REAL_UNLINKED";
  assert.equal(importSynthetic(s).provenance, "CONFLICT");
});

test("FB16: comparison gives descriptive delta with no verified benchmark claim", () => {
  const a = importSynthetic(fakeSummary());
  const bSrc = fakeSummary();
  bSrc.metrics[0].observed = 10;
  const b = importSynthetic(bSrc);
  const comparison = m.compare(a, b);
  assert.equal(comparison.rows[0].delta, -2);
  assert.equal(comparison.rows[0].status, "NUMERIC_ONLY");
  assert.equal(comparison.context, "UNVERIFIED");
  assert.equal(comparison.benchmarkVerified, false);
});

test("FB17: synthetic-vs-claimed-real comparisons refuse delta", () => {
  const a = importSynthetic(fakeSummary());
  const bSrc = fakeSummary();
  bSrc.capture = { origin: "DECLARED_REAL_UNLINKED" };
  const comparison = m.compare(a, importSynthetic(bSrc));
  assert.equal(comparison.context, "CONFLICT");
  assert.equal(comparison.rows[0].delta, null);
});

test("FB18: missing metric in either comparison refuses delta", () => {
  const a = importSynthetic(fakeSummary());
  const s = fakeSummary();
  s.metrics[0].observed = null;
  s.metrics[0].status = "INCOMPLETE";
  const comparison = m.compare(a, importSynthetic(s));
  assert.equal(comparison.rows[0].delta, null);
  assert.equal(comparison.rows[0].status, "NOT_COMPARABLE");
});

test("FB19: series cannot be compared as one single-run sample", () => {
  const comparison = m.compare(importSynthetic(fakeSeries()), importSynthetic(fakeSummary()));
  assert.equal(comparison.context, "NOT_COMPARABLE");
  assert.equal(comparison.rows.length, 0);
});

test("FB20: HTML declares offline CSP and imports only local files", () => {
  const root = path.join(__dirname, "..", "tools", "perf_evidence_browser");
  const html = fs.readFileSync(path.join(root, "index.html"), "utf8");
  const app = fs.readFileSync(path.join(root, "app.js"), "utf8");
  assert.ok(html.includes("connect-src 'none'"));
  assert.ok(html.includes("type=\"file\""));
  assert.ok(!app.includes("fetch("));
  assert.ok(!app.includes("localStorage"));
  assert.ok(!app.includes("innerHTML"));
  assert.ok(app.includes("textContent"));
});

test("FB21: input size guard applies before JSON parsing", () => {
  assert.throws(() => m.normalize("large.json", "x".repeat(m.MAX_FILE_BYTES + 1)), /上限/);
});

test("FB22: source whole-scene PASS assertion is explicitly distrusted", () => {
  const s = fakeSummary({ full_scene_pass: true });
  const r = importSynthetic(s);
  assert.equal(r.fullScenePass, false);
  assert.ok(r.warnings.some(w => w.includes("PASS")));
});

test("FB23: process RAM and private commit remain isolated metadata", () => {
  const s = fakeSummary();
  s.process_memory = {
    working_set_peak_observed_gib: 0.6, private_bytes_peak_observed_gib: 0.4,
    quality: "DECLARED_PROCESS_SAMPLE"
  };
  s.metrics[4].observed = null;
  s.metrics[4].status = "INCOMPLETE";
  const r = importSynthetic(s);
  assert.equal(r.processMemory.workingSet, 0.6);
  assert.equal(r.processMemory.privateCommit, 0.4);
  assert.equal(getMetric(r, "ram_peak_gib").observed, null);
});

test("FB24: series retains per-run engine, renderer, hash and source warnings", () => {
  const s = fakeSeries();
  s.groups[0].runs[0].capture = {
    engine_version: "4.7.2", renderer: "opengl3", scene_sha256: "a".repeat(64)
  };
  s.groups[0].runs[0].warnings = ["缺少脚本CPU"];
  const r = importSynthetic(s);
  const row = r.groups[0].runDetails[0];
  assert.equal(row.engineVersion, "4.7.2");
  assert.equal(row.renderer, "opengl3");
  assert.equal(row.sceneHash, "a".repeat(64));
  assert.deepEqual(row.warnings, ["缺少脚本CPU"]);
  assert.equal(r.provenanceVerified, false);
});

test("FB25: malformed summary task or budget approval cannot be treated as within budget", () => {
  for (const overrides of [
    { task_id: "other" },
    { version: "r2" },
    { budget_approval: "APPROVED" }
  ]) {
    const result = importSynthetic(fakeSummary(overrides));
    assert.ok(result.metrics.every(x => !x.usable));
    assert.equal(result.fullScenePass, false);
  }
});

test("FB26: duplicate metric keys in single summary prevent numeric trust", () => {
  const src = fakeSummary();
  src.metrics.push({ ...src.metrics[0] });
  const r = importSynthetic(src);
  assert.equal(getMetric(r, "frame_p50_ms").usable, false);
  assert.ok(r.warnings.some(x => x.includes("重复指标")));
});

test("FB27: malformed series contract invalidates group-level coverage", () => {
  const s = fakeSeries({ budget_approval: "APPROVED" });
  const r = importSynthetic(s);
  assert.equal(r.groups[0].metrics[0].coverage, "INCOMPLETE");
  assert.equal(r.groups[0].metrics[0].median, null);
});

test("FB28: group coverage claim conflicts with reported counts", () => {
  const s = fakeSeries();
  s.groups[0].metrics[0].coverage = "PARTIAL";
  const r = importSynthetic(s);
  assert.equal(r.groups[0].metrics[0].coverage, "INCOMPLETE");
});

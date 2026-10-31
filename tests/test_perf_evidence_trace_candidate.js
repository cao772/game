/* GAME-WEB-PERF-006/r1 — future-only, synthetic contract examples.
 * Intentionally NOT_RUN. Do not run as part of this delivery.
 * Node built-in assert and node:test; no Godot, network or private inputs.
 */
"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const model = require("../tools/perf_evidence_browser/model.js");
const trace = require("../tools/perf_evidence_browser/trace.js");

function sourceSingle(capture = { origin: "SYNTHETIC" }) {
  return {
    task_id: "GAME-WEB-MODULE-PERF-002",
    version: "r1",
    whole_scene_status: "INCOMPLETE",
    full_scene_pass: false,
    budget_approval: "UNAPPROVED_PROPOSAL",
    sample_count: 62,
    measured_subset_status: "PASS",
    capture,
    warnings: [],
    metrics: model.METRICS.map(([key, name, unit, budget]) => ({
      key, name, unit, budget,
      budget_status: "PROPOSAL",
      observed: budget,
      status: "PASS",
      note: "synthetic-only assertion",
    }))
  };
}
function normalized(raw) {
  return model.normalize("candidate-report.json", JSON.stringify(raw));
}
function oneGap(report, metricName) {
  return report.classifiedMissing.find(x => x.metric === metricName);
}

test("PF01: normalized synthetic declaration never becomes verified benchmark", () => {
  const evidence = trace.traceReport(normalized(sourceSingle()));
  assert.equal(evidence.report.sourceClass, "SYNTHETIC");
  assert.equal(evidence.verifiedBenchmark, false);
  assert.equal(evidence.fullScenePass, false);
  assert.equal(evidence.budgetApproved, false);
  assert.equal(evidence.deliveryStatus, "NOT_RUN");
});

test("PF02: null is NOT_MEASURED, never 0", () => {
  const src = sourceSingle();
  src.metrics[3].observed = null;
  src.metrics[3].status = "INCOMPLETE";
  src.measured_subset_status = "INCOMPLETE";
  const normalizedReport = normalized(src);
  const evidence = trace.traceReport(normalizedReport);
  assert.equal(oneGap(evidence, "script_p95_ms").category, "NOT_MEASURED");
  assert.equal(normalizedReport.metrics[3].observed, null);
});

test("PF03: boolean and negative values are INVALID_VALUE rather than absent", () => {
  for (const observed of [false, -1, "invalid"]) {
    const src = sourceSingle();
    src.metrics[5].observed = observed;
    src.metrics[5].status = "INCOMPLETE";
    src.measured_subset_status = "INCOMPLETE";
    const ev = trace.traceReport(normalized(src));
    assert.equal(oneGap(ev, "vram_delta_peak_gib").category, "INVALID_VALUE");
  }
});

test("PF04: a provided value with incompatible budget is INCONSISTENT_INPUT", () => {
  const src = sourceSingle();
  src.metrics[0].budget = 999;
  const ev = trace.traceReport(normalized(src));
  assert.equal(oneGap(ev, "frame_p50_ms").category, "INCONSISTENT_INPUT");
});

test("PF05: PR12 single summary does not magically verify raw CSV origin", () => {
  const ev = trace.traceReport(normalized(sourceSingle()));
  assert.equal(ev.chain[0].stage, "RAW_CAPTURE");
  assert.equal(ev.chain[0].state, "NOT_VERIFIED");
  assert.equal(ev.chain[1].stage, "PERF_002_ANALYZER");
  assert.equal(ev.chain[1].state, "NOT_LINKED");
  assert.equal(ev.chain[2].state, "DECLARED_REPORT_INPUT");
  assert.equal(ev.chain[3].state, "PARSED_UNVERIFIED");
});

test("PF06: engine and scene SHA are declarations not hash checks", () => {
  const src = sourceSingle({
    origin: "DECLARED_REAL_UNLINKED",
    engine_version: "4.7.2",
    renderer: "opengl3",
    scene_sha256: "a".repeat(64)
  });
  const ev = trace.traceReport(normalized(src));
  assert.equal(ev.report.declaredSceneSha256, "a".repeat(64));
  assert.equal(ev.report.sceneHashVerified, false);
  assert.equal(ev.report.rawCsvSha256Verified, false);
  assert.equal(ev.report.independentRepeatVerified, false);
});

test("PF07: missing scene hash creates UNVERIFIED_ORIGIN, not fake hash", () => {
  const ev = trace.traceReport(normalized(sourceSingle()));
  assert.ok(ev.contextIssues.some(x => x.category === "UNVERIFIED_ORIGIN"));
  assert.equal(ev.report.declaredSceneSha256, "未提供");
});

test("PF08: headless/dummy mode produces SOURCE_CONFLICT context", () => {
  const src = sourceSingle({
    origin: "NOT_GPU_BENCHMARK",
    renderer: "dummy",
    display_server: "headless"
  });
  const ev = trace.traceReport(normalized(src));
  assert.ok(ev.contextIssues.some(x => x.category === "SOURCE_CONFLICT"));
  assert.equal(ev.verifiedBenchmark, false);
});

test("PF09: unmeasured whole-scene metrics remain OUT_OF_SCOPE", () => {
  const ev = trace.traceReport(normalized(sourceSingle()));
  assert.equal(ev.outOfScope.length, 5);
  assert.ok(ev.outOfScope.every(x => x.category === "OUT_OF_SCOPE"));
  assert.equal(ev.wholeSceneStatus, "INCOMPLETE");
});

test("PF10: session aggregate sums missing classifications but never claims real tests", () => {
  const a = normalized(sourceSingle());
  const bSrc = sourceSingle();
  bSrc.metrics[4].observed = null;
  bSrc.metrics[4].status = "INCOMPLETE";
  bSrc.measured_subset_status = "INCOMPLETE";
  const b = normalized(bSrc);
  const total = trace.traceSelection([a, b]);
  assert.equal(total.count, 2);
  assert.ok(total.byCategory.NOT_MEASURED >= 1);
  assert.equal(total.testStatus, "NOT_RUN");
  assert.equal(total.status, "INCOMPLETE");
  assert.match(total.warning, /same original capture/);
});

test("PF11: unacceptable number of reports is rejected without scanning local paths", () => {
  assert.throws(() => trace.traceSelection(Array(41).fill(null)), /at most 40/);
});

test("PF12: unknown object is rejected, no speculative report structure", () => {
  assert.throws(() => trace.traceReport({ kind: "unrecognized" }), /Unsupported/);
});

test("PF13: trace preserves input report (pure normalization)", () => {
  const report = normalized(sourceSingle());
  const before = JSON.stringify(report);
  trace.traceReport(report);
  assert.equal(JSON.stringify(report), before);
});

test("PF14: source input path is not copied into trace output", () => {
  const src = sourceSingle();
  src.source = "C:\\Users\\private\\story\\secret.csv";
  const traceJson = JSON.stringify(trace.traceReport(normalized(src)));
  assert.ok(!traceJson.includes("private\\story"));
  assert.ok(!traceJson.includes("secret.csv"));
});

test("PF15: group missing coverage classifies PARTIAL, absent and inconsistency", () => {
  assert.equal(trace.gapForGroupMetric({coverage: "PARTIAL"}), "PARTIAL_COVERAGE");
  assert.equal(trace.gapForGroupMetric({coverage: "NOT_MEASURED"}), "NOT_MEASURED");
  assert.equal(trace.gapForGroupMetric({coverage: "INCOMPLETE"}), "INCONSISTENT_INPUT");
});

test("PF16: browser includes trace module and renders evidence ledger offline", () => {
  const root = path.join(__dirname, "..", "tools", "perf_evidence_browser");
  const html = fs.readFileSync(path.join(root, "index.html"), "utf8");
  const app = fs.readFileSync(path.join(root, "app.js"), "utf8");
  assert.match(html, /trace\.js/);
  assert.match(html, /id="trace-details"/);
  assert.match(html, /connect-src 'none'/);
  assert.match(app, /renderTraceDetails/);
  assert.match(app, /trace\.traceReport/);
  assert.ok(!app.includes("innerHTML"));
  assert.ok(!app.includes("localStorage"));
});

test("PF17: duplicate run fingerprint not inferred from identical declared scene hash", () => {
  const a = normalized(sourceSingle({origin: "SYNTHETIC", scene_sha256: "b".repeat(64)}));
  const b = normalized(sourceSingle({origin: "SYNTHETIC", scene_sha256: "b".repeat(64)}));
  const result = trace.traceSelection([a, b]);
  assert.equal(result.count, 2);
  assert.equal(result.rows[0].report.independentRepeatVerified, false);
  assert.equal(result.rows[1].report.independentRepeatVerified, false);
});

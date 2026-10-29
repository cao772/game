/* GAME-WEB-FLOW-PERF-004/r1 — offline evidence-browser data model.
 * Technical candidate; NOT_RUN; no networking, persistence, or execution of
 * input content. Never treats proposal budgets as measured observations.
 * Self-contained UMD export for browser and future Node built-in tests.
 */
(function (root) {
  "use strict";

  const VERSION = "r1";
  const MAX_FILE_BYTES = 2000000;
  const MAX_FILES = 40;
  const METRICS = Object.freeze([
    ["frame_p50_ms", "帧间隔 P50", "ms", 12, ["frame_ms", "p50"]],
    ["frame_p95_ms", "帧间隔 P95", "ms", 16.7, ["frame_ms", "p95"]],
    ["frame_p99_ms", "帧间隔 P99", "ms", 24, ["frame_ms", "p99"]],
    ["script_p95_ms", "脚本 P95", "ms", 2, ["script_ms", "p95"]],
    ["ram_peak_gib", "逐帧 RAM 峰值", "GiB", 1.2, ["ram_gib", "peak"]],
    ["vram_delta_peak_gib", "VRAM 增量峰值", "GiB", 1, ["vram_delta_gib", "peak"]],
    ["draw_calls_peak", "绘制调用峰值", "/帧", 200, ["draw_calls", "peak"]],
    ["triangles_peak", "三角面峰值", "/帧", 150000, ["triangles", "peak"]]
  ]);
  const MISSING_SCENE = Object.freeze([
    "cold_load_s", "scene_switch_s", "dynamic_lights_peak",
    "shadow_lights_peak", "active_npcs_peak"
  ]);
  const PERCENTILE = "nearest-rank: ascending, rank=ceil(p*n), p in {0.50,0.95,0.99}; no interpolation";
  const GOOD_SOURCE_STATES = new Set(["PASS", "FAIL"]);

  function dict(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }
  function finite(v) { return typeof v === "number" && Number.isFinite(v) && v >= 0 ? v : null; }
  function integer(v) { return Number.isSafeInteger(v) && v >= 0 ? v : null; }
  function label(v, max) {
    return typeof v === "string" ? v.slice(0, max || 120) : "未提供";
  }
  function field(obj, key) { return dict(obj) ? obj[key] : undefined; }
  function keyIndex(metrics) {
    const map = Object.create(null);
    for (const row of metrics) { map[row.key] = row; }
    return map;
  }
  function proposedMetric(spec, observed, sourceStatus, issues, canRead, note) {
    const [key, name, unit, ceiling] = spec;
    const actual = finite(observed);
    const budget = ceiling; // explicitly an unapproved proposal, NEVER observed
    const usable = canRead && actual !== null && GOOD_SOURCE_STATES.has(sourceStatus);
    const expected = actual === null ? null : (actual <= ceiling ? "PASS" : "FAIL");
    let diagnostic = "NOT_MEASURED";
    let reason = note || "来源未提供有效观测";
    if (actual !== null && !usable) {
      diagnostic = "INCOMPLETE";
      reason = note || "数值存在，但来源状态或口径未验证";
    } else if (usable && sourceStatus === expected) {
      diagnostic = actual <= ceiling ? "WITHIN_PROPOSAL" : "OVER_PROPOSAL";
      reason = "仅按未批准预算作数值对照；不是游戏验收";
    } else if (usable && sourceStatus !== expected) {
      diagnostic = "INCOMPLETE";
      reason = "来源PASS/FAIL与观测和预算冲突";
      issues.push(key + "：状态与数值不符");
    }
    return { key, name, unit, budget, budgetKind: "UNAPPROVED_PROPOSAL",
      observed: actual, sourceStatus: label(sourceStatus, 24),
      diagnostic, reason, usable: diagnostic === "WITHIN_PROPOSAL" || diagnostic === "OVER_PROPOSAL" };
  }
  function normalizeOrigin(capture, fallback) {
    const origin = field(capture, "origin");
    const explicit = field(capture, "is_synthetic");
    const fallbackSynthetic = field(fallback, "is_synthetic");
    const originString = typeof origin === "string" ? origin : "";
    const synthetic = explicit === true || fallbackSynthetic === true || originString === "SYNTHETIC";
    const contradicted = (synthetic && (explicit === false || fallbackSynthetic === false)) ||
      (explicit === true && originString === "DECLARED_REAL_UNLINKED");
    if (contradicted) return ["CONFLICT", "合成标识与其他声明矛盾"];
    if (synthetic) return ["SYNTHETIC", "来源声明：合成数据（不是游戏跑分）"];
    if (originString === "NOT_GPU_BENCHMARK") return ["NOT_GPU_BENCHMARK", "headless/dummy，不能视为GPU跑分"];
    const rendering = label(field(capture, "renderer") || field(capture, "rendering_driver"), 80).toLowerCase();
    const display = label(field(capture, "display_server"), 80).toLowerCase();
    if (rendering.includes("dummy") || rendering.includes("headless") || display.includes("headless")) {
      return ["NOT_GPU_BENCHMARK", "headless/dummy，不具备GPU跑分依据"];
    }
    if (originString === "DECLARED_REAL_UNLINKED" || explicit === false) {
      return ["DECLARED_REAL_UNVERIFIED", "声明非合成；缺少原始文件/场景哈希核对"];
    }
    return ["UNVERIFIED", "没有可核验来源声明；不能认定实测"];
  }
  function metadata(capture) {
    const base = dict(capture) ? capture : {};
    return {
      origin: label(base.origin, 64),
      engineVersion: label(base.engine_version, 80),
      renderer: label(base.renderer || base.rendering_driver, 80),
      sceneHash: label(base.scene_sha256, 84),
      displayServer: label(base.display_server, 60),
      capturedComplete: base.capture_complete === true,
      provenanceVerified: false
    };
  }
  function overallFlags(item, issues) {
    if (item.full_scene_pass === true) issues.push("来源声称完整场景PASS，浏览器不采信");
    if (item.whole_scene_status && item.whole_scene_status !== "INCOMPLETE") {
      issues.push("来源整体场景状态与候选预期不符");
    }
  }
  function baseReport(kind, source, capture, issues) {
    const provenance = normalizeOrigin(capture, source);
    return {
      kind, sourceTask: label(source.task_id, 80), provenance: provenance[0],
      provenanceNote: provenance[1], capture: metadata(capture),
      wholeSceneStatus: "INCOMPLETE", fullScenePass: false,
      budgetApproved: false, provenanceVerified: false,
      warnings: issues, metrics: [], groups: [], missingScene: [...MISSING_SCENE],
      sampleCount: integer(source.sample_count), sourceStatus: label(source.measured_subset_status, 24)
    };
  }
  function singleReport(source) {
    const issues = [];
    const capture = dict(source.capture) ? source.capture : null;
    const result = baseReport("single", source, capture, issues);
    overallFlags(source, issues);
    const list = Array.isArray(source.metrics) ? source.metrics : [];
    const byKey = Object.create(null);
    const duplicateKeys = new Set();
    for (const item of list) {
      if (!dict(item) || typeof item.key !== "string") { issues.push("指标行格式异常"); continue; }
      if (Object.prototype.hasOwnProperty.call(byKey, item.key)) {
        issues.push(item.key.slice(0, 40) + "：重复指标，不采信该指标");
        duplicateKeys.add(item.key);
      }
      byKey[item.key] = item;
    }
    const sourceClean = (
      ["GAME-WEB-MODULE-PERF-001", "GAME-WEB-MODULE-PERF-002"].includes(source.task_id) &&
      source.version === "r1" &&
      source.budget_approval === "UNAPPROVED_PROPOSAL" &&
      ["PASS", "FAIL", "INCOMPLETE"].includes(source.measured_subset_status) &&
      source.whole_scene_status === "INCOMPLETE" &&
      source.full_scene_pass === false && result.sampleCount !== null &&
      result.sampleCount > 0
    );
    if (!sourceClean) issues.push("整体状态或有效样本数缺失，禁止认定任何单项达预算");
    result.metrics = METRICS.map(spec => {
      const row = byKey[spec[0]];
      const status = field(row, "status");
      const sourceBudget = finite(field(row, "budget"));
      const coherent = sourceBudget === spec[3] && sourceClean &&
        !duplicateKeys.has(spec[0]) &&
        field(row, "budget_status") === "PROPOSAL";
      if (row && sourceBudget !== spec[3]) issues.push(spec[0] + "：预算口径不一致");
      return proposedMetric(spec, field(row, "observed"), status, issues, coherent,
        !row ? "该项未出现在来源报告" : (!coherent ? "来源预算或采样状态无法核对" : ""));
    });
    const inputWarnings = Array.isArray(source.warnings) ? source.warnings : [];
    for (const w of inputWarnings.slice(0, 25)) {
      if (typeof w === "string") issues.push("来源提示：" + w.slice(0, 150));
    }
    if (dict(source.process_memory)) {
      const mem = source.process_memory;
      result.processMemory = {
        workingSet: finite(mem.working_set_peak_observed_gib),
        privateCommit: finite(mem.private_bytes_peak_observed_gib),
        quality: label(mem.quality, 60),
        note: "独立PID工作集与私有提交，不可填入逐帧ram_gib"
      };
    }
    return result;
  }
  function analyzerReport(source) {
    const issues = [];
    const result = baseReport("analyzer", source, null, issues);
    overallFlags(source, issues);
    const checks = dict(source.checks) ? source.checks : {};
    const stats = dict(source.stats) ? source.stats : {};
    const good = source.task_id === "GAME-WEB-PERF-002" && source.version === "r1" &&
      source.error_count === 0 && Array.isArray(source.errors) && source.errors.length === 0 &&
      result.sampleCount !== null && result.sampleCount > 0 &&
      source.status === "incomplete" && source.full_scene_pass === false &&
      source.percentile_definition === PERCENTILE;
    if (!good) issues.push("分析器输入存在缺失/异常，全部单项降级，不能判断预算通过");
    result.metrics = METRICS.map(spec => {
      const key = spec[0], check = field(checks, key);
      const node = field(stats, spec[4][0]);
      const stat = field(node, spec[4][1]);
      const observation = field(check, "value");
      const matching = finite(observation) !== null &&
        finite(stat) !== null && observation === stat;
      const bound = finite(field(check, "upper_inclusive"));
      const coherent = good && matching && bound === spec[3];
      if (check && !matching && finite(observation) !== null) {
        issues.push(key + "：checks与stats无法核对");
      }
      return proposedMetric(spec, observation, field(check, "status"), issues, coherent,
        !check ? "分析器没有该指标" : !coherent ? "分析器输入无效、缺测或口径冲突" : "");
    });
    if (typeof source.source === "string") {
      issues.push("未读取原始CSV或其SHA256；分析器报告路径不是来源真实性证明");
    }
    return result;
  }
  function seriesReport(source) {
    const issues = [];
    const result = baseReport("series", source, null, issues);
    overallFlags(source, issues);
    result.sourceStatus = "DESCRIPTIVE_ONLY";
    const seriesContract = source.task_id === "GAME-WEB-CONTINUE-PERF-003" &&
      source.version === "r1" && source.schema === "perf-series-report-v1" &&
      source.status === "INCOMPLETE" &&
      source.budget_approval === "UNAPPROVED_PROPOSAL" &&
      source.full_scene_pass === false && source.whole_scene_status === "INCOMPLETE";
    if (!seriesContract) {
      issues.push("分组摘要版本、预算声明或整体状态异常；不采信数值覆盖率");
    }
    const groups = Array.isArray(source.groups) ? source.groups.slice(0, 2) : [];
    if (!groups.length) issues.push("没有有效分组");
    const groupOrigins = [];
    result.groups = groups.map((g, gi) => {
      const runs = Array.isArray(field(g, "runs")) ? g.runs.slice(0, 24) : [];
      const n = integer(field(g, "n_runs"));
      if (n === null || n !== runs.length || !runs.length) issues.push("分组" + gi + "采样数不一致");
      const origins = runs.map(run => {
        const o = label(field(run, "source_origin"), 64);
        groupOrigins.push(o);
        return o;
      });
      const rawMetrics = Array.isArray(field(g, "metrics")) ? g.metrics : [];
      const metricByKey = Object.create(null);
      const duplicateMetrics = new Set();
      for (const row of rawMetrics) {
        if (dict(row) && typeof row.key === "string") {
          if (Object.prototype.hasOwnProperty.call(metricByKey, row.key)) {
            issues.push("分组重复指标：" + row.key.slice(0, 40));
            duplicateMetrics.add(row.key);
          }
          metricByKey[row.key] = row;
        }
      }
      const metrics = METRICS.map(spec => {
        const m = metricByKey[spec[0]];
        const total = integer(field(m, "n_total"));
        const measured = integer(field(m, "n_observed"));
        const missing = integer(field(m, "n_missing"));
        const validCounts = total !== null && total === n && measured !== null &&
          missing !== null && measured + missing === total && measured <= total;
        const minimum = finite(field(m, "min"));
        const middle = finite(field(m, "median"));
        const maximum = finite(field(m, "max"));
        const budgetConsistent = finite(field(m, "budget")) === spec[3] &&
          field(m, "budget_status") === "UNAPPROVED_PROPOSAL";
        const order = measured > 0 && minimum !== null && middle !== null &&
          maximum !== null && minimum <= middle && middle <= maximum;
        const empty = measured === 0 && minimum === null && middle === null && maximum === null;
        const expectedCoverage = measured === 0 ? "NOT_MEASURED" :
          measured === total ? "COMPLETE_NUMERIC" : "PARTIAL";
        const expectedMissingRuns = measured === total ||
          (Array.isArray(field(m, "missing_runs")) &&
           m.missing_runs.length === missing);
        const coherent = seriesContract && n !== null && n > 0 &&
          !duplicateMetrics.has(spec[0]) && validCounts && budgetConsistent &&
          field(m, "coverage") === expectedCoverage && expectedMissingRuns &&
          (order || empty);
        if (!coherent) issues.push((typeof g.name === "string" ? g.name.slice(0, 30) : "组") + "/" + spec[0] + "存在缺测或数值异常");
        const coverage = coherent ? (
          measured === 0 ? "NOT_MEASURED" :
          measured === total ? "COMPLETE_NUMERIC" : "PARTIAL"
        ) : "INCOMPLETE";
        return { key: spec[0], name: spec[1], unit: spec[2],
          budget: spec[3], budgetKind: "UNAPPROVED_PROPOSAL",
          min: coherent && measured ? minimum : null, median: coherent && measured ? middle : null,
          max: coherent && measured ? maximum : null,
          nObserved: validCounts ? measured : null, nTotal: validCounts ? total : null,
          coverage, sourceCoverage: label(field(m, "coverage"), 40),
          missingRuns: Array.isArray(field(m, "missing_runs")) ?
            m.missing_runs.slice(0, 24).map(x => ({
              id: label(field(x, "run_id"), 32), status: label(field(x, "status"), 28),
              reason: label(field(x, "reason"), 160)
            })) : [] };
      });
      return {
        name: label(field(g, "name"), 32), nRuns: n, origins, metrics,
        runDetails: runs.map(x => {
          const c = field(x, "capture");
          return {
            id: label(field(x, "id"), 32),
            sourceStatus: label(field(x, "analyzer_subset_status"), 40),
            sourceOrigin: label(field(x, "source_origin"), 64),
            count: integer(field(x, "sample_count")),
            engineVersion: label(field(c, "engine_version"), 80),
            renderer: label(field(c, "renderer"), 80),
            sceneHash: label(field(c, "scene_sha256"), 84),
            warnings: Array.isArray(field(x, "warnings")) ?
              x.warnings.slice(0, 24).filter(w => typeof w === "string")
                .map(w => w.slice(0, 160)) : []
          };
        })
      };
    });
    const uniq = [...new Set(groupOrigins)];
    if (uniq.length === 1 && uniq[0] === "SYNTHETIC") {
      result.provenance = "SYNTHETIC";
      result.provenanceNote = "所有来源声明为合成，非游戏跑分";
    } else if (uniq.includes("SYNTHETIC") && uniq.length > 1) {
      result.provenance = "CONFLICT";
      result.provenanceNote = "混用合成及其他来源声明";
    } else if (uniq.includes("NOT_GPU_BENCHMARK")) {
      result.provenance = "NOT_GPU_BENCHMARK";
      result.provenanceNote = "含headless/dummy记录，不能视为GPU测试";
    } else if (uniq.length && uniq.every(o => o === "DECLARED_REAL_UNLINKED")) {
      result.provenance = "DECLARED_REAL_UNVERIFIED";
      result.provenanceNote = "各次声明非合成，但没有核对原始证据";
    } else {
      result.provenance = "UNVERIFIED";
      result.provenanceNote = "分组来源缺失或混杂；未验证";
    }
    const missing = Array.isArray(source.missing_run_details) ? source.missing_run_details.slice(0, 48) : [];
    result.missingByRun = missing.map(r => ({
      group: label(field(r, "group"), 32), id: label(field(r, "id"), 32),
      missing: Array.isArray(field(r, "missing")) ? r.missing.slice(0, 8).map(x => ({
        metric: label(field(x, "metric"), 42), status: label(field(x, "status"), 28),
        reason: label(field(x, "reason"), 160)
      })) : []
    }));
    if (source.group_comparison) {
      issues.push("来源组间差值仅是run级描述性比较；不转化为跑分验收");
    }
    return result;
  }
  function normalize(filename, text) {
    if (typeof text !== "string" || text.length > MAX_FILE_BYTES) {
      throw new Error("输入超出2000000字符限制");
    }
    let obj;
    try { obj = JSON.parse(text); } catch (_) { throw new Error("JSON无效；不能导入"); }
    if (!dict(obj)) throw new Error("根节点必须为JSON对象");
    let report;
    if (obj.schema === "perf-series-report-v1" && Array.isArray(obj.groups)) {
      report = seriesReport(obj);
    } else if (Array.isArray(obj.metrics) && "whole_scene_status" in obj) {
      report = singleReport(obj);
    } else if (obj.task_id === "GAME-WEB-PERF-002" && dict(obj.checks)) {
      report = analyzerReport(obj);
    } else {
      throw new Error("不支持的证据结构：仅PERF-002分析器/PR#12单次及分组报告");
    }
    report.filename = label(filename, 100);
    report.browserId = null;
    report.isSynthetic = report.provenance === "SYNTHETIC";
    report.gpuBenchmarkVerified = false;
    report.reportTrust = "UNVERIFIED_INPUT";
    return report;
  }
  function compare(a, b) {
    if (!a || !b || a.kind === "series" || b.kind === "series") {
      return { context: "NOT_COMPARABLE", note: "多轮聚合统计不得当作单次逐帧指标跨文件直接对比", rows: [] };
    }
    const ca = a.capture || {}, cb = b.capture || {};
    const keys = ["engineVersion", "renderer", "sceneHash"];
    const conflicts = keys.filter(k => ca[k] && cb[k] &&
      ca[k] !== "未提供" && cb[k] !== "未提供" && ca[k] !== cb[k]);
    if (a.provenance !== b.provenance ||
        a.provenance === "CONFLICT" || b.provenance === "CONFLICT") {
      conflicts.push("source_origin");
    }
    const context = conflicts.length ? "CONFLICT" : "UNVERIFIED";
    const old = keyIndex(a.metrics), now = keyIndex(b.metrics);
    const rows = METRICS.map(spec => {
      const x = old[spec[0]], y = now[spec[0]];
      const valid = !conflicts.length && x && y && x.usable && y.usable &&
        x.budget === y.budget && x.unit === y.unit;
      const d = valid ? y.observed - x.observed : null;
      const delta = typeof d === "number" && Number.isFinite(d) ? d : null;
      const p = delta !== null && x.observed !== 0 ? (delta / x.observed) * 100 : null;
      return { key: spec[0], name: spec[1], unit: spec[2],
        baseline: x ? x.observed : null, current: y ? y.observed : null,
        delta, deltaPercent: typeof p === "number" && Number.isFinite(p) ? p : null,
        status: delta === null ? "NOT_COMPARABLE" : "NUMERIC_ONLY" };
    });
    return { context, note: conflicts.length ?
      "来源声明或引擎/场景信息存在冲突：" + conflicts.join(", ") :
      "仅按可读数值计算差值，未核实同设备、同场景和同采样时段",
      rows, benchmarkVerified: false };
  }
  const api = Object.freeze({ VERSION, MAX_FILE_BYTES, MAX_FILES, METRICS,
    normalize, compare, finite, normalizeOrigin });
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root && typeof root === "object") root.PerfEvidenceModel = api;
})(typeof window === "object" ? window : null);

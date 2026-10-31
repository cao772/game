/* GAME-WEB-PERF-006/r1 — read-only evidence trace and gap taxonomy.
 * Candidate only. NOT_RUN. Operates on normalized public-contract report
 * objects in memory. No disk, network, crypto claim, or data export.
 */
(function (root) {
  "use strict";

  const GAP = Object.freeze({
    NOT_MEASURED: "NOT_MEASURED",
    INVALID_VALUE: "INVALID_VALUE",
    INCONSISTENT_INPUT: "INCONSISTENT_INPUT",
    PARTIAL_COVERAGE: "PARTIAL_COVERAGE",
    SOURCE_CONFLICT: "SOURCE_CONFLICT",
    UNVERIFIED_ORIGIN: "UNVERIFIED_ORIGIN",
    OUT_OF_SCOPE: "OUT_OF_SCOPE"
  });
  const DESCRIPTIONS = Object.freeze({
    NOT_MEASURED: "没有可用的原始观测值；不是零",
    INVALID_VALUE: "观测字段为负数、非数字、布尔或非有限数",
    INCONSISTENT_INPUT: "字段、预算、来源状态或统计口径互相矛盾",
    PARTIAL_COVERAGE: "仅部分run有可用数值；不得推算全量",
    SOURCE_CONFLICT: "采集来源或声明的环境信息存在冲突",
    UNVERIFIED_ORIGIN: "报告数值可读，但缺少可靠的原始采样与身份绑定",
    OUT_OF_SCOPE: "不属于当前报告的已观测字段，仍待独立验证"
  });
  const VALID_METRIC = new Set(["WITHIN_PROPOSAL", "OVER_PROPOSAL"]);
  const SCENE_LABELS = Object.freeze({
    cold_load_s: "冷启动耗时",
    scene_switch_s: "场景切换耗时",
    dynamic_lights_peak: "动态灯峰值",
    shadow_lights_peak: "阴影灯峰值",
    active_npcs_peak: "活跃NPC峰值"
  });
  function text(value, max = 100) {
    return typeof value === "string" ? value.slice(0, max) : "未提供";
  }
  function positiveCount(v) {
    return Number.isSafeInteger(v) && v >= 0 ? v : null;
  }
  function gapForMetric(metric) {
    if (!metric) return GAP.NOT_MEASURED;
    if (metric.missingKind === "INVALID_VALUE") return GAP.INVALID_VALUE;
    if (metric.diagnostic === "NOT_MEASURED") return GAP.NOT_MEASURED;
    if (metric.diagnostic === "INCOMPLETE" || metric.usable === false) {
      return GAP.INCONSISTENT_INPUT;
    }
    if (VALID_METRIC.has(metric.diagnostic) && metric.usable === true) {
      return null;
    }
    return GAP.INCONSISTENT_INPUT;
  }
  function gapForGroupMetric(metric) {
    if (!metric || metric.coverage === "NOT_MEASURED") return GAP.NOT_MEASURED;
    if (metric.coverage === "PARTIAL") return GAP.PARTIAL_COVERAGE;
    if (metric.coverage === "COMPLETE_NUMERIC") return null;
    return GAP.INCONSISTENT_INPUT;
  }
  function known(v) { return typeof v === "string" && v && v !== "未提供"; }
  function declaredMetadata(report) {
    const c = report && report.capture ? report.capture : {};
    return {
      fileLabel: text(report && report.filename, 100),
      kind: text(report && report.kind, 24),
      reportTaskId: text(report && report.sourceTask, 80),
      sourceClass: text(report && report.provenance, 40),
      declaredEngine: text(c.engineVersion, 80),
      declaredRenderer: text(c.renderer, 80),
      declaredDisplay: text(c.displayServer, 60),
      declaredSceneSha256: text(c.sceneHash, 84),
      frameCount: positiveCount(report && report.sampleCount),
      sceneHashVerified: false,
      rawCsvSha256Verified: false,
      binaryExeVerified: false,
      captureAssociationVerified: false,
      independentRepeatVerified: false
    };
  }
  function provenanceChain(report) {
    const kind = report && report.kind;
    const first = {
      stage: "RAW_CAPTURE", state: "NOT_VERIFIED",
      explanation: "未读取或验证源CSV、进程创建ID、帧时钟及真实设备记录"
    };
    const analysis = {
      stage: "PERF_002_ANALYZER",
      state: kind === "analyzer" ? "DECLARED_REPORT_INPUT" : "NOT_LINKED",
      explanation: kind === "analyzer" ?
        "当前文件声明来自PERF-002分析器；仍未取得原始CSV哈希" :
        "当前导入的是下游摘要，未逐份链接到原分析器输入"
    };
    const summary = {
      stage: "PR12_REPORT",
      state: kind === "single" || kind === "series" ?
        "DECLARED_REPORT_INPUT" : "NOT_APPLICABLE",
      explanation: kind === "single" || kind === "series" ?
        "当前文件含PR#12报告结构；上游完整链路未经核对" :
        "当前文件仅为原分析器结果，无PR#12摘要证明"
    };
    return [
      first, analysis, summary,
      { stage: "LOCAL_BROWSER", state: "PARSED_UNVERIFIED",
        explanation: "当前浏览器在内存中解析所选文件，不能证明数据原件未修改" }
    ];
  }
  function metricGaps(report) {
    const entries = [];
    if (report && report.kind === "series") {
      const groups = Array.isArray(report.groups) ? report.groups : [];
      for (const group of groups) {
        for (const m of Array.isArray(group.metrics) ? group.metrics : []) {
          const code = gapForGroupMetric(m);
          if (!code) continue;
          const sourceMissing = Array.isArray(m.missingRuns) ? m.missingRuns : [];
          entries.push({
            group: text(group.name, 32), metric: text(m.key, 42),
            label: text(m.name, 80), category: code,
            available: positiveCount(m.nObserved), total: positiveCount(m.nTotal),
            details: sourceMissing.slice(0, 24).map(r => ({
              id: text(r.id, 32), reason: text(r.reason, 150),
              status: text(r.status, 32)
            })),
            explanation: DESCRIPTIONS[code]
          });
        }
      }
    } else {
      for (const m of Array.isArray(report && report.metrics) ? report.metrics : []) {
        const code = gapForMetric(m);
        if (!code) continue;
        entries.push({
          group: "single", metric: text(m.key, 42), label: text(m.name, 80),
          category: code, available: 0, total: 1,
          details: [], explanation: text(m.reason, 170) + "；" + DESCRIPTIONS[code]
        });
      }
    }
    return entries;
  }
  function traceReport(report) {
    if (!report || !["single", "series", "analyzer"].includes(report.kind)) {
      throw new TypeError("Unsupported normalized report");
    }
    const meta = declaredMetadata(report);
    const gaps = metricGaps(report);
    const contextIssues = [];
    if (report.provenance === "CONFLICT" ||
        report.provenance === "NOT_GPU_BENCHMARK") {
      contextIssues.push({
        category: GAP.SOURCE_CONFLICT,
        explanation: "来源冲突或非GPU环境，不允许据此宣称GPU性能"
      });
    } else {
      contextIssues.push({
        category: GAP.UNVERIFIED_ORIGIN,
        explanation: "来源声明尚未通过真实进程、原始文件与时间窗核查"
      });
    }
    if (!known(meta.declaredSceneSha256)) {
      contextIssues.push({
        category: GAP.UNVERIFIED_ORIGIN,
        explanation: "缺少可供独立校验的场景SHA256声明"
      });
    }
    const missingScene = Array.isArray(report.missingScene) ? report.missingScene : [];
    const outOfScope = missingScene.slice(0, 16).map(key => ({
      key: text(key, 60), label: SCENE_LABELS[key] || text(key, 60),
      category: GAP.OUT_OF_SCOPE,
      explanation: DESCRIPTIONS.OUT_OF_SCOPE
    }));
    const byCategory = Object.create(null);
    for (const cat of Object.values(GAP)) byCategory[cat] = 0;
    for (const entry of gaps) byCategory[entry.category] += 1;
    for (const entry of contextIssues) byCategory[entry.category] += 1;
    byCategory.OUT_OF_SCOPE += outOfScope.length;
    return {
      task_id: "GAME-WEB-PERF-006",
      version: "r1", deliveryStatus: "NOT_RUN",
      report: meta, chain: provenanceChain(report),
      classifiedMissing: gaps, contextIssues, outOfScope,
      countByCategory: byCategory,
      wholeSceneStatus: "INCOMPLETE",
      fullScenePass: false, budgetApproved: false, verifiedBenchmark: false,
      claim: "Only declarations and report-level values were inspected; no independent provenance proof"
    };
  }
  function traceSelection(reports) {
    if (!Array.isArray(reports) || reports.length > 40) {
      throw new RangeError("Expected at most 40 normalized reports");
    }
    const rows = reports.map(traceReport);
    const totals = Object.create(null);
    for (const name of Object.values(GAP)) totals[name] = 0;
    for (const row of rows) {
      for (const [k, v] of Object.entries(row.countByCategory)) totals[k] += v;
    }
    const contexts = Object.create(null);
    for (const row of rows) {
      const key = row.report.sourceClass;
      contexts[key] = (contexts[key] || 0) + 1;
    }
    return {
      task_id: "GAME-WEB-PERF-006", version: "r1",
      status: "INCOMPLETE", testStatus: "NOT_RUN",
      count: rows.length, rows, byCategory: totals, byDeclaredOrigin: contexts,
      warning: "Multiple reports can share the same original capture; no independent-run proof"
    };
  }
  const api = Object.freeze({ GAP, DESCRIPTIONS, traceReport,
    traceSelection, metricGaps, gapForMetric, gapForGroupMetric });
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root && typeof root === "object") root.PerfEvidenceTrace = api;
})(typeof window === "object" ? window : null);

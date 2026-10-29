/* GAME-WEB-PLAY-PERF-005/r1
 * Multi-report comparative reader. PURE MODEL ONLY; implementation NOT_RUN.
 * Never pools frame samples or promotes source claims into verified benchmarks.
 * Standalone browser/Node export; no network, disk, storage or process actions.
 */
(function (root) {
  "use strict";

  const MAX_SELECTED = 12;
  const METRIC_KEYS = Object.freeze([
    "frame_p50_ms", "frame_p95_ms", "frame_p99_ms", "script_p95_ms",
    "ram_peak_gib", "vram_delta_peak_gib", "draw_calls_peak", "triangles_peak"
  ]);
  const VALID = new Set(["WITHIN_PROPOSAL", "OVER_PROPOSAL"]);
  function number(x) {
    return typeof x === "number" && Number.isFinite(x) && x >= 0 ? x : null;
  }
  function signed(x) {
    return typeof x === "number" && Number.isFinite(x) ? x : null;
  }
  function known(value) {
    return typeof value === "string" && value.length > 0 && value !== "未提供";
  }
  function median(sorted) {
    if (!sorted.length) return null;
    const values = [...sorted].sort((a, b) => a - b);
    const middle = Math.floor(values.length / 2);
    const value = values.length % 2 ?
      values[middle] : (values[middle - 1] / 2 + values[middle] / 2);
    return number(value);
  }
  function sourceContext(reports) {
    const conflicts = [];
    const gaps = [];
    const originals = reports.map(r => r.provenance);
    const origins = [...new Set(originals)];
    if (origins.length > 1) conflicts.push("来源类别不同");
    if (origins.includes("CONFLICT")) conflicts.push("已有来源冲突");
    if (origins.includes("NOT_GPU_BENCHMARK")) conflicts.push("含非GPU渲染证据");
    for (const [field, human] of [
      ["engineVersion", "引擎版本"],
      ["renderer", "渲染后端"],
      ["sceneHash", "场景哈希"]
    ]) {
      const values = reports.map(r => r.capture && r.capture[field]);
      const present = values.filter(known);
      if (new Set(present).size > 1) conflicts.push(human + "存在不一致");
      if (present.length < reports.length) gaps.push(human + "缺失");
    }
    const context = conflicts.length ? "CONFLICT" : "UNVERIFIED";
    const synthetic = origins.length === 1 && origins[0] === "SYNTHETIC";
    const evidenceNote = synthetic ?
      "全部输入声明为合成数据，数值对照仅用于验证报告展示逻辑" :
      "输入为来源声明或未核实证据，不能声称已经完成真实游戏跑分";
    return {
      status: context, reasons: conflicts, missingContext: gaps,
      provenance: origins, allSynthetic: synthetic,
      evidenceNote,
      note: conflicts.length ?
        "已声明的采样条件或来源冲突，禁止计算跨文件数值变化" :
        "未证明设备、分辨率、帧率限制、动作、采样时间及文件哈希一致"
    };
  }
  function validateSelected(items) {
    if (!Array.isArray(items) || items.length < 2 || items.length > MAX_SELECTED) {
      throw new RangeError("请选择2至12份独立报告");
    }
    const ids = new Set();
    for (const item of items) {
      if (!item || (item.kind !== "single" && item.kind !== "analyzer")) {
        throw new TypeError("多次比较仅接受分析器或单次摘要，不接受聚合报告");
      }
      if (!Number.isSafeInteger(item.browserId) || item.browserId < 1) {
        throw new TypeError("报告缺少本次浏览器会话ID");
      }
      if (ids.has(item.browserId)) throw new TypeError("不能重复选择相同报告");
      ids.add(item.browserId);
    }
  }
  function compareMany(items, baselineId) {
    validateSelected(items);
    if (!Number.isSafeInteger(baselineId) ||
        !items.some(x => x.browserId === baselineId)) {
      throw new TypeError("基线必须是已选择的一份报告");
    }
    const context = sourceContext(items);
    const baseline = items.find(x => x.browserId === baselineId);
    const index = items.map(r => ({
      id: r.browserId,
      name: typeof r.filename === "string" ? r.filename.slice(0, 100) : "未命名",
      type: r.kind,
      provenance: r.provenance,
      engineVersion: r.capture ? r.capture.engineVersion : "未提供",
      renderer: r.capture ? r.capture.renderer : "未提供",
      sceneHash: r.capture ? r.capture.sceneHash : "未提供",
      sampleCount: r.sampleCount,
      reportedStatus: r.sourceStatus,
      warningCount: Array.isArray(r.warnings) ? r.warnings.length : 0
    }));
    const normalized = items.map(r => {
      const byKey = new Map((r.metrics || []).filter(Boolean).map(x => [x.key, x]));
      return { report: r, byKey };
    });
    const baseMap = normalized[items.indexOf(baseline)].byKey;
    const rows = METRIC_KEYS.map(key => {
      const exemplar = normalized.map(x => x.byKey.get(key)).find(Boolean);
      const baselineMetric = baseMap.get(key);
      const baseValid = baselineMetric &&
        VALID.has(baselineMetric.diagnostic) && baselineMetric.usable === true &&
        number(baselineMetric.observed) !== null;
      const baselineValue = baseValid ? baselineMetric.observed : null;
      const cells = normalized.map(({ report, byKey }) => {
        const metric = byKey.get(key);
        const observed = number(metric && metric.observed);
        const usable = metric && VALID.has(metric.diagnostic) &&
          metric.usable === true && observed !== null &&
          number(metric.budget) !== null;
        const missingReason = !metric ? "没有该指标" :
          usable ? "" : (metric.reason || "缺失或输入冲突");
        const conflictBudget = Boolean(
          usable && baselineMetric && number(baselineMetric.budget) !== number(metric.budget)
        );
        const d = usable && baseValid && !conflictBudget &&
          context.status !== "CONFLICT" ? signed(observed - baselineValue) : null;
        const ratio = d !== null && baselineValue !== 0 ?
          signed(100 * d / baselineValue) : null;
        return {
          id: report.browserId,
          filename: report.filename,
          reported: observed,
          canUse: Boolean(usable),
          diagnostic: metric ? metric.diagnostic : "NOT_MEASURED",
          reason: conflictBudget ? "预算定义冲突" : missingReason,
          delta: d,
          deltaPercent: ratio,
          comparison: d === null ? "NOT_COMPARABLE" : "NUMERIC_ONLY"
        };
      });
      const count = cells.filter(x => x.canUse).length;
      const complete = count === items.length;
      const values = complete ? cells.map(x => x.reported) : [];
      const variation = complete && context.status !== "CONFLICT" ?
        { min: number(Math.min(...values)), median: median(values), max: number(Math.max(...values)) } :
        { min: null, median: null, max: null };
      const missing = cells.filter(x => !x.canUse).map(x => ({
        id: x.id, filename: x.filename, diagnostic: x.diagnostic, reason: x.reason
      }));
      return {
        key,
        name: exemplar ? exemplar.name : key,
        unit: exemplar ? exemplar.unit : "",
        budget: exemplar ? exemplar.budget : null,
        budgetKind: "UNAPPROVED_PROPOSAL",
        total: items.length, nReportedUsable: count,
        coverage: count === 0 ? "NOT_MEASURED" : complete ? "COMPLETE_NUMERIC" : "PARTIAL",
        min: variation.min, median: variation.median, max: variation.max,
        completeContext: context.status !== "CONFLICT",
        missing, cells,
        note: !complete ?
          "存在缺测/异常；不计算跨报告聚合值（并未用零补齐）" :
          context.status === "CONFLICT" ?
            "来源上下文冲突；不计算组中位数或差值" :
            "各报告自身统计量的等权中位数，不是合并帧分位数"
      };
    });
    return {
      task_id: "GAME-WEB-PLAY-PERF-005", version: "r1",
      status: "INCOMPLETE", fullScenePass: false,
      budgetApproved: false, benchmarkVerified: false,
      testStatus: "NOT_RUN", method: "per-report numeric comparison only; no pooled frames",
      context, baselineId, records: index, rows,
      missingOverview: {
        totalMetricCells: rows.length * items.length,
        untrustedOrMissing: rows.reduce((n, x) => n + x.missing.length, 0),
        missingByRecord: index.map(r => ({
          id: r.id, filename: r.name,
          items: rows.flatMap(row =>
            row.missing.filter(x => x.id === r.id).map(x => ({
              key: row.key, label: row.name, diagnostic: x.diagnostic, reason: x.reason
            }))
          )
        }))
      }
    };
  }
  const api = Object.freeze({ MAX_SELECTED, METRIC_KEYS, compareMany, sourceContext, median });
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root && typeof root === "object") root.PerfEvidenceCohort = api;
})(typeof window === "object" ? window : null);

/* GAME-WEB-FLOW-PERF-004/r1 — local File API, read-only evidence browser.
 * No fetch, XHR, storage, service worker, telemetry, eval or remote assets.
 * Candidate is NOT_RUN and must not be described as tested.
 */
(function () {
  "use strict";

  const model = window.PerfEvidenceModel;
  const cohort = window.PerfEvidenceCohort;
  const trace = window.PerfEvidenceTrace;
  const byId = id => document.getElementById(id);
  const state = { reports: [], selected: null, sequence: 0, errors: [], multiSelected: new Set(), seenFiles: new Set(), busy: false };
  const els = {
    files: byId("files"), drop: byId("drop"), count: byId("count"),
    total: byId("total"), synthetic: byId("synthetic-count"),
    real: byId("real-count"), unknown: byId("unknown-count"),
    search: byId("search"), filter: byId("filter"),
    list: byId("report-list"), listEmpty: byId("list-empty"),
    status: byId("import-status"), errors: byId("errors"),
    clear: byId("clear"), detail: byId("detail"),
    baseline: byId("baseline"), current: byId("current"),
    compare: byId("compare"), result: byId("compare-result"),
    multiBaseline: byId("multi-baseline"), multiCompare: byId("multi-compare"),
    multiClear: byId("multi-clear"), multiCount: byId("multi-count"),
    multiResult: byId("multi-result"),
    traceDetails: byId("trace-details"), traceOverview: byId("trace-overview")
  };

  function node(tag, text, className) {
    const n = document.createElement(tag);
    if (text !== undefined && text !== null) n.textContent = String(text);
    if (className) n.className = className;
    return n;
  }
  function put(parent, ...children) {
    for (const c of children) if (c) parent.appendChild(c);
    return parent;
  }
  function clear(parent) { parent.replaceChildren(); }
  function fmt(value, unit) {
    if (typeof value !== "number" || !Number.isFinite(value)) return "未测";
    return new Intl.NumberFormat("zh-CN", { maximumFractionDigits: 5 }).format(value) +
      (unit ? " " + unit : "");
  }
  const ORIGINS = {
    SYNTHETIC: "合成数据",
    DECLARED_REAL_UNVERIFIED: "声明非合成 · 未核实",
    NOT_GPU_BENCHMARK: "非 GPU 跑分",
    CONFLICT: "来源冲突",
    UNVERIFIED: "来源未核实"
  };
  const DIAGNOSTICS = {
    WITHIN_PROPOSAL: "数值在提案范围内（非验收）",
    OVER_PROPOSAL: "数值超过提案",
    NOT_MEASURED: "未测",
    INCOMPLETE: "不完整/口径异常"
  };
  function badge(text, kind) {
    return node("span", text, "pill " + (kind || "muted"));
  }
  function paragraph(text, className) { return node("p", text, className); }
  function heading(text, level) { return node(level || "h3", text); }
  function table(columns, rows) {
    const wrap = node("div", null, "scroller");
    const grid = node("table");
    const head = node("thead");
    const tr = node("tr");
    for (const col of columns) put(tr, node("th", col));
    head.appendChild(tr);
    const body = node("tbody");
    for (const cells of rows) {
      const r = node("tr");
      for (const value of cells) {
        let cell = node("td");
        if (typeof value === "object" && value !== null && value.nodeType) {
          cell.appendChild(value);
        } else {
          cell.textContent = String(value === undefined || value === null ? "未测" : value);
        }
        r.appendChild(cell);
      }
      body.appendChild(r);
    }
    put(grid, head, body);
    wrap.appendChild(grid);
    return wrap;
  }
  function overview() {
    const all = state.reports;
    els.total.textContent = String(all.length);
    els.count.textContent = String(all.length);
    els.synthetic.textContent = String(all.filter(x => x.provenance === "SYNTHETIC").length);
    els.real.textContent = String(all.filter(x => x.provenance === "DECLARED_REAL_UNVERIFIED").length);
    els.unknown.textContent = String(all.filter(x =>
      x.provenance !== "SYNTHETIC" && x.provenance !== "DECLARED_REAL_UNVERIFIED").length);
    els.clear.disabled = all.length === 0;
    renderTraceOverview();
  }
  function renderList() {
    clear(els.list);
    const query = els.search.value.trim().toLowerCase();
    const filter = els.filter.value;
    const matching = state.reports.filter(r =>
      (filter === "ALL" || r.provenance === filter) &&
      (r.filename.toLowerCase().includes(query) ||
        r.kind.toLowerCase().includes(query) ||
        r.sourceTask.toLowerCase().includes(query))
    );
    els.listEmpty.hidden = matching.length > 0;
    if (!matching.length) els.listEmpty.textContent = state.reports.length ?
      "当前筛选没有匹配的报告。" : "暂无报告。请导入现有分析结果或报告JSON。";
    for (const item of matching) {
      const li = node("li");
      const button = node("button", null, "report-entry" +
        (item.browserId === state.selected ? " selected" : ""));
      button.type = "button";
      button.setAttribute("aria-pressed", String(item.browserId === state.selected));
      put(button,
        node("span", item.filename, "name"),
        node("span", item.kind + " · " + (ORIGINS[item.provenance] || "来源不明"), "tags")
      );
      button.addEventListener("click", () => {
        state.selected = item.browserId;
        renderList();
        renderDetail();
      });
      if (item.kind !== "series") {
        const wrapper = node("div", null, "library-line");
        const toggle = node("input");
        toggle.type = "checkbox";
        toggle.className = "multi-check";
        toggle.checked = state.multiSelected.has(item.browserId);
        toggle.setAttribute("aria-label", "勾选横向对照：" + item.filename);
        toggle.addEventListener("change", () => {
          if (toggle.checked && state.multiSelected.size >= cohort.MAX_SELECTED) {
            toggle.checked = false;
            els.status.textContent = "最多勾选12份独立单次报告；系列摘要不能直接跨文件混合比较。";
            return;
          }
          if (toggle.checked) state.multiSelected.add(item.browserId);
          else state.multiSelected.delete(item.browserId);
          rebuildMultiSelection();
        });
        put(wrapper, toggle, button);
        li.appendChild(wrapper);
      } else {
        li.appendChild(button);
      }
      els.list.appendChild(li);
    }
  }
  function renderErrors() {
    clear(els.errors);
    for (const entry of state.errors.slice(-12)) {
      els.errors.appendChild(node("li", entry));
    }
  }
  function addWarningPanel(parent, warnings, limit = 50) {
    const box = node("div", null, "warnings");
    put(box, heading("需复核或缺失", "h3"));
    const list = node("ul");
    if (!warnings.length) list.appendChild(node("li", "暂无额外格式告警；不代表已完成来源验证。"));
    for (const warning of warnings.slice(0, limit)) {
      list.appendChild(node("li", warning));
    }
    if (warnings.length > limit) {
      list.appendChild(node("li", "另有 " + (warnings.length - limit) +
        " 条未展开，请保留源JSON复核，不应视为已处理。"));
    }
    box.appendChild(list);
    parent.appendChild(box);
  }
  function addMeta(parent, report) {
    put(parent, heading("来源信息与证据语义"));
    const d = node("dl", null, "meta");
    const c = report.capture;
    const entries = [
      ["报告类型", report.kind],
      ["来源任务标识", report.sourceTask],
      ["来源分类", ORIGINS[report.provenance] || "来源未核实"],
      ["引擎版本（声明）", c.engineVersion],
      ["渲染后端（声明）", c.renderer],
      ["场景哈希（声明）", c.sceneHash],
      ["显示后端（声明）", c.displayServer],
      ["采样行数（来源）", report.sampleCount === null ? "未提供" : String(report.sampleCount)],
      ["整体场景状态", "INCOMPLETE"],
      ["采样真实性验证", "未完成"],
    ];
    for (const [k, v] of entries) {
      put(d, put(node("div"), node("dt", k), node("dd", v)));
    }
    parent.appendChild(d);
    parent.appendChild(paragraph(report.provenanceNote, "footnote"));
  }
  function statusCell(row) {
    const type = row.diagnostic === "WITHIN_PROPOSAL" ? "within" :
      row.diagnostic === "OVER_PROPOSAL" ? "over" : "missing";
    return node("span", DIAGNOSTICS[row.diagnostic] || "不完整", "state " + type);
  }
  function addSingleMetrics(parent, report) {
    put(parent, heading("观测值与暂定预算"));
    const rows = report.metrics.map(m => [
      m.name, fmt(m.observed, m.unit), fmt(m.budget, m.unit) + "（未批准）",
      statusCell(m), "来源声称：" + m.sourceStatus, m.reason
    ]);
    put(parent, table(
      ["指标", "导入的观测值", "预算提案（非实测）", "本地审阅结果", "源状态", "缺测/复核原因"],
      rows
    ));
    put(parent, paragraph("来源数值与预算比较不构成真实测试或场景通过。脚本CPU、GPU时间和VRAM不得从帧间隔或Windows进程CPU推断。", "footnote"));
  }
  function addSeriesMetrics(parent, report) {
    put(parent, heading("多次采样 · run级统计（绝不池化逐帧数据）"));
    for (const g of report.groups) {
      const box = node("div", null, "group");
      put(box, heading(g.name + " · " + (g.nRuns === null ? "未知" : g.nRuns) + " 次", "h3"));
      const rows = g.metrics.map(m => [
        m.name, fmt(m.min, m.unit), fmt(m.median, m.unit), fmt(m.max, m.unit),
        m.nObserved === null ? "未核实" : m.nObserved + "/" + m.nTotal,
        m.coverage, fmt(m.budget, m.unit) + "（提案）"
      ]);
      put(box, table(
        ["指标", "最小", "各次中位数", "最大", "覆盖", "缺测标记", "预算提案"],
        rows
      ));
      const runTable = g.runDetails.map(r => [
        r.id, r.count === null ? "未提供" : String(r.count),
        ORIGINS[r.sourceOrigin] || r.sourceOrigin, "源声明：" + r.sourceStatus,
        r.engineVersion, r.renderer, r.sceneHash
      ]);
      put(box, heading("每次采样来源与元数据（均未经核实）", "h3"),
        table(["run ID", "来源帧数", "来源声明", "子集状态（来源）",
               "引擎版本", "渲染后端", "场景哈希"], runTable));
      const missing = [];
      for (const r of g.runDetails) {
        for (const warning of r.warnings) {
          missing.push(r.id + " / 来源校验：" + warning);
        }
      }
      for (const m of g.metrics) {
        for (const item of m.missingRuns) {
          missing.push(m.name + " / " + item.id + "：" + item.reason + " [" + item.status + "]");
        }
      }
      if (missing.length) addWarningPanel(box, missing, 240);
      parent.appendChild(box);
    }
    if (Array.isArray(report.missingByRun)) {
      const details = [];
      for (const run of report.missingByRun) {
        for (const missing of run.missing) {
          details.push(run.group + " / " + run.id + " / " + missing.metric +
            "：" + missing.reason + " [" + missing.status + "]");
        }
      }
      if (details.length) addWarningPanel(parent, details);
    }
    put(parent, paragraph("本浏览器仅展示各次独立统计结果。多份P99的中位数不是合并帧P99；不据此认定性能优化。", "footnote"));
  }
  function addMissingExplanation(parent, report) {
    put(parent, heading("缺测与口径说明（不以0代替）"));
    const reasons = [];
    if (report.kind !== "series") {
      for (const m of report.metrics) {
        if (m.diagnostic === "NOT_MEASURED" || m.diagnostic === "INCOMPLETE") {
          reasons.push([m.name, m.diagnostic === "NOT_MEASURED" ? "未测" : "输入不完整/不可采信",
            m.reason || "来源无有效值，不能推断为0"]);
        }
      }
    } else {
      for (const group of report.groups) {
        for (const m of group.metrics) {
          if (m.coverage !== "COMPLETE_NUMERIC") {
            reasons.push([group.name + " / " + m.name,
              m.nObserved === null ? "覆盖不可信" : m.nObserved + "/" + m.nTotal,
              "每次run缺失详情见上方；仅对已有独立数值做描述性统计"]);
          }
        }
      }
    }
    if (reasons.length) {
      put(parent, paragraph("以下是缺测或异常字段；即使有其他观测值，整体场景也不能判通过。", "footnote"),
        table(["字段", "缺测状态/有效数", "原因与限制"], reasons));
    } else {
      put(parent, paragraph("八项统计字段的来源数值齐全，但仍缺少真实性与场景整体指标验证；不代表实测通过。", "footnote"));
    }
    const boundaries = [
      "帧间隔是帧事件之间的墙钟时间，不等于游戏脚本CPU时间或GPU耗时",
      "进程工作集含共享内存、私有提交不是驻留RAM；两者不能自动替代逐帧RAM",
      "VRAM增量未可靠采集时保持缺测，不能猜测为0",
      "headless/dummy不构成GPU跑分；声明非合成也不是独立验真",
      "冷启动、切换、灯光和NPC等未测项目仍须单独验收"
    ];
    put(parent, paragraph(boundaries.join("；"), "footnote"));
  }

  function addMemory(parent, m) {
    if (!m) return;
    put(parent, heading("单列展示：Windows进程级内存"));
    put(parent, table(["指标", "观测峰值", "范围声明"], [
      ["工作集", fmt(m.workingSet, "GiB"), "包含共享页，非专有RAM"],
      ["私有提交", fmt(m.privateCommit, "GiB"), "不是驻留物理RAM"],
      ["证据质量", m.quality, "未关联逐帧采样时间和来源哈希"]
    ]));
    put(parent, paragraph(m.note, "footnote"));
  }
  function renderTraceOverview() {
    clear(els.traceOverview);
    if (!trace || !state.reports.length) {
      els.traceOverview.appendChild(paragraph(
        trace ? "当前会话未导入报告，暂无来源与缺测统计。" : "来源分类模块未加载，无法追踪证据。",
        "empty"));
      return;
    }
    const summary = trace.traceSelection(state.reports);
    const rows = Object.entries(summary.byCategory).map(([name, count]) => [
      name, trace.DESCRIPTIONS[name] || "待复核", String(count)
    ]);
    put(els.traceOverview, paragraph(
      "报告总数 " + summary.count + "；以下统计是报告内字段缺口和未核实声明的数量，不是已测性能值。",
      "footnote"), table(["分类", "含义", "发现次数"], rows),
      paragraph(summary.warning, "footnote"));
  }
  function renderTraceDetails(report) {
    clear(els.traceDetails);
    if (!report || !trace) {
      els.traceDetails.appendChild(paragraph(
        "从左侧选择一份报告以展开来源链路与缺测类别。", "empty"));
      return;
    }
    const evidence = trace.traceReport(report);
    const meta = evidence.report;
    put(els.traceDetails, heading("所选报告的来源声明", "h3"),
      table(["字段", "报告内声明（均未验真）"], [
        ["报告", meta.fileLabel],
        ["类型/来源任务", meta.kind + " / " + meta.reportTaskId],
        ["来源类别", meta.sourceClass],
        ["引擎/渲染后端", meta.declaredEngine + " / " + meta.declaredRenderer],
        ["显示服务", meta.declaredDisplay],
        ["场景哈希（未独立核对）", meta.declaredSceneSha256],
        ["原始CSV哈希/进程身份/独立重复采样", "均未得到可靠绑定"]
      ]));
    put(els.traceDetails, heading("证据链阶段", "h3"),
      table(["阶段", "可核实状态", "保守解释"], evidence.chain.map(x => [
        x.stage, x.state, x.explanation
      ])));
    const gaps = evidence.classifiedMissing.map(x => [
      x.group, x.label, x.category,
      x.available === null || x.total === null ? "未提供" : x.available + "/" + x.total,
      x.details.length ? x.details.map(d =>
        d.id + "：" + d.reason + " [" + d.status + "]").join("；") : x.explanation
    ]);
    put(els.traceDetails, heading("逐指标缺测分类", "h3"));
    if (gaps.length) {
      put(els.traceDetails, table(["组", "指标", "类别", "有效覆盖", "原因与对应run"], gaps));
    } else {
      put(els.traceDetails, paragraph(
        "八项报告数值可能齐全，但来源真实性、全场景性能及未测参数仍未通过验证。", "footnote"));
    }
    const extra = evidence.contextIssues.map(x => [x.category, x.explanation]);
    put(els.traceDetails, heading("来源及场景范围的缺口", "h3"),
      table(["类别", "未核实或待测说明"], [
        ...extra,
        ...evidence.outOfScope.map(x => [x.category, x.label + "：未独立采集或验证"])
      ]));
    put(els.traceDetails, paragraph(
      "本模块没有读取原始CSV、验证其哈希、检查Godot真实进程或GPU指标。声明≠实测核验；完整场景始终INCOMPLETE。",
      "footnote"));
  }
  function renderDetail() {
    clear(els.detail);
    const report = state.reports.find(x => x.browserId === state.selected);
    renderTraceDetails(report);
    if (!report) {
      els.detail.appendChild(paragraph("从左侧选择一份已导入报告，查看指标、来源与缺测信息。", "empty big"));
      return;
    }
    const title = node("div", null, "detail-head");
    put(title, put(node("div"), heading(report.filename, "h3"),
      paragraph(report.kind + " · 来源：" + report.sourceTask, "detail-kind")),
      badge(ORIGINS[report.provenance] || "未核实",
        report.provenance === "SYNTHETIC" ? "synthetic" :
        report.provenance === "DECLARED_REAL_UNVERIFIED" ? "claim" : "warning"));
    els.detail.appendChild(title);
    els.detail.appendChild(paragraph(
      "整体 INCOMPLETE · full_scene_pass=false · 预算未批准 · 真实性尚未独立核对",
      "summary"));
    addMeta(els.detail, report);
    if (report.kind === "series") addSeriesMetrics(els.detail, report);
    else addSingleMetrics(els.detail, report);
    addMissingExplanation(els.detail, report);
    addMemory(els.detail, report.processMemory);
    addWarningPanel(els.detail, report.warnings);
    put(els.detail, paragraph(
      "整场景仍缺测（没有通过依据）：" + report.missingScene.join("、"), "footnote"));
  }
  function selectOption(value, name) {
    const opt = node("option", name);
    opt.value = value;
    return opt;
  }
  function rebuildComparators() {
    const oldA = els.baseline.value, oldB = els.current.value;
    const eligible = state.reports.filter(x => x.kind !== "series");
    clear(els.baseline);
    clear(els.current);
    els.baseline.appendChild(selectOption("", "选择基线报告"));
    els.current.appendChild(selectOption("", "选择本次报告"));
    for (const r of eligible) {
      const display = r.filename + " (" + r.kind + ")";
      els.baseline.appendChild(selectOption(String(r.browserId), display));
      els.current.appendChild(selectOption(String(r.browserId), display));
    }
    els.baseline.value = eligible.some(r => String(r.browserId) === oldA) ? oldA : "";
    els.current.value = eligible.some(r => String(r.browserId) === oldB) ? oldB : "";
    els.compare.disabled = eligible.length < 2;
  }
  function compareClicked() {
    clear(els.result);
    const a = state.reports.find(x => String(x.browserId) === els.baseline.value);
    const b = state.reports.find(x => String(x.browserId) === els.current.value);
    if (!a || !b || a.browserId === b.browserId) {
      els.result.appendChild(paragraph("请选择两份不同的单次/分析器报告。", "empty"));
      return;
    }
    const result = model.compare(a, b);
    put(els.result, paragraph(
      "对照状态：" + result.context + "。 " + result.note +
      "。只能表示数值差异，不构成真实性或性能改善判定。", "summary"));
    if (!result.rows.length) return;
    const rows = result.rows.map(r => [
      r.name, fmt(r.baseline, r.unit), fmt(r.current, r.unit),
      fmt(r.delta, r.unit), fmt(r.deltaPercent, "%"), r.status
    ]);
    els.result.appendChild(table(
      ["指标", "基线观测", "本次观测", "差值", "变化率", "比较状态"], rows));
  }
  function multiSelection() {
    return state.reports.filter(r => state.multiSelected.has(r.browserId) && r.kind !== "series");
  }
  function rebuildMultiSelection() {
    const selection = multiSelection();
    const previous = els.multiBaseline.value;
    clear(els.multiBaseline);
    els.multiBaseline.appendChild(selectOption("", "选择勾选项作为基准"));
    for (const report of selection) {
      els.multiBaseline.appendChild(selectOption(String(report.browserId), report.filename));
    }
    els.multiBaseline.value = selection.some(r => String(r.browserId) === previous) ? previous :
      selection.length ? String(selection[0].browserId) : "";
    els.multiCount.textContent = String(selection.length) + "/" + cohort.MAX_SELECTED;
    els.multiCompare.disabled = selection.length < 2 || selection.length > cohort.MAX_SELECTED;
    els.multiClear.disabled = selection.length === 0;
    clear(els.multiResult);
    els.multiResult.appendChild(paragraph("已勾选" + selection.length +
      "份；选择基准后点击比较。对照仅用于展示各报告声明的数值，不是已核实性能。",
      "empty"));
  }
  function resetMultiSelection() {
    state.multiSelected.clear();
    rebuildMultiSelection();
    renderList();
  }
  function renderMultiClicked() {
    clear(els.multiResult);
    const selected = multiSelection();
    try {
      const result = cohort.compareMany(selected, Number(els.multiBaseline.value));
      const c = result.context;
      const selectedTrace = trace.traceSelection(selected);
      put(els.multiResult,
        paragraph("对照状态：" + c.status + "；" + c.note, "summary"),
        paragraph(c.evidenceNote + "。完整场景保持 INCOMPLETE，原始证据未独立校验。",
          "footnote"),
        paragraph("覆盖统计：" + (result.missingOverview.totalMetricCells -
          result.missingOverview.untrustedOrMissing) + "/" +
          result.missingOverview.totalMetricCells +
          " 个数字字段具备报告内可对照状态；这不等于有这么多项真实实测。", "footnote"));
      put(els.multiResult, heading("本次选中报告的缺测分类概览", "h3"),
        table(["类别", "解释", "发现数"],
          Object.entries(selectedTrace.byCategory).map(([name, value]) =>
            [name, trace.DESCRIPTIONS[name] || "待复核", String(value)])));
      const sourceRows = result.records.map(item => [
        item.id === result.baselineId ? item.name + "（基准）" : item.name,
        ORIGINS[item.provenance] || item.provenance,
        item.sampleCount === null ? "未提供" : String(item.sampleCount),
        item.engineVersion, item.renderer, item.sceneHash,
        "警告 " + item.warningCount + " 条"
      ]);
      put(els.multiResult, heading("各份报告的来源声明", "h3"),
        table(["名称", "来源类别", "来源帧数", "引擎", "后端", "场景哈希", "告警"], sourceRows));
      put(els.multiResult, paragraph("横向表中每个单元格显示“原文件数值／相对基准的数值变化”。" +
        "没有通过来源检验时显示“不可比较”，绝不以预算值填补。", "footnote"));
      const columns = ["指标", ...result.records.map(r => r.name),
        "有效数/总数", "各报告中位数", "提案预算", "覆盖状态"];
      const rows = result.rows.map(row => [
        row.name,
        ...row.cells.map(cell => {
          const value = fmt(cell.reported, row.unit);
          if (!cell.canUse) return value + "（不可采信）";
          return value + (cell.delta === null ? " · 不可比较" :
            " · Δ" + fmt(cell.delta, row.unit));
        }),
        row.nReportedUsable + "/" + row.total,
        fmt(row.median, row.unit), fmt(row.budget, row.unit) + "（未批准）",
        row.coverage
      ]);
      put(els.multiResult, heading("多份观测逐指标对照", "h3"), table(columns, rows));
      const missing = [];
      for (const record of result.missingOverview.missingByRecord) {
        for (const item of record.items) {
          missing.push(record.filename + " / " + item.label + "：" +
            item.reason + " [" + item.diagnostic + "]");
        }
      }
      if (missing.length) addWarningPanel(els.multiResult, missing, 110);
      else put(els.multiResult, paragraph("报告字段均可作数值对照，但仍无法证明真实运行条件一致。", "footnote"));
      put(els.multiResult, paragraph("每份报告均只保留自己的帧分位数；跨次中位数不是合并帧P50/P95/P99。",
        "footnote"));
    } catch (err) {
      els.multiResult.appendChild(paragraph("无法比较：" +
        (err && err.message ? String(err.message).slice(0, 180) : "输入缺失或非法"),
        "empty"));
    }
  }

  async function importFiles(files) {
    if (!model || !cohort || !trace) {
      els.status.textContent = "依赖模块未加载完整，拒绝导入和任何伪数据显示。";
      return;
    }
    if (state.busy) {
      els.status.textContent = "上一批本地文件仍在读取，请勿并行导入以免混淆证据。";
      return;
    }
    const selected = Array.from(files || []);
    if (!selected.length) return;
    if (selected.length + state.reports.length > model.MAX_FILES) {
      els.status.textContent = "超过最多40份报告的限制；本次未导入。";
      return;
    }
    state.busy = true;
    let added = 0;
    try {
    for (const f of selected) {
      const safeName = typeof f.name === "string" ? f.name.slice(0, 100) : "未命名文件";
      if (!f || typeof f.size !== "number" || f.size > model.MAX_FILE_BYTES) {
        state.errors.push(safeName + "：超过2 MB限制或不是有效文件");
        continue;
      }
      if (!safeName.toLowerCase().endsWith(".json")) {
        state.errors.push(safeName + "：只接受 .json");
        continue;
      }
      // Collision-resistant identity is NOT proven here: this is only a UX
      // guard against accidental repeat-selection of the same local file.
      const signature = safeName + "|" + String(f.size) + "|" + String(f.lastModified);
      if (state.seenFiles.has(signature)) {
        state.errors.push(safeName + "：疑似重复选择（文件名/大小/修改时间相同），未再次计数");
        continue;
      }
      try {
        const text = await f.text();
        if (text.length > model.MAX_FILE_BYTES) throw new Error("解码后超出字符上限");
        const record = model.normalize(safeName, text);
        record.browserId = ++state.sequence;
        state.reports.push(record);
        state.seenFiles.add(signature);
        if (state.selected === null) state.selected = record.browserId;
        added += 1;
      } catch (err) {
        state.errors.push(safeName + "：" + (err && err.message ? String(err.message).slice(0, 180) : "读取失败"));
      }
    }
    } finally {
      state.busy = false;
    }
    els.status.textContent = "已导入 " + added + " 份；错误 " + Math.min(state.errors.length, 12) + " 条（仅当前会话）。";
    overview();
    renderErrors();
    renderList();
    rebuildComparators();
    rebuildMultiSelection();
    renderDetail();
  }
  function reset() {
    if (state.busy) {
      els.status.textContent = "本地文件读取尚未结束；本次暂不清空。";
      return;
    }
    state.reports = []; state.selected = null; state.errors = [];
    state.multiSelected.clear(); state.seenFiles.clear();
    els.files.value = "";
    els.baseline.value = ""; els.current.value = "";
    clear(els.result);
    els.result.appendChild(paragraph("导入两份报告后选择基线与本次。", "empty"));
    els.status.textContent = "已清空当前会话的报告引用。";
    overview(); renderErrors(); renderList(); rebuildComparators(); rebuildMultiSelection(); renderDetail();
  }
  els.files.addEventListener("change", async e => {
    await importFiles(e.currentTarget.files);
    e.currentTarget.value = "";
  });
  els.drop.addEventListener("dragover", e => {
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
    els.drop.classList.add("over");
  });
  els.drop.addEventListener("dragleave", () => els.drop.classList.remove("over"));
  els.drop.addEventListener("drop", async e => {
    e.preventDefault();
    els.drop.classList.remove("over");
    if (e.dataTransfer && e.dataTransfer.files) await importFiles(e.dataTransfer.files);
  });
  els.drop.addEventListener("keydown", e => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      els.files.click();
    }
  });
  els.search.addEventListener("input", renderList);
  els.filter.addEventListener("change", renderList);
  els.clear.addEventListener("click", reset);
  els.compare.addEventListener("click", compareClicked);
  els.multiCompare.addEventListener("click", renderMultiClicked);
  els.multiClear.addEventListener("click", resetMultiSelection);
  if (!model || !cohort || !trace) {
    els.status.textContent = "依赖模块未全部载入；拒绝解析报告或展示伪结果。";
    els.files.disabled = true;
  } else {
    overview(); rebuildComparators(); rebuildMultiSelection(); renderList();
  }
})();

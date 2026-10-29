/* GAME-WEB-FLOW-PERF-004/r1 — local File API, read-only evidence browser.
 * No fetch, XHR, storage, service worker, telemetry, eval or remote assets.
 * Candidate is NOT_RUN and must not be described as tested.
 */
(function () {
  "use strict";

  const model = window.PerfEvidenceModel;
  const byId = id => document.getElementById(id);
  const state = { reports: [], selected: null, sequence: 0, errors: [] };
  const els = {
    files: byId("files"), drop: byId("drop"), count: byId("count"),
    total: byId("total"), synthetic: byId("synthetic-count"),
    real: byId("real-count"), unknown: byId("unknown-count"),
    search: byId("search"), filter: byId("filter"),
    list: byId("report-list"), listEmpty: byId("list-empty"),
    status: byId("import-status"), errors: byId("errors"),
    clear: byId("clear"), detail: byId("detail"),
    baseline: byId("baseline"), current: byId("current"),
    compare: byId("compare"), result: byId("compare-result")
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
      li.appendChild(button);
      els.list.appendChild(li);
    }
  }
  function renderErrors() {
    clear(els.errors);
    for (const entry of state.errors.slice(-12)) {
      els.errors.appendChild(node("li", entry));
    }
  }
  function addWarningPanel(parent, warnings) {
    const box = node("div", null, "warnings");
    put(box, heading("需复核或缺失", "h3"));
    const list = node("ul");
    if (!warnings.length) list.appendChild(node("li", "暂无额外格式告警；不代表已完成来源验证。"));
    for (const warning of warnings.slice(0, 50)) {
      list.appendChild(node("li", warning));
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
      if (missing.length) addWarningPanel(box, missing);
      parent.appendChild(box);
    }
    put(parent, paragraph("本浏览器仅展示各次独立统计结果。多份P99的中位数不是合并帧P99；不据此认定性能优化。", "footnote"));
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
  function renderDetail() {
    clear(els.detail);
    const report = state.reports.find(x => x.browserId === state.selected);
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
  async function importFiles(files) {
    const selected = Array.from(files || []);
    if (!selected.length) return;
    if (selected.length + state.reports.length > model.MAX_FILES) {
      els.status.textContent = "超过最多40份报告的限制；本次未导入。";
      return;
    }
    let added = 0;
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
      try {
        const text = await f.text();
        if (text.length > model.MAX_FILE_BYTES) throw new Error("解码后超出字符上限");
        const record = model.normalize(safeName, text);
        record.browserId = ++state.sequence;
        state.reports.push(record);
        if (state.selected === null) state.selected = record.browserId;
        added += 1;
      } catch (err) {
        state.errors.push(safeName + "：" + (err && err.message ? String(err.message).slice(0, 180) : "读取失败"));
      }
    }
    els.status.textContent = "已导入 " + added + " 份；错误 " + Math.min(state.errors.length, 12) + " 条（仅当前会话）。";
    overview();
    renderErrors();
    renderList();
    rebuildComparators();
    renderDetail();
  }
  function reset() {
    state.reports = []; state.selected = null; state.errors = [];
    els.files.value = "";
    els.baseline.value = ""; els.current.value = "";
    clear(els.result);
    els.result.appendChild(paragraph("导入两份报告后选择基线与本次。", "empty"));
    els.status.textContent = "已清空当前会话的报告引用。";
    overview(); renderErrors(); renderList(); rebuildComparators(); renderDetail();
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
  if (!model) {
    els.status.textContent = "模型模块未载入；无法解析报告（不得展示伪结果）。";
    els.files.disabled = true;
  } else {
    overview(); rebuildComparators(); renderList();
  }
})();

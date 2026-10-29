#!/usr/bin/env python3
"""GAME-WEB-CONTINUE-PERF-003/r1: multi-run offline report candidate.

Read-only manifest → bounded PERF-002 JSON inputs → per-run descriptive summary.
Never pool per-run nearest-rank percentiles into a false whole-frame percentile.
The input reporter must pass build_report/read_object; no imports from this module
execute sampling, renderers or process monitoring. NOT_RUN, no approved interface.
"""
from __future__ import annotations

from datetime import datetime, timezone
from html import escape
import math
from pathlib import Path, PurePosixPath
import re

SCHEMA = "perf-report-series-v1"
MAX_GROUP_RUNS = 12
MAX_TOTAL_RUNS = 24
ID = re.compile(r"[A-Za-z0-9_-]{1,32}\Z", re.ASCII)
VALID = frozenset(("PASS", "FAIL"))
MAX_RELATIVE_LENGTH = 240


def _finite(value):
    """Accept only finite numbers, not booleans or missing measurements."""
    if type(value) not in (int, float):
        return None
    try:
        if math.isfinite(value) and value >= 0:
            return value
    except (OverflowError, TypeError, ValueError):
        pass
    return None


def _safe_signed(value):
    if type(value) not in (int, float):
        return None
    try:
        if math.isfinite(value):
            return value
    except (OverflowError, TypeError, ValueError):
        pass
    return None


def _median(values):
    """Median of *run-level* observations, not pooled frame samples."""
    seq = sorted(values)
    if not seq:
        return None
    mid = len(seq) // 2
    if len(seq) % 2:
        return seq[mid]
    return seq[mid - 1] / 2.0 + seq[mid] / 2.0


def _relative_file(base, value, used, role):
    """Manifest-local POSIX paths; never network URLs, absolute or parent escapes."""
    if not isinstance(value, str) or not 1 <= len(value) <= MAX_RELATIVE_LENGTH:
        raise ValueError(role + ": nonempty relative path required")
    if "\\" in value or ":" in value or "\0" in value or value.startswith(("/", "~")):
        raise ValueError(role + ": only relative POSIX paths accepted")
    posix = PurePosixPath(value)
    if any(part in ("..", ".") for part in value.split("/")) or posix.is_absolute():
        raise ValueError(role + ": parent and absolute paths forbidden")
    path = (base / Path(*posix.parts)).resolve(strict=True)
    if not path.is_relative_to(base):
        raise ValueError(role + ": resolves outside manifest directory")
    if not path.is_file():
        raise ValueError(role + ": expected a regular JSON file")
    if path in used:
        raise ValueError(role + ": duplicate input file across runs")
    used.add(path)
    return path


def _group_metrics(runs, template):
    result = []
    for original in template["metrics"]:
        key = original["key"]
        observed = []
        missing = []
        counts = {"PASS": 0, "FAIL": 0, "INCOMPLETE": 0, "NOT_MEASURED": 0}
        for run in runs:
            item = run["measurements"][key]
            status = item["status"]
            counts[status] = counts.get(status, 0) + 1
            value = _finite(item["value"])
            if status in VALID and value is not None:
                observed.append(value)
            else:
                missing.append({
                    "run_id": run["id"],
                    "status": status,
                    "reason": item["reason"],
                })
        count = len(observed)
        coverage = (
            "NOT_MEASURED" if count == 0 else
            "COMPLETE_NUMERIC" if count == len(runs) else
            "PARTIAL"
        )
        result.append({
            "key": key,
            "label": original["label"],
            "unit": original["unit"],
            "budget": original["budget"],
            "budget_status": "UNAPPROVED_PROPOSAL",
            "n_total": len(runs),
            "n_observed": count,
            "n_missing": len(missing),
            "min": min(observed) if observed else None,
            "median": _median(observed),
            "max": max(observed) if observed else None,
            "coverage": coverage,
            "statuses": counts,
            "missing_runs": missing,
            "aggregation": "unweighted median of run-level statistics; not a pooled percentile",
        })
    return result


def _snapshot(run_id, report):
    items = {}
    for item in report["metrics"]:
        good = item["status"] in VALID and _finite(item["observed"]) is not None
        items[item["key"]] = {
            "value": _finite(item["observed"]) if good else None,
            "status": item["status"],
            "reason": "" if good else item["note"],
        }
    return {
        "id": run_id,
        "sample_count": report["sample_count"],
        "analyzer_subset_status": report["measured_subset_status"],
        "source_origin": report["capture"]["origin"],
        "capture": report["capture"],
        "warnings": report["warnings"],
        "measurements": items,
        "whole_scene_status": "INCOMPLETE",
        "full_scene_pass": False,
    }


def read_series_manifest(path, read_object, build_report):
    """Read only explicitly named local files. Never copy input paths into report."""
    manifest_path = Path(path).resolve(strict=True)
    base = manifest_path.parent
    manifest = read_object(manifest_path)
    if set(manifest) != {"schema", "groups"} or manifest.get("schema") != SCHEMA:
        raise ValueError("Unsupported or malformed series manifest")
    groups = manifest.get("groups")
    if not isinstance(groups, list) or len(groups) not in (1, 2):
        raise ValueError("Series requires one or two groups")
    names = [group.get("name") if isinstance(group, dict) else None for group in groups]
    if names not in (["current"], ["baseline", "current"]):
        raise ValueError("Group names must be current or baseline,current in order")
    used_files, used_ids, collected, total = set(), set(), [], 0
    for group in groups:
        if set(group) != {"name", "runs"}:
            raise ValueError("Unexpected group fields")
        rows = group["runs"]
        if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_GROUP_RUNS:
            raise ValueError("Each group requires 1..12 runs")
        total += len(rows)
        if total > MAX_TOTAL_RUNS:
            raise ValueError("Maximum 24 runs exceeded")
        run_reports = []
        for row in rows:
            if not isinstance(row, dict) or not {"id", "analysis"} <= set(row):
                raise ValueError("Each run requires an ID and analysis")
            if set(row) - {"id", "analysis", "capture"}:
                raise ValueError("Unexpected run fields")
            run_id = row["id"]
            if not isinstance(run_id, str) or not ID.fullmatch(run_id):
                raise ValueError("Run ID must be ASCII alphanumeric, underscore or hyphen (max 32)")
            if run_id in used_ids:
                raise ValueError("Duplicate run ID")
            used_ids.add(run_id)
            analysis_path = _relative_file(base, row["analysis"], used_files, "analysis")
            analysis = read_object(analysis_path)
            capture = None
            if "capture" in row:
                capture_path = _relative_file(base, row["capture"], used_files, "capture")
                capture = read_object(capture_path)
            report = build_report(analysis, capture=capture)
            run_reports.append(_snapshot(run_id, report))
        if len(groups) == 1 and len(run_reports) < 2:
            raise ValueError("A single group needs at least two runs")
        collected.append({
            "name": group["name"],
            "runs": run_reports,
        })
    return collected


def _context(groups):
    """Check reported context conflicts; absence never establishes equivalence."""
    fields = ("engine_version", "renderer", "scene_sha256")
    conflicts = []
    missing = []
    for field in fields:
        values = [run["capture"].get(field) for group in groups for run in group["runs"]]
        known = [value for value in values if value not in (None, "", "未提供")]
        if len(set(known)) > 1:
            conflicts.append(field)
        if len(known) != len(values):
            missing.append(field)
    origins = {run["source_origin"] for group in groups for run in group["runs"]}
    if len(origins) > 1 and "SYNTHETIC" in origins:
        conflicts.append("synthetic_vs_other_origin")
    if conflicts:
        return "CONFLICT", "采样声明不一致：" + ", ".join(conflicts)
    reason = "未独立验证设备、分辨率、帧原始数据及场景哈希绑定"
    if missing:
        reason += "；缺失元数据：" + ", ".join(missing)
    return "UNVERIFIED", reason


def _group_comparison(groups):
    if len(groups) != 2:
        return None
    baseline, current = groups
    context, note = _context(groups)
    prior = {m["key"]: m for m in baseline["metrics"]}
    rows = []
    for this in current["metrics"]:
        old = prior[this["key"]]
        complete = (
            context != "CONFLICT"
            and old["coverage"] == "COMPLETE_NUMERIC"
            and this["coverage"] == "COMPLETE_NUMERIC"
            and old["budget"] == this["budget"]
        )
        a, b = old["median"], this["median"]
        delta = _safe_signed(b - a) if complete and a is not None and b is not None else None
        percent = _safe_signed((delta / a) * 100.0) if delta is not None and a else None
        rows.append({
            "key": this["key"], "label": this["label"], "unit": this["unit"],
            "baseline_median": a,
            "current_median": b,
            "delta_median": delta,
            "delta_percent": percent,
            "status": "NUMERIC_ONLY" if delta is not None else "NOT_COMPARABLE",
        })
    return {
        "status": "DESCRIPTIVE_ONLY",
        "context_status": context,
        "context_note": note,
        "comparison_is_verified_benchmark": False,
        "rows": rows,
        "note": "delta uses group medians, not paired-frame differences; no improvement verdict",
    }


def build_series_summary(groups, task_id="GAME-WEB-CONTINUE-PERF-003"):
    """Pure analysis of independently normalized run reports; all status unapproved."""
    if not isinstance(groups, list) or not groups:
        raise ValueError("No groups")
    if any(not isinstance(group, dict) or not group.get("runs") for group in groups):
        raise ValueError("Missing run group")
    output_groups = []
    for group in groups:
        template_run = group["runs"][0]
        # Fixed ordering/labels/budgets from the reporter, never input manifest.
        from perf_report_candidate import BUDGETS
        template = {"metrics": [
            {"key": key, "label": label, "unit": unit, "budget": limit}
            for key, label, unit, limit in BUDGETS
        ]}
        output_groups.append({
            "name": group["name"],
            "n_runs": len(group["runs"]),
            "runs": group["runs"],
            "metrics": _group_metrics(group["runs"], template),
        })
    comparison = _group_comparison(output_groups)
    missing_run_details = [
        {
            "group": group["name"],
            "id": run["id"],
            "missing": [
                {"metric": key, "status": item["status"], "reason": item["reason"]}
                for key, item in run["measurements"].items()
                if item["status"] not in VALID or item["value"] is None
            ],
        }
        for group in output_groups for run in group["runs"]
    ]
    return {
        "task_id": task_id,
        "version": "r1",
        "schema": "perf-series-report-v1",
        "input_version": "PERF-002/r1 + PR#12 report candidate",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "status": "INCOMPLETE",
        "whole_scene_status": "INCOMPLETE",
        "full_scene_pass": False,
        "budget_approval": "UNAPPROVED_PROPOSAL",
        "test_status": "NOT_RUN",
        "mode": "MULTI_RUN_OFFLINE_DESCRIPTIVE",
        "numeric_method": "unweighted min/median/max of independent run-level metrics",
        "frame_percentiles_pooled": False,
        "has_verified_real_game_benchmark": False,
        "groups": output_groups,
        "group_comparison": comparison,
        "missing_run_details": missing_run_details,
        "unmeasured_whole_scene": [
            "cold_load_s", "scene_switch_s", "dynamic_lights_peak",
            "shadow_lights_peak", "active_npcs_peak",
        ],
        "limitations": [
            "Source capture metadata are declarations, not verified provenance",
            "A PASS/FAIL from an individual analyzer is only a provisional budget comparison",
            "Partial groups are shown with coverage and omitted from cross-group deltas",
            "Windows process working set/private commit are not the per-frame ram_gib",
            "Script CPU, GPU time and VRAM cannot be inferred from frame interval",
            "No scene, novel, save, game code or shared interface is approved",
        ],
    }


def html_series_report(summary):
    """Stand-alone static HTML; escaped inputs; no scripts, fonts or external links."""
    def e(value):
        return escape(str(value), quote=True)

    def num(value, unit=""):
        return "未测" if value is None else f"{value:g}" + ((" " + unit) if unit else "")

    pages = []
    for group in summary["groups"]:
        metrics = "".join(
            "<tr><td>" + e(row["label"]) + "</td><td>" +
            e(str(row["n_observed"])) + "/" + e(str(row["n_total"])) + "</td><td>" +
            e(num(row["min"], row["unit"])) + "</td><td>" +
            e(num(row["median"], row["unit"])) + "</td><td>" +
            e(num(row["max"], row["unit"])) + "</td><td>" +
            e(num(row["budget"], row["unit"])) + "（提案）</td><td>" +
            e(row["coverage"]) + "</td></tr>"
            for row in group["metrics"]
        )
        run_rows = "".join(
            "<tr><td>" + e(run["id"]) + "</td><td>" +
            e(num(run["sample_count"])) + "</td><td>" +
            e(run["analyzer_subset_status"]) + "</td><td>" +
            e(run["source_origin"]) + "</td><td>" +
            e(str(len(run["warnings"]))) + "</td></tr>"
            for run in group["runs"]
        )
        pages.append(
            "<section><h2>" + e(group["name"]) + " · " +
            e(str(group["n_runs"])) + " 次采样</h2>" +
            "<p>指标按每次采样独立统计量再作min/median/max，绝不拼接帧数据。</p>"
            "<div class='scroll'><table><thead><tr><th>指标</th><th>有数值/总次数</th>"
            "<th>最小</th><th>各次中位数</th><th>最大</th><th>预算</th><th>覆盖</th>"
            "</tr></thead><tbody>" + metrics + "</tbody></table></div>"
            "<h3>每次采样来源</h3><div class='scroll'><table><thead>"
            "<tr><th>ID</th><th>原始帧数</th><th>分析器子集状态</th><th>来源声明</th><th>需复核提示数</th>"
            "</tr></thead><tbody>" + run_rows + "</tbody></table></div></section>"
        )
    comparison = summary.get("group_comparison")
    if comparison is not None:
        rows = "".join(
            "<tr><td>" + e(m["label"]) + "</td><td>" +
            e(num(m["baseline_median"], m["unit"])) + "</td><td>" +
            e(num(m["current_median"], m["unit"])) + "</td><td>" +
            e(num(m["delta_median"], m["unit"])) + "</td><td>" +
            e(num(m["delta_percent"], "%")) + "</td><td>" +
            e(m["status"]) + "</td></tr>"
            for m in comparison["rows"]
        )
        pages.append(
            "<section><h2>基线组 vs 本次组：描述性数值差异</h2>"
            "<p>每组先求各次指标的中位数，差值＝本次组中位数－基线组中位数。"
            "无完整覆盖或元数据冲突时不计算差值；下降不代表性能改善。</p>"
            "<p>上下文：" + e(comparison["context_status"]) + "；" +
            e(comparison["context_note"]) + "</p>"
            "<div class='scroll'><table><thead><tr><th>指标</th><th>基线中位数</th>"
            "<th>本次中位数</th><th>差值</th><th>比例</th><th>比较状态</th></tr>"
            "</thead><tbody>" + rows + "</tbody></table></div></section>"
        )
    missing = []
    for run in summary["missing_run_details"]:
        if not run["missing"]:
            continue
        cells = "; ".join(
            item["metric"] + " [" + item["status"] + "]：" + item["reason"]
            for item in run["missing"]
        )
        missing.append(
            "<li>" + e(run["group"]) + " / " + e(run["id"]) + "：" +
            e(cells) + "</li>"
        )
    if not missing:
        missing = ["<li>八项指标的可读取覆盖完整；仍不能证明真实来源或整个场景通过。</li>"]
    pages.append(
        "<section><h2>逐次缺测与异常说明</h2><ul>" +
        "".join(missing) + "</ul><p>另有冷启动、场景切换、动态灯、阴影灯、NPC等整场景指标未测。</p>"
        "<p>合成采样、OpenGL/headless/dummy、Windows进程内存与GPU真实跑分不能混同。</p>"
        "</section>"
    )
    return (
        '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; '
        'style-src \'unsafe-inline\'; base-uri \'none\'; form-action \'none\'">'
        '<title>多次性能采样｜离线报告候选</title><style>'
        'body{margin:0;padding:24px 16px;background:#f4f7fb;color:#18304d;'
        'font:15px/1.6 system-ui,sans-serif}main{max-width:1100px;margin:auto}'
        'section{background:#fff;border:1px solid #dde4ed;border-radius:10px;'
        'padding:18px;margin:16px 0}.scroll{overflow:auto}table{border-collapse:collapse;'
        'width:100%;font-size:13px}td,th{padding:9px;border-bottom:1px solid #e1e8f0;'
        'text-align:left;white-space:nowrap}th{background:#eef3f9}'
        'h1{font-size:24px}h2{font-size:18px}p{margin:8px 0}small{color:#617286}'
        '</style></head><body><main><h1>多次采样对比｜候选 r1</h1>'
        '<section><h2>整体：INCOMPLETE · 未验收</h2>'
        '<p>所有阈值为未批准预算，绝非观测值。'
        '本报告是本地描述性分析，不是经过验证的游戏GPU或CPU跑分。</p>'
        '<p>统计原则：每次采样独立，未合并原始帧；相同P99指标的跨次中位数不是总P99。</p>'
        '<p>交付验证状态：NOT_RUN；共享接口与完整场景均未批准。</p></section>' +
        "".join(pages) + "</main></body></html>"
    )

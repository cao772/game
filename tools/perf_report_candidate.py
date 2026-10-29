#!/usr/bin/env python3
"""GAME-WEB-MODULE-PERF-002/r1: read-only offline report & comparison candidate.

Consumes the JSON produced by PR #2 tools/perf_analyze_candidate.py.
Optional Windows process-memory JSON and Godot capture metadata stay separate.
Produces a standalone static HTML report and a machine-readable summary.
This is a candidate reporting interface, NOT an approved shared interface.
Python standard library only. Never runs the game or changes upstream inputs.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from html import escape
import json
import math
from pathlib import Path
import sys

TASK_ID = "GAME-WEB-MODULE-PERF-002"
VERSION = "r1"
INPUT_VERSION = "GAME-WEB-PERF-002/r1 (PR #2)"
MAX_INPUT_BYTES = 2_000_000
# Exact definition currently emitted by the PR #2 offline analyzer.
ANALYZER_PERCENTILE = (
    "nearest-rank: ascending, rank=ceil(p*n), "
    "p in {0.50,0.95,0.99}; no interpolation"
)
STAT_PATHS = {
    "frame_p50_ms": ("frame_ms", "p50"),
    "frame_p95_ms": ("frame_ms", "p95"),
    "frame_p99_ms": ("frame_ms", "p99"),
    "script_p95_ms": ("script_ms", "p95"),
    "ram_peak_gib": ("ram_gib", "peak"),
    "vram_delta_peak_gib": ("vram_delta_gib", "peak"),
    "draw_calls_peak": ("draw_calls", "peak"),
    "triangles_peak": ("triangles", "peak"),
}

# All thresholds are unapproved proposal values from PERF-001/r1.
BUDGETS = (
    ("frame_p50_ms", "帧间隔 P50", "ms", 12.0),
    ("frame_p95_ms", "帧间隔 P95", "ms", 16.7),
    ("frame_p99_ms", "帧间隔 P99", "ms", 24.0),
    ("script_p95_ms", "脚本耗时 P95", "ms", 2.0),
    ("ram_peak_gib", "RAM 峰值（分析器字段）", "GiB", 1.2),
    ("vram_delta_peak_gib", "VRAM 增量峰值", "GiB", 1.0),
    ("draw_calls_peak", "Draw calls 峰值", "/帧", 200.0),
    ("triangles_peak", "三角形峰值", "/帧", 150000.0),
)
MISSING_WHOLE_SCENE = (
    ("cold_load_s", "冷启动时长", "s"),
    ("scene_switch_s", "场景切换时长", "s"),
    ("dynamic_lights_peak", "动态灯数量", "个"),
    ("shadow_lights_peak", "实时阴影灯数量", "个"),
    ("active_npcs_peak", "活跃 NPC 数量", "个"),
)


def number(value):
    """Strict nonnegative finite JSON number; bool is not a measurement."""
    if type(value) not in (int, float):
        return None
    try:
        if not math.isfinite(value) or value < 0:
            return None
    except (ValueError, OverflowError):
        return None
    return value


def short_text(value, limit=180):
    if not isinstance(value, str):
        return "未提供"
    return value[:limit] + ("…" if len(value) > limit else "")


def read_object(filename):
    """Bounded JSON parsing; reject duplicate keys and non-finite constants."""
    path = Path(filename)
    with path.open("rb") as handle:
        raw = handle.read(MAX_INPUT_BYTES + 1)
    if len(raw) > MAX_INPUT_BYTES:
        raise ValueError("JSON exceeds 2 MiB byte limit")

    def no_duplicates(pairs):
        obj = {}
        for key, value in pairs:
            if key in obj:
                raise ValueError("Duplicate JSON key: " + key[:80])
            obj[key] = value
        return obj

    def bad_constant(text):
        raise ValueError("Non-finite JSON constant: " + text)

    obj = json.loads(
        raw.decode("utf-8-sig"), parse_constant=bad_constant,
        object_pairs_hook=no_duplicates,
    )
    if not isinstance(obj, dict):
        raise ValueError("Expected a JSON object")
    return obj


def declared_origin(capture):
    """Metadata are declarations, never independently verified provenance."""
    if not isinstance(capture, dict):
        return "UNVERIFIED", "未提供场景采集元数据，不能确认真实测量来源"
    if capture.get("is_synthetic") is True:
        return "SYNTHETIC", "元数据明确声明为合成数据：不是游戏跑分"
    if capture.get("is_synthetic") is not False:
        return "UNVERIFIED", "缺少明确 is_synthetic=false 声明"
    driver = str(capture.get("rendering_driver") or "").lower()
    display = str(capture.get("display_server") or "").lower()
    if "dummy" in driver or "headless" in driver or "headless" in display:
        return "NOT_GPU_BENCHMARK", "无有效图形后端证明，不能当作 GPU 跑分"
    if capture.get("capture_complete") is not True:
        return "UNVERIFIED", "采集记录未证实完整"
    if not driver or not display:
        return "UNVERIFIED", "缺少渲染后端或显示服务标识"
    return "DECLARED_REAL_UNLINKED", "仅声明非合成采样；未经原始CSV、场景哈希及设备身份回读校验"


def build_memory(memory):
    """Show process observations separately; never insert them into frame budgets."""
    result = {
        "provided": memory is not None,
        "status": "NOT_MEASURED",
        "quality": "UNVERIFIED",
        "pid": None,
        "process_creation_filetime_100ns": None,
        "samples": None,
        "working_set_peak_observed_gib": None,
        "private_bytes_peak_observed_gib": None,
        "cpu_semantics": "进程累计CPU时间不是脚本CPU时间",
        "note": "未附进程内存观测；不得将内存猜为0",
    }
    if not isinstance(memory, dict):
        return result
    result["status"] = short_text(memory.get("status"), 40)
    samples = memory.get("samples")
    if type(samples) is int and samples > 0:
        result["samples"] = samples
    pid = memory.get("pid")
    if type(pid) is int and pid > 0:
        result["pid"] = pid
    creation = memory.get("process_creation_filetime_100ns")
    if isinstance(creation, str) and creation.isdecimal():
        result["process_creation_filetime_100ns"] = creation
    for key in ("working_set_peak_observed_gib", "private_bytes_peak_observed_gib"):
        result[key] = number(memory.get(key))
    trusted_shape = (
        memory.get("is_synthetic") is False
        and memory.get("status") == "complete"
        and memory.get("expected_exe_matched") is True
        and result["samples"] is not None
        and result["pid"] is not None
        and result["process_creation_filetime_100ns"] is not None
    )
    result["quality"] = "DECLARED_PROCESS_SAMPLE" if trusted_shape else "PARTIAL_OR_UNVERIFIED"
    result["note"] = (
        "独立PID进程观测（声明为真实）；工作集含共享页，私有提交不是驻留RAM。"
        if trusted_shape else
        "进程记录不完整或身份/来源未核实，显示值仅作参考。"
    )
    return result


def build_report(analysis, memory=None, capture=None):
    """Pure normalization; never runs analyzers, Godot, external commands or tests."""
    if not isinstance(analysis, dict):
        raise ValueError("Analyzer report must be a JSON object")
    checks = analysis.get("checks")
    checks = checks if isinstance(checks, dict) else {}
    stats = analysis.get("stats")
    stats = stats if isinstance(stats, dict) else {}
    warnings = []
    if not isinstance(analysis.get("checks"), dict):
        warnings.append("分析器缺少checks对象")
    if not isinstance(analysis.get("stats"), dict):
        warnings.append("分析器缺少stats对象")
    error_count = analysis.get("error_count")
    clean_input = type(error_count) is int and error_count == 0
    if not clean_input:
        warnings.append("分析器缺少有效 error_count=0；所有预算判定降级为不完整")
    samples = analysis.get("sample_count")
    if type(samples) is not int or samples <= 0:
        clean_input = False
        warnings.append("没有正数逐帧样本数；不接受任何PASS")
    if analysis.get("status") != "incomplete" or analysis.get("full_scene_pass") is not False:
        clean_input = False
        warnings.append("分析器整体场景状态缺失或非incomplete；不接受任何PASS")
    if analysis.get("version") != "r1":
        clean_input = False
        warnings.append("分析器版本非r1，拒绝直接比较")
    if not isinstance(analysis.get("checks"), dict) or not isinstance(analysis.get("stats"), dict):
        clean_input = False
    if analysis.get("errors") != []:
        clean_input = False
        warnings.append("分析器错误明细非空、缺失或格式异常")
    if analysis.get("task_id") != "GAME-WEB-PERF-002":
        clean_input = False
        warnings.append("不是已知 PERF-002 分析器输出：不接受PASS")
    definition = analysis.get("percentile_definition")
    correct_definition = definition == ANALYZER_PERCENTILE
    if not correct_definition:
        clean_input = False
        warnings.append("未证实最近秩分位数口径：不接受PASS")

    metrics = []
    for key, label, unit, limit in BUDGETS:
        check = checks.get(key)
        metric = {
            "key": key, "label": label, "unit": unit,
            "budget": limit, "budget_status": "PROPOSAL",
            "observed": None, "status": "NOT_MEASURED",
            "note": "分析器未提供有效数值",
        }
        if isinstance(check, dict):
            raw = number(check.get("value"))
            source_limit = number(check.get("upper_inclusive"))
            declared = check.get("status")
            path_a, path_b = STAT_PATHS[key]
            group = stats.get(path_a)
            stat_raw = number(group.get(path_b)) if isinstance(group, dict) else None
            if raw is not None:
                metric["observed"] = raw
            if raw is None:
                metric["note"] = "缺测、无效或非有限值，不能判为通过"
                if declared == "PASS":
                    warnings.append(key + " 缺测却声明PASS")
            elif stat_raw is None or raw != stat_raw:
                metric["status"] = "INCOMPLETE"
                metric["note"] = "checks与stats缺少一致数值，不能采信"
                warnings.append(key + " 的统计字段不一致")
            elif source_limit != limit:
                metric["status"] = "INCOMPLETE"
                metric["note"] = "分析器预算与本候选固定预算不一致"
                warnings.append(key + " 的预算口径冲突")
            elif not clean_input:
                metric["status"] = "INCOMPLETE"
                metric["note"] = "输入无效或分位数口径未确认"
            else:
                expected = "PASS" if raw <= limit else "FAIL"
                if declared == expected:
                    metric["status"] = expected
                    metric["note"] = "仅该项相对暂定预算的比较"
                else:
                    metric["status"] = "INCOMPLETE"
                    metric["note"] = "分析器判定与数值不一致，禁止提升为PASS"
                    warnings.append(key + " 的值与状态冲突")
        metrics.append(metric)

    statuses = [metric["status"] for metric in metrics]
    computed = (
        "INCOMPLETE" if "INCOMPLETE" in statuses or "NOT_MEASURED" in statuses else
        "FAIL" if "FAIL" in statuses else
        "PASS" if all(s == "PASS" for s in statuses) else
        "INCOMPLETE"
    )
    source_subset = analysis.get("measured_subset_status")
    if source_subset != computed:
        warnings.append("已测子集状态与原分析器声明不一致；降级为INCOMPLETE")
        computed = "INCOMPLETE"
    if analysis.get("full_scene_pass") is True:
        warnings.append("源报告声称全场景通过；本组件拒绝该主张")
        computed = "INCOMPLETE"
    origin_code, origin_note = declared_origin(capture)
    if origin_code != "DECLARED_REAL_UNLINKED":
        warnings.append(origin_note)
    missing = [
        {"key": key, "label": label, "unit": unit,
         "observed": None, "status": "NOT_MEASURED"}
        for key, label, unit in MISSING_WHOLE_SCENE
    ]
    return {
        "task_id": TASK_ID,
        "version": VERSION,
        "input_version": INPUT_VERSION,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "budget_approval": "UNAPPROVED_PROPOSAL",
        "whole_scene_status": "INCOMPLETE",
        "full_scene_pass": False,
        "measured_subset_status": computed,
        "sample_count": analysis.get("sample_count") if (
            type(analysis.get("sample_count")) is int and
            analysis["sample_count"] >= 0) else None,
        "percentile_method": "nearest-rank: rank=ceil(p*n), no interpolation",
        "metrics": metrics,
        "whole_scene_missing": missing,
        "capture": {
            "origin": origin_code, "note": origin_note,
            "engine_version": short_text(capture.get("engine_version"), 80)
            if isinstance(capture, dict) else "未提供",
            "renderer": short_text(capture.get("rendering_driver"), 80)
            if isinstance(capture, dict) else "未提供",
            "scene_sha256": short_text(capture.get("scene_sha256"), 90)
            if isinstance(capture, dict) else "未提供",
        },
        "process_memory": build_memory(memory),
        "warnings": warnings,
        "testing_status": "NOT_RUN",
        "shared_interface_approved": False,
    }


def fmt(value, unit=""):
    return "未测" if value is None else f"{value:g}" + (" " + unit if unit else "")


def html_report(report):
    """Fully offline, static and escaped markup; no scripts/network assets."""
    def e(value):
        return escape(str(value), quote=True)

    def row(metric):
        status = metric["status"]
        klass = "good" if status == "PASS" else "bad" if status == "FAIL" else "muted"
        return (
            "<tr><td>" + e(metric["label"]) + "</td><td>" +
            e(fmt(metric["observed"], metric["unit"])) + "</td><td>" +
            e(fmt(metric["budget"], metric["unit"])) + ' <small>提案</small></td>' +
            '<td class="' + klass + '">' + e(status) + "</td><td>" +
            e(metric["note"]) + "</td></tr>"
        )
    rows = "\n".join(row(metric) for metric in report["metrics"])
    missing = "\n".join(
        "<tr><td>" + e(item["label"]) + "</td><td>未测</td><td>NOT_MEASURED</td></tr>"
        for item in report["whole_scene_missing"]
    )
    memory = report["process_memory"]
    mem_rows = "\n".join(
        "<tr><td>" + e(label) + "</td><td>" +
        e(fmt(memory.get(key), unit)) + "</td></tr>"
        for key, label, unit in (
            ("working_set_peak_observed_gib", "工作集采样峰值（含共享页）", "GiB"),
            ("private_bytes_peak_observed_gib", "私有提交采样峰值", "GiB"),
            ("samples", "进程观测采样数", ""),
        )
    )
    warnings = "".join("<li>" + e(w) + "</li>" for w in report["warnings"])
    capture = report["capture"]
    return """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>GAME-WEB-MODULE-PERF-002 性能证据报告（候选）</title>
<style>
:root{color-scheme:light;font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
body{background:#f4f7fb;color:#192d45;margin:0;padding:30px 16px}
main{max-width:1100px;margin:auto}
section{background:#fff;border:1px solid #dde5ee;border-radius:10px;padding:20px;margin:16px 0}
h1{font-size:25px;margin-bottom:6px}h2{font-size:19px}
p,li,td{line-height:1.6}small,.muted{color:#5b687a}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{border-bottom:1px solid #e4e9f0;padding:10px;text-align:left;vertical-align:top}
th{background:#eef3f9}
.good{color:#087345;font-weight:bold}.bad{color:#a12727;font-weight:bold}
.banner{border-left:5px solid #b87516}
strong{font-weight:700}code{white-space:pre-wrap}
</style></head><body><main>
<h1>离线性能证据报告 · 候选 r1</h1>
<p>预算为未经批准的提案；显示数值不等于已验证的真实游戏性能。</p>
<section class="banner"><h2>整体场景：INCOMPLETE（不得宣称通过）</h2>
<p>CSV已测子集：<strong>""" + e(report["measured_subset_status"]) + """</strong>；
全场景始终缺少必要指标。帧间隔不等于脚本 CPU 或 GPU 执行时间。</p></section>
<section><h2>证据来源与口径</h2>
<p>帧样本量：""" + e(fmt(report["sample_count"])) + """；
数据来源：""" + e(capture["origin"]) + """（""" + e(capture["note"]) + """）。</p>
<p>引擎：""" + e(capture["engine_version"]) + """；
渲染后端：""" + e(capture["renderer"]) + """；
场景SHA256：""" + e(capture["scene_sha256"]) + """。</p>
<p>分位数：最近秩法，升序 rank=ceil(p*n)，不插值。</p></section>
<section><h2>预算与观测（独立对照）</h2>
<table><thead><tr><th>指标</th><th>分析器观测值</th><th>预算上限</th><th>单项状态</th><th>解释</th></tr></thead>
<tbody>""" + rows + """</tbody></table>
<p class="muted">PASS只表示已测单项与暂定上限的数值对比；不是场景、设备或正式验收通过。</p></section>
<section><h2>全场景仍缺测</h2>
<table><thead><tr><th>指标</th><th>观测值</th><th>状态</th></tr></thead>
<tbody>""" + missing + """</tbody></table></section>
<section><h2>Windows PID内存旁路证据</h2>
<p>质量：""" + e(memory["quality"]) + """；进程采样状态：""" +
e(memory["status"]) + """。""" + e(memory["note"]) + """</p>
<table><tbody>""" + mem_rows + """</tbody></table>
<p>不将工作集或私有提交自动写入PERF-002的ram_gib；未验证时间同步和来源绑定。</p>
<p>全进程CPU累计时间不是游戏脚本CPU；GPU/VRAM均未由该观察器测量。</p></section>
<section><h2>需要复核</h2><ul>""" + warnings + """</ul>
<p>本任务交付状态NOT_RUN；后续使用工具生成报告不等于测试或性能验收，不构成共享接口批准。</p></section>
</main></body></html>"""


def save_pair(prefix, markup, summary):
    """Refuse overwrite of EITHER output, preserving pre-existing files."""
    html_path = Path(str(prefix) + ".html")
    json_path = Path(str(prefix) + ".summary.json")
    created = []
    try:
        with html_path.open("x", encoding="utf-8", newline="") as file:
            created.append(html_path)
            file.write(markup)
        with json_path.open("x", encoding="utf-8", newline="") as file:
            created.append(json_path)
            json.dump(summary, file, indent=2, ensure_ascii=False, allow_nan=False)
            file.write("\n")
    except BaseException:
        for item in created:
            item.unlink(missing_ok=True)
        raise
    return html_path, json_path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis", required=True, help="PERF-002 JSON result")
    parser.add_argument("--memory", help="Optional PERF-004 process JSON")
    parser.add_argument("--capture", help="Optional PERF-003 capture metadata JSON")
    parser.add_argument("--out-prefix", required=True, help="New HTML and JSON output prefix")
    args = parser.parse_args(argv)
    try:
        analysis = read_object(args.analysis)
        memory = read_object(args.memory) if args.memory else None
        capture = read_object(args.capture) if args.capture else None
        report = build_report(analysis, memory, capture)
        html_path, json_path = save_pair(args.out_prefix, html_report(report), report)
    except (ValueError, OSError, UnicodeError, TypeError, OverflowError) as exc:
        print("REPORT_ERROR: " + type(exc).__name__ + ": " + str(exc), file=sys.stderr)
        return 2
    print("HTML=" + str(html_path))
    print("JSON=" + str(json_path))
    print("WHOLE_SCENE_STATUS=INCOMPLETE")
    print("TEST_STATUS=NOT_RUN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

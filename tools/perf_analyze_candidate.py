
#!/usr/bin/env python3
"""GAME-WEB-PERF-002/r1 | 离线CSV分析候选；仅标准库。

用法：
  python perf_analyze_candidate.py frames.csv [-o result.json]
  python perf_analyze_candidate.py --write-synthetic synthetic.csv
  python perf_analyze_candidate.py --self-test
退出码：0=CSV已测子集达标；1=已测子集超限；2=输入不完整或读写错误。
注意：0不等于整个场景验收通过；本工具永远不判定全场景PASS。
"""

import argparse
import csv
import io
import json
import math
import sys

TASK_ID = "GAME-WEB-PERF-002"
COLUMNS = ("frame_ms", "script_ms", "ram_gib", "vram_delta_gib",
           "draw_calls", "triangles")
INTEGER_COLUMNS = {"draw_calls", "triangles"}
LIMITS = {
    "frame_p50_ms": 12.0,
    "frame_p95_ms": 16.7,
    "frame_p99_ms": 24.0,
    "script_p95_ms": 2.0,
    "ram_peak_gib": 1.2,
    "vram_delta_peak_gib": 1.0,
    "draw_calls_peak": 200,
    "triangles_peak": 150000,
}
UNMEASURED = ("cold_load_s", "scene_switch_s", "dynamic_lights_peak",
              "shadow_lights_peak", "active_npcs_peak")
SYNTHETIC_CSV = ("frame_ms,script_ms,ram_gib,vram_delta_gib,draw_calls,triangles\n"
                 "12,2,1.2,1,200,150000\n"
                 "12,2,1.2,1,200,150000\n"
                 "12,2,1.2,1,200,150000\n")


def percentile_nearest_rank(samples, fraction):
    """升序排序；1-based秩=ceil(fraction*n)，不插值。"""
    ordered = sorted(samples)
    return ordered[math.ceil(fraction * len(ordered)) - 1]


def blank_report(source):
    return {
        "task_id": TASK_ID,
        "version": "r1",
        "input_version": "GAME-WEB-PERF-001/r1",
        "scope": "CSV measured subset only",
        "source": source,
        "percentile_definition": "nearest-rank: ascending, rank=ceil(p*n), p in {0.50,0.95,0.99}; no interpolation",
        "sample_count": 0,
        "stats": {
            "frame_ms": {"p50": None, "p95": None, "p99": None},
            "script_ms": {"p95": None},
            "ram_gib": {"peak": None},
            "vram_delta_gib": {"peak": None},
            "draw_calls": {"peak": None},
            "triangles": {"peak": None},
        },
        "checks": {k: {"value": None, "upper_inclusive": v,
                       "status": "INCOMPLETE"} for k, v in LIMITS.items()},
        "not_measured": {k: {"value": None, "status": "NOT_MEASURED"}
                         for k in UNMEASURED},
        "measured_subset_status": "INCOMPLETE",
        "status": "incomplete",
        "full_scene_pass": False,
        "error_count": 0,
        "errors": [],
    }


def record_error(report, code, detail):
    report["error_count"] += 1
    if len(report["errors"]) < 20:
        report["errors"].append({"code": code, "detail": detail})


def analyze_csv(stream, source="<stream>"):
    report = blank_report(source)
    frame, script = [], []
    peak = {name: 0 for name in COLUMNS[2:]}
    try:
        reader = csv.DictReader(stream, restkey="__EXTRA__", strict=True)
        if reader.fieldnames is None:
            record_error(report, "EMPTY_FILE", "无CSV表头")
            return report
        headers = [str(name).strip().lstrip("\ufeff") for name in reader.fieldnames]
        reader.fieldnames = headers
        if len(headers) != len(set(headers)) or "" in headers or "__EXTRA__" in headers:
            record_error(report, "INVALID_HEADER", "列名为空、重复或与保留名称冲突")
            return report
        missing = [name for name in COLUMNS if name not in headers]
        if missing:
            record_error(report, "MISSING_COLUMNS", ",".join(missing))
            return report
        for row in reader:
            report["sample_count"] += 1
            line = reader.line_num
            if "__EXTRA__" in row:
                record_error(report, "EXTRA_FIELDS", f"line {line}: 多余单元格")
                continue
            values = {}
            for col in COLUMNS:
                raw = row.get(col)
                if raw is None or not raw.strip():
                    record_error(report, "MISSING_VALUE", f"line {line}: {col}")
                    continue
                try:
                    value = float(raw.strip())
                except ValueError:
                    record_error(report, "NOT_NUMBER", f"line {line}: {col}")
                    continue
                if not math.isfinite(value):
                    record_error(report, "NON_FINITE", f"line {line}: {col}")
                elif value < 0:
                    record_error(report, "NEGATIVE", f"line {line}: {col}")
                elif col in INTEGER_COLUMNS and not value.is_integer():
                    record_error(report, "NOT_INTEGER", f"line {line}: {col}")
                else:
                    values[col] = value
            if len(values) == len(COLUMNS):
                frame.append(values["frame_ms"])
                script.append(values["script_ms"])
                for col in peak:
                    peak[col] = max(peak[col], values[col])
    except (csv.Error, UnicodeError, OSError) as exc:
        record_error(report, "READ_ERROR", f"{type(exc).__name__}: {exc}")
    if report["sample_count"] == 0:
        record_error(report, "EMPTY_TABLE", "无逐帧数据行")
    # 试验策略：任一行/列无效，则整份CSV不可信；所有已测统计保留null，不允许局部PASS。
    if report["error_count"]:
        return report
    stats = report["stats"]
    stats["frame_ms"] = {"p50": percentile_nearest_rank(frame, 0.50),
                         "p95": percentile_nearest_rank(frame, 0.95),
                         "p99": percentile_nearest_rank(frame, 0.99)}
    stats["script_ms"]["p95"] = percentile_nearest_rank(script, 0.95)
    for col in peak:
        stats[col]["peak"] = int(peak[col]) if col in INTEGER_COLUMNS else peak[col]
    observed = {
        "frame_p50_ms": stats["frame_ms"]["p50"],
        "frame_p95_ms": stats["frame_ms"]["p95"],
        "frame_p99_ms": stats["frame_ms"]["p99"],
        "script_p95_ms": stats["script_ms"]["p95"],
        "ram_peak_gib": stats["ram_gib"]["peak"],
        "vram_delta_peak_gib": stats["vram_delta_gib"]["peak"],
        "draw_calls_peak": stats["draw_calls"]["peak"],
        "triangles_peak": stats["triangles"]["peak"],
    }
    for key, value in observed.items():
        report["checks"][key].update(value=value,
                status="PASS" if value <= LIMITS[key] else "FAIL")
    report["measured_subset_status"] = (
        "PASS" if all(c["status"] == "PASS" for c in report["checks"].values())
        else "FAIL")
    # CSV未包含灯、NPC、加载耗时，故全场景状态始终incomplete。
    return report


def csv_from_rows(rows):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(COLUMNS)
    writer.writerows(rows)
    return output.getvalue()


def self_test():
    def check(csv_text):
        return analyze_csv(io.StringIO(csv_text), source="synthetic_only")

    basic = check(SYNTHETIC_CSV)
    assert basic["sample_count"] == 3
    assert basic["measured_subset_status"] == "PASS"
    assert basic["status"] == "incomplete" and not basic["full_scene_pass"]
    assert all(v["status"] == "NOT_MEASURED" for v in basic["not_measured"].values())
    assert json.loads(json.dumps(basic, allow_nan=False))["stats"]["frame_ms"]["p50"] == 12

    frames = [12] * 50 + [16.7] * 45 + [24] * 5
    rows = [[x, 2, 1.2, 1, 200, 150000] for x in frames]
    boundary = check(csv_from_rows(rows))
    assert boundary["stats"]["frame_ms"] == {"p50": 12, "p95": 16.7, "p99": 24}
    assert all(v["status"] == "PASS" for v in boundary["checks"].values())

    rows[-2][0] = rows[-1][0] = 24.01
    breach = check(csv_from_rows(rows))
    assert breach["checks"]["frame_p99_ms"]["status"] == "FAIL"
    assert breach["measured_subset_status"] == "FAIL"

    invalid_csvs = [
        "", ",".join(COLUMNS) + "\n",  # 无文件/空表
        SYNTHETIC_CSV.replace("triangles", "other", 1),  # 缺列
        SYNTHETIC_CSV.replace("12,2,", "12,,", 1),  # 缺值
        SYNTHETIC_CSV.replace("12,2,", "nan,2,", 1),
        SYNTHETIC_CSV.replace("12,2,", "inf,2,", 1),
        SYNTHETIC_CSV.replace("12,2,", "-1,2,", 1),
        SYNTHETIC_CSV.replace("200,150000", "200.5,150000", 1),
        SYNTHETIC_CSV.replace("12,2,1.2,1,200,150000", "12,2,1.2,1,200", 1),
    ]
    for text in invalid_csvs:
        result = check(text)
        assert result["status"] == "incomplete"
        assert result["measured_subset_status"] == "INCOMPLETE"
        assert result["error_count"] > 0
        assert all(item["value"] is None and item["status"] == "INCOMPLETE"
                   for item in result["checks"].values())
    print("SELF_TEST_OK: synthetic inputs only; not a benchmark")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", nargs="?")
    parser.add_argument("-o", "--output", help="JSON路径；拒绝覆盖已有文件")
    parser.add_argument("--write-synthetic", metavar="FILE", help="生成纯合成CSV；拒绝覆盖")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    if args.write_synthetic:
        try:
            with open(args.write_synthetic, "x", encoding="utf-8", newline="") as f:
                f.write(SYNTHETIC_CSV)
        except OSError as exc:
            parser.exit(2, f"无法创建合成CSV: {exc}\n")
        return 0
    if not args.csv_file:
        parser.error("需要CSV文件或--self-test/--write-synthetic")
    try:
        with open(args.csv_file, "r", encoding="utf-8-sig", newline="") as f:
            result = analyze_csv(f, source=args.csv_file)
    except (OSError, UnicodeError) as exc:
        result = blank_report(args.csv_file)
        record_error(result, "OPEN_ERROR", f"{type(exc).__name__}: {exc}")
    payload = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    if args.output:
        try:
            with open(args.output, "x", encoding="utf-8") as f:
                f.write(payload)
        except OSError as exc:
            parser.exit(2, f"无法创建JSON: {exc}\n")
    else:
        sys.stdout.write(payload)
    if result["error_count"]:
        return 2
    return 1 if result["measured_subset_status"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())

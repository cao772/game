
#!/usr/bin/env python3
"""GAME-WEB-PERF-004/r1
Windows explicit-PID process-memory sampler.
Python standard library only. No process enumeration or termination.
"""

import argparse
import csv
import ctypes
from ctypes import wintypes
from datetime import datetime, timedelta, timezone
import io
import json
import math
import ntpath
import os
from pathlib import Path
import tempfile
import time

GIB = 1024 ** 3
FILETIME_EPOCH = datetime(1601, 1, 1, tzinfo=timezone.utc)

COLUMNS = (
    "utc", "monotonic_elapsed_s", "pid",
    "process_creation_filetime_100ns",
    "working_set_gib", "private_bytes_gib",
    "process_cpu_total_s",
)

MIN_SECONDS, MAX_SECONDS = 0.1, 600.0
MIN_INTERVAL, MAX_INTERVAL = 0.05, 10.0

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
SYNCHRONIZE = 0x00100000
WAIT_OBJECT_0 = 0
WAIT_TIMEOUT = 0x102


class FILETIME(ctypes.Structure):
    _fields_ = [
        ("dwLowDateTime", wintypes.DWORD),
        ("dwHighDateTime", wintypes.DWORD),
    ]


class PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("PageFaultCount", wintypes.DWORD),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
        ("PrivateUsage", ctypes.c_size_t),
    ]


def filetime_ticks(value):
    return (
        (int(value.dwHighDateTime) << 32)
        | int(value.dwLowDateTime)
    )


def filetime_utc(ticks):
    return (
        FILETIME_EPOCH
        + timedelta(microseconds=ticks // 10)
    ).isoformat()


class ApiError(Exception):
    def __init__(self, name, code):
        self.name = name
        self.code = code
        super().__init__(f"{name}: Win32 error {code}")


class Stopped(Exception):
    pass


class WindowsAPI:
    def __init__(self):
        if os.name != "nt":
            raise RuntimeError("Windows only")

        self.k = ctypes.WinDLL(
            "kernel32", use_last_error=True
        )
        self.p = ctypes.WinDLL(
            "psapi", use_last_error=True
        )

        self.k.OpenProcess.argtypes = [
            wintypes.DWORD,
            wintypes.BOOL,
            wintypes.DWORD,
        ]
        self.k.OpenProcess.restype = wintypes.HANDLE

        self.k.CloseHandle.argtypes = [
            wintypes.HANDLE
        ]
        self.k.CloseHandle.restype = wintypes.BOOL

        self.k.WaitForSingleObject.argtypes = [
            wintypes.HANDLE,
            wintypes.DWORD,
        ]
        self.k.WaitForSingleObject.restype = (
            wintypes.DWORD
        )

        self.k.GetProcessTimes.argtypes = [
            wintypes.HANDLE,
            ctypes.POINTER(FILETIME),
            ctypes.POINTER(FILETIME),
            ctypes.POINTER(FILETIME),
            ctypes.POINTER(FILETIME),
        ]
        self.k.GetProcessTimes.restype = wintypes.BOOL

        self.k.QueryFullProcessImageNameW.argtypes = [
            wintypes.HANDLE,
            wintypes.DWORD,
            wintypes.LPWSTR,
            ctypes.POINTER(wintypes.DWORD),
        ]
        self.k.QueryFullProcessImageNameW.restype = (
            wintypes.BOOL
        )

        self.p.GetProcessMemoryInfo.argtypes = [
            wintypes.HANDLE,
            ctypes.POINTER(PROCESS_MEMORY_COUNTERS_EX),
            wintypes.DWORD,
        ]
        self.p.GetProcessMemoryInfo.restype = (
            wintypes.BOOL
        )

    @staticmethod
    def failed(api):
        raise ApiError(api, ctypes.get_last_error())

    def open(self, pid):
        # No PROCESS_TERMINATE, VM_WRITE or elevation.
        rights = (
            PROCESS_QUERY_LIMITED_INFORMATION
            | SYNCHRONIZE
        )
        handle = self.k.OpenProcess(rights, False, pid)
        if not handle:
            self.failed("OpenProcess")
        return handle

    def close(self, handle):
        if handle:
            self.k.CloseHandle(handle)

    def wait_alive(self, handle, milliseconds=0):
        code = self.k.WaitForSingleObject(
            handle, milliseconds
        )
        if code == WAIT_OBJECT_0:
            raise Stopped("PID_EXITED")
        if code != WAIT_TIMEOUT:
            if code == 0xFFFFFFFF:
                self.failed("WaitForSingleObject")
            raise ApiError(
                "WaitForSingleObject_unexpected", code
            )

    def identity_and_cpu(self, handle):
        create, end, kernel, user = (
            FILETIME() for _ in range(4)
        )

        ok = self.k.GetProcessTimes(
            handle,
            ctypes.byref(create),
            ctypes.byref(end),
            ctypes.byref(kernel),
            ctypes.byref(user),
        )
        if not ok:
            self.failed("GetProcessTimes")

        creation = filetime_ticks(create)
        cpu_total = (
            filetime_ticks(kernel)
            + filetime_ticks(user)
        ) / 1e7

        return creation, cpu_total

    def image_path(self, handle):
        length = wintypes.DWORD(32768)
        buffer = ctypes.create_unicode_buffer(
            length.value
        )
        ok = self.k.QueryFullProcessImageNameW(
            handle, 0, buffer, ctypes.byref(length)
        )
        if not ok:
            self.failed("QueryFullProcessImageNameW")
        return buffer.value

    def memory(self, handle):
        mem = PROCESS_MEMORY_COUNTERS_EX()
        mem.cb = ctypes.sizeof(mem)

        ok = self.p.GetProcessMemoryInfo(
            handle, ctypes.byref(mem), mem.cb
        )
        if not ok:
            self.failed("GetProcessMemoryInfo")

        return (
            mem.WorkingSetSize / GIB,
            mem.PrivateUsage / GIB,
        )


def positive_pid(raw):
    try:
        pid = int(raw)
    except ValueError:
        raise argparse.ArgumentTypeError(
            "PID must be a positive integer"
        ) from None

    if not 1 <= pid <= 0xFFFFFFFF:
        raise argparse.ArgumentTypeError(
            "PID out of range"
        )
    return pid


def bounded_float(name, low, high):
    def parse(raw):
        try:
            value = float(raw)
        except ValueError:
            raise argparse.ArgumentTypeError(
                f"{name} must be numeric"
            ) from None

        if not math.isfinite(value) or not (
            low <= value <= high
        ):
            raise argparse.ArgumentTypeError(
                f"{name} must be finite in [{low}, {high}]"
            )
        return value
    return parse


def expected_mode(value):
    if not value:
        return "none"
    if ntpath.isabs(value):
        return "path"
    if (
        ntpath.basename(value) == value
        and ":" not in value
    ):
        return "basename"
    raise ValueError(
        "--expected-exe must be a basename "
        "or absolute Windows path"
    )


def same_image(actual, expected):
    mode = expected_mode(expected)
    if mode == "none":
        return True
    if mode == "basename":
        return (
            ntpath.basename(actual).casefold()
            == expected.casefold()
        )
    return (
        ntpath.normcase(ntpath.normpath(actual))
        == ntpath.normcase(ntpath.normpath(expected))
    )


def offsets(seconds, interval):
    # Finite schedule; includes the requested endpoint.
    steps = math.ceil(seconds / interval)
    for i in range(steps + 1):
        yield min(seconds, i * interval)


def reserve_pair(prefix):
    csv_path = Path(str(prefix) + ".csv")
    json_path = Path(str(prefix) + ".json")

    # Exclusive create: never overwrite an old result.
    csv_file = csv_path.open(
        "x", encoding="utf-8", newline=""
    )
    try:
        json_file = json_path.open(
            "x", encoding="utf-8", newline=""
        )
    except BaseException:
        csv_file.close()
        # Delete only the CSV just created by this call.
        csv_path.unlink()
        raise

    return csv_path, json_path, csv_file, json_file


def parser():
    p = argparse.ArgumentParser(
        description=__doc__
    )
    p.add_argument(
        "--pid", type=positive_pid,
        help="Explicitly authorized target PID"
    )
    p.add_argument(
        "--seconds",
        type=bounded_float(
            "seconds", MIN_SECONDS, MAX_SECONDS
        ),
        default=3.0,
    )
    p.add_argument(
        "--interval",
        type=bounded_float(
            "interval", MIN_INTERVAL, MAX_INTERVAL
        ),
        default=0.25,
    )
    p.add_argument(
        "--expected-exe",
        help="Exact basename or absolute Windows path"
    )
    p.add_argument(
        "--include-cpu",
        action="store_true",
        help="Total process CPU; never script CPU"
    )
    p.add_argument(
        "--out-prefix",
        help="Unique output stem for CSV and JSON"
    )
    p.add_argument(
        "--self-test",
        action="store_true",
        help="Cross-platform tests without Windows API calls"
    )
    return p


def self_test():
    p = parser()

    valid = p.parse_args([
        "--pid", "42",
        "--seconds", "0.1",
        "--interval", "0.05",
    ])
    assert valid.pid == 42

    invalid = [
        ["--pid", "0"],
        ["--seconds", "nan"],
        ["--seconds", "601"],
        ["--interval", "0"],
        ["--interval", "inf"],
    ]

    import contextlib

    for args in invalid:
        with contextlib.redirect_stderr(io.StringIO()):
            try:
                p.parse_args(args)
            except SystemExit as ex:
                assert ex.code != 0
            else:
                raise AssertionError(
                    f"Unexpectedly accepted {args}"
                )

    assert list(offsets(.11, .05)) == [
        0, .05, .1, .11
    ]
    assert len(list(offsets(600, .05))) <= 12002

    assert same_image(
        r"C:\Tools\Godot.exe", "godot.exe"
    )
    assert same_image(
        r"C:\Tools\Godot.exe",
        r"c:\tools\GODOT.exe"
    )
    assert not same_image(
        r"C:\Tools\Godot.exe",
        r"C:\Else\Godot.exe"
    )

    try:
        expected_mode(r"relative\Godot.exe")
    except ValueError:
        pass
    else:
        raise AssertionError(
            "Accepted relative executable path"
        )

    # Filesystem tests only use an isolated temporary dir.
    with tempfile.TemporaryDirectory() as folder:
        stem = Path(folder) / "sample"
        csv_path, json_path, cf, jf = reserve_pair(
            stem
        )

        cf.write("header\n")
        cf.close()
        jf.write("{}")
        jf.close()

        try:
            reserve_pair(stem)
        except FileExistsError:
            pass
        else:
            raise AssertionError(
                "Overwrite was not rejected"
            )

        assert csv_path.read_text() == "header\n"
        assert json_path.read_text() == "{}"

        stem2 = Path(folder) / "second"
        second_json = Path(str(stem2) + ".json")
        second_json.write_text("kept")

        try:
            reserve_pair(stem2)
        except FileExistsError:
            pass
        else:
            raise AssertionError(
                "Second-file collision was not rejected"
            )

        assert not Path(
            str(stem2) + ".csv"
        ).exists()
        assert second_json.read_text() == "kept"

    print(
        "SELF_TEST_OK: parameters, finite schedule, "
        "exclusive outputs; no Windows API calls"
    )


def collect(api, args, writer, csv_file, record):
    original = None
    start = None
    peak_working = None
    peak_private = None

    try:
        original = api.open(args.pid)
        api.wait_alive(original)

        ticks, _ = api.identity_and_cpu(original)
        image_path = api.image_path(original)

        record["process_creation_filetime_100ns"] = (
            str(ticks)
        )
        record["process_created_utc"] = (
            filetime_utc(ticks)
        )
        record["exe_basename"] = (
            ntpath.basename(image_path)
        )
        record["expected_exe_matched"] = (
            same_image(image_path, args.expected_exe)
        )

        if not record["expected_exe_matched"]:
            raise Stopped("EXPECTED_EXE_MISMATCH")

        start = time.monotonic()

        for offset in offsets(
            args.seconds, args.interval
        ):
            due = start + offset
            remaining = due - time.monotonic()

            if remaining > 0:
                api.wait_alive(
                    original,
                    math.ceil(remaining * 1000)
                )

            api.wait_alive(original)
            current = None

            try:
                # Reopen the SAME specified PID only.
                current = api.open(args.pid)
                api.wait_alive(current)

                observed_ticks, total_cpu = (
                    api.identity_and_cpu(current)
                )

                if observed_ticks != ticks:
                    raise Stopped("PID_REUSED")

                current_image = api.image_path(current)
                if not same_image(
                    current_image, image_path
                ):
                    raise Stopped("PID_IMAGE_CHANGED")

                working, private = api.memory(current)

                # Reject samples captured across termination.
                api.wait_alive(current)
                api.wait_alive(original)

            finally:
                api.close(current)

            elapsed = time.monotonic() - start

            row = {
                "utc": datetime.now(
                    timezone.utc
                ).isoformat(timespec="milliseconds"),
                "monotonic_elapsed_s": round(
                    elapsed, 6
                ),
                "pid": args.pid,
                "process_creation_filetime_100ns": str(
                    ticks
                ),
                "working_set_gib": working,
                "private_bytes_gib": private,
                "process_cpu_total_s": (
                    total_cpu if args.include_cpu else ""
                ),
            }

            writer.writerow(row)
            csv_file.flush()

            record["samples"] += 1
            peak_working = (
                working if peak_working is None
                else max(peak_working, working)
            )
            peak_private = (
                private if peak_private is None
                else max(peak_private, private)
            )

        record["stop_reason"] = "DURATION_REACHED"
        # Means sampling completed, NOT performance PASS.
        record["status"] = "complete"

    except Stopped as exc:
        record["stop_reason"] = str(exc)

    except ApiError as exc:
        reason = (
            "PERMISSION_DENIED"
            if exc.code == 5 else "API_ERROR"
        )

        if (
            original is None
            and exc.name == "OpenProcess"
            and exc.code == 87
        ):
            reason = "PID_NOT_FOUND_OR_EXITED"

        if original is not None:
            try:
                api.wait_alive(original)
            except Stopped:
                reason = "PID_EXITED"
            except ApiError:
                pass

        record["stop_reason"] = reason
        record["win32_error"] = {
            "api": exc.name,
            "code": exc.code,
        }

    except KeyboardInterrupt:
        record["stop_reason"] = "INTERRUPTED"

    except OSError as exc:
        record["stop_reason"] = "IO_ERROR"
        record["error_type"] = type(exc).__name__

    finally:
        record["elapsed_s"] = (
            round(time.monotonic() - start, 6)
            if start is not None else None
        )
        record["working_set_peak_observed_gib"] = (
            peak_working
        )
        record["private_bytes_peak_observed_gib"] = (
            peak_private
        )
        api.close(original)


def main(argv=None):
    p = parser()
    args = p.parse_args(argv)

    if args.self_test:
        self_test()
        return 0

    if args.pid is None or args.out_prefix is None:
        p.error(
            "--pid and --out-prefix are required"
        )

    if args.interval > args.seconds:
        p.error(
            "--interval must not exceed --seconds"
        )

    try:
        mode = expected_mode(args.expected_exe)
    except ValueError as exc:
        p.error(str(exc))

    if os.name != "nt":
        p.error(
            "Live sampling requires Windows; "
            "use --self-test elsewhere"
        )

    try:
        csv_path, json_path, cf, jf = reserve_pair(
            args.out_prefix
        )
    except OSError as exc:
        print(
            f"OUTPUT_ERROR: {type(exc).__name__}; "
            "existing files must not be overwritten"
        )
        return 2

    record = {
        "task_id": "GAME-WEB-PERF-004",
        "version": "r1",
        "input_version": "GAME-WEB-PERF-003/r1",
        "is_synthetic": False,
        "pid": args.pid,
        "process_creation_filetime_100ns": None,
        "process_created_utc": None,
        "exe_basename": None,
        "expected_exe_mode": mode,
        "expected_exe_matched": None,
        "seconds_requested": args.seconds,
        "interval_requested": args.interval,
        "samples": 0,
        "elapsed_s": None,
        "status": "incomplete",
        "stop_reason": "NOT_STARTED",
        "working_set_peak_observed_gib": None,
        "private_bytes_peak_observed_gib": None,
        "process_cpu_total_s_status": (
            "MEASURED_PROCESS_TOTAL"
            if args.include_cpu else "NOT_MEASURED"
        ),
        "script_cpu_status": "NOT_MEASURED",
        "gpu_status": "NOT_MEASURED",
        "vram_status": "NOT_MEASURED",
        "full_scene_pass": False,
        "performance_status": "NOT_EVALUATED",
        "csv_path": str(csv_path),
        "json_path": str(json_path),
    }

    try:
        writer = csv.DictWriter(
            cf, fieldnames=COLUMNS
        )
        writer.writeheader()
        cf.flush()

        api = WindowsAPI()
        collect(
            api, args, writer, cf, record
        )

    except (OSError, ApiError) as exc:
        record["status"] = "incomplete"
        record["stop_reason"] = "SETUP_OR_OUTPUT_ERROR"
        record["error_type"] = type(exc).__name__

    finally:
        cf.close()

        try:
            jf.write(
                json.dumps(
                    record,
                    ensure_ascii=False,
                    indent=2,
                    allow_nan=False,
                )
            )
            jf.write("\n")
        finally:
            jf.close()

    print(
        f"CSV={csv_path}\n"
        f"JSON={json_path}\n"
        f"SAMPLES={record['samples']}\n"
        f"STATUS={record['status']}\n"
        f"STOP_REASON={record['stop_reason']}"
    )

    return 0 if record["status"] == "complete" else 2


if __name__ == "__main__":
    raise SystemExit(main())

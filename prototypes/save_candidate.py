
import json
import os
import tempfile
from copy import deepcopy
from pathlib import Path

VERSION = 1

class SaveError(ValueError):
    pass

def clock_ok(value):
    return type(value) is int and value >= 0

def validate(data):
    if not isinstance(data, dict) or set(data) != {"version", "mode", "free_clock", "history"}:
        raise SaveError("存档字段不合法")
    if type(data["version"]) is not int or data["version"] != VERSION:
        raise SaveError("不支持的存档版本")
    if data["mode"] not in ("free", "history"):
        raise SaveError("未知游戏模式")
    if not clock_ok(data["free_clock"]):
        raise SaveError("自由时钟不合法")
    h = data["history"]
    if not isinstance(h, dict) or set(h) != {"active_chapter", "entry_free_clock", "chapter_clocks"}:
        raise SaveError("历史数据结构不合法")
    clocks = h["chapter_clocks"]
    if not isinstance(clocks, dict):
        raise SaveError("章节时钟集合不合法")
    for name, value in clocks.items():
        if not isinstance(name, str) or not name.strip():
            raise SaveError("章节标识不合法")
        if not clock_ok(value):
            raise SaveError("章节时钟不合法")
    active = h["active_chapter"]
    entry = h["entry_free_clock"]
    if data["mode"] == "free":
        if active is not None or entry is not None:
            raise SaveError("自由模式不能保留活动章节")
    else:
        if not isinstance(active, str) or active not in clocks:
            raise SaveError("活动章节不存在")
        if not clock_ok(entry) or entry != data["free_clock"]:
            raise SaveError("历史模式修改了自由时钟")
    return data

def new_game():
    return validate({
        "version": VERSION, "mode": "free", "free_clock": 0,
        "history": {"active_chapter": None, "entry_free_clock": None,
                    "chapter_clocks": {}}
    })

def enter_chapter(state, chapter):
    validate(state)
    if state["mode"] != "free":
        raise SaveError("必须先退出当前章节")
    if not isinstance(chapter, str) or not chapter.strip():
        raise SaveError("章节标识不能为空")
    result = deepcopy(state)
    h = result["history"]
    h["chapter_clocks"].setdefault(chapter, 0)
    h["active_chapter"] = chapter
    h["entry_free_clock"] = result["free_clock"]
    result["mode"] = "history"
    return validate(result)

def advance(state, ticks):
    validate(state)
    if not clock_ok(ticks):
        raise SaveError("时间增量必须为非负整数")
    result = deepcopy(state)
    if result["mode"] == "free":
        result["free_clock"] += ticks
    else:
        h = result["history"]
        chapter = h["active_chapter"]
        h["chapter_clocks"][chapter] += ticks
    return validate(result)

def exit_chapter(state):
    validate(state)
    if state["mode"] != "history":
        raise SaveError("当前不在历史章节")
    result = deepcopy(state)
    result["mode"] = "free"
    result["history"]["active_chapter"] = None
    result["history"]["entry_free_clock"] = None
    return validate(result)

def load_game(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as exc:
        raise SaveError("无法读取或解析存档") from exc
    return validate(data)

def save_game(state, path):
    validate(state)
    path = Path(path)
    if path.exists():
        old = load_game(path)
        if state["free_clock"] < old["free_clock"]:
            raise SaveError("拒绝覆盖：自由时钟不得倒退")
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                         dir=path.parent, delete=False) as file:
            tmp = file.name
            json.dump(state, file, ensure_ascii=False, indent=2, sort_keys=True)
            file.write("\n")
            file.flush()
            os.fsync(file.fileno())
        os.replace(tmp, path)
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)

def test_clock_isolation():
    start = new_game()
    free = advance(start, 120)
    chapter = enter_chapter(free, "chapter_001")
    chapter = advance(chapter, 500)
    assert chapter["free_clock"] == 120
    assert chapter["history"]["entry_free_clock"] == 120
    assert chapter["history"]["chapter_clocks"]["chapter_001"] == 500
    back = exit_chapter(chapter)
    assert back["free_clock"] == 120
    assert back["mode"] == "free"
    assert start["free_clock"] == 0
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "save.json"
        save_game(free, path)
        save_game(back, path)
        rejected = False
        try:
            save_game(start, path)
        except SaveError:
            rejected = True
        assert rejected
        assert load_game(path)["free_clock"] == 120

def test_roundtrip():
    state = advance(new_game(), 42)
    state = enter_chapter(state, "正史第一章")
    state = advance(state, 17)
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "save.json"
        save_game(state, path)
        restored = load_game(path)
        assert restored == state
        assert restored["free_clock"] == 42
        assert restored["history"]["chapter_clocks"]["正史第一章"] == 17

def test_invalid_version():
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "bad.json"
        for patch in (
            {"version": 0}, {"version": 2}, {"version": True},
            {"mode": "unknown"}, {"free_clock": -1}, {"free_clock": True}
        ):
            corrupted = new_game()
            corrupted.update(patch)
            path.write_text(json.dumps(corrupted), encoding="utf-8")
            rejected = False
            try:
                load_game(path)
            except SaveError:
                rejected = True
            assert rejected, f"未拒绝损坏存档：{patch}"

if __name__ == "__main__":
    test_clock_isolation()
    test_roundtrip()
    test_invalid_version()
    print("PASS: 3 tests")

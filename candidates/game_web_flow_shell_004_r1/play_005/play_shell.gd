extends Control
## GAME-WEB-PLAY-SHELL-005 r1 / source submitted / NOT_RUN.
## Standalone UI façade. All upstream sources are pinned local public copies.
## No real story/events/game state, no save writes, no direct cross-PR API.
signal page_changed(page_id: String)
signal synthetic_region_confirmation(target_id: StringName)
signal synthetic_event_choice(action_id: String)

const EventModel = preload("res://play_005/event_preview_model.gd")
const InputBackend = preload("res://play_005/vendor/input/input_settings_ui_backend_004.gd")
const REGION_SCENE := "res://play_005/vendor/region/main.tscn"
const STATE_SCENE := "res://play_005/vendor/state/snapshot_browser.tscn"
const CHAR_SCENE := "res://play_005/vendor/char/profile_flow_candidate.tscn"
const MODULES := ["region", "event", "saves", "characters", "input_19"]
const LABELS := {
    "region": "合成灰盒 / 场景交互",
    "event": "公开占位事件 / 选择",
    "saves": "只读存档浏览",
    "characters": "合成资料列表",
    "input_19": "输入配置候选 #19"
}
const KEY_CHOICES := [KEY_4, KEY_5, KEY_6, KEY_2, KEY_Q, KEY_F1]
const ACTION_IDS := ["observe", "open_door", "withdraw", "reset_round", "cancel"]

@onready var _flow: Control = $FlowEntry
var _screen: PanelContainer = null
var _stage: VBoxContainer = null
var _status: Label = null
var _next_button: Button = null
var _event_choice: OptionButton = null
var _selected_action: OptionButton = null
var _selected_key: OptionButton = null
var _event_model = EventModel.new()
var _input_backend = InputBackend.new()
var _active: String = ""
var _region: Node3D = null
var _instance: Node = null
var _event_snapshot: Dictionary = {}
var _last_region_confirm: StringName = &""


func _ready() -> void:
    var sidebar := _flow.get_node_or_null("Shell/Frame/Layout/Body/Sidebar")
    if sidebar is VBoxContainer:
        sidebar.add_child(HSeparator.new())
        for id in MODULES:
            var button := Button.new()
            button.name = "Play005_" + id
            button.text = LABELS[id]
            button.focus_mode = Control.FOCUS_ALL
            button.pressed.connect(Callable(self, "open_module").bind(id))
            sidebar.add_child(button)


func active_module() -> String:
    return _active


func last_region_confirmation() -> StringName:
    return _last_region_confirm


func event_state() -> Dictionary:
    return _event_model.state()


func return_menu() -> void:
    _remove_screen()
    _active = ""
    _flow.show()
    page_changed.emit("menu")


func _remove_screen() -> void:
    _region = null
    _instance = null
    _event_choice = null
    _selected_action = null
    _selected_key = null
    _stage = null
    _status = null
    _next_button = null
    if is_instance_valid(_screen):
        remove_child(_screen)
        _screen.queue_free()
    _screen = null


func _make_label(value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return label


func _button(parent: Control, name_value: String, caption: String,
        action: Callable) -> Button:
    var b := Button.new()
    b.name = name_value
    b.text = caption
    b.focus_mode = Control.FOCUS_ALL
    b.pressed.connect(action)
    parent.add_child(b)
    return b


func _make_screen(title: String) -> void:
    _screen = PanelContainer.new()
    _screen.name = "Play005Screen"
    _screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_screen)
    var pad := MarginContainer.new()
    pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for margin in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        pad.add_theme_constant_override(margin, 14)
    _screen.add_child(pad)
    var main := VBoxContainer.new()
    main.add_theme_constant_override("separation", 9)
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pad.add_child(main)
    var top := HBoxContainer.new()
    main.add_child(top)
    var heading := _make_label(title + " · Draft / NOT_RUN")
    heading.add_theme_font_size_override("font_size", 22)
    top.add_child(heading)
    _button(top, "ReturnMenu", "返回主菜单",
        Callable(self, "return_menu"))
    _stage = VBoxContainer.new()
    _stage.name = "PlayContent"
    _stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _stage.add_theme_constant_override("separation", 9)
    main.add_child(_stage)
    _status = _make_label("本地公开占位内容；所有关联接口均为待验收候选。")
    _status.name = "PlayStatus"
    main.add_child(_status)


func _blocked(reason: String) -> void:
    _stage.add_child(_make_label("BLOCKED · " + reason))
    _status.text = "降级：未自动替换、猜测或调用缺失组件。"


func _mount_control(path: String) -> Dictionary:
    if not ResourceLoader.exists(path, "PackedScene"):
        return {"ok": false, "reason": "缺少固定场景 " + path.get_file()}
    var asset: Resource = ResourceLoader.load(path, "PackedScene")
    if not asset is PackedScene:
        return {"ok": false, "reason": "固定候选场景资源格式无效"}
    var candidate: Node = (asset as PackedScene).instantiate()
    if not candidate is Control:
        candidate.free()
        return {"ok": false, "reason": "候选场景根节点不是 Control"}
    var widget: Control = candidate as Control
    widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _stage.add_child(widget)
    return {"ok": true, "node": widget}


func open_module(id: String) -> bool:
    if not MODULES.has(id):
        return false
    if get_tree().paused:
        return false
    _remove_screen()
    _active = id
    _flow.hide()
    _make_screen(LABELS[id])
    match id:
        "region":
            _build_region()
        "event":
            _build_event()
        "saves":
            _build_saves()
        "characters":
            _build_characters()
        "input_19":
            _build_input()
    page_changed.emit(id)
    return true


func _build_region() -> void:
    _stage.add_child(_make_label(
        "PR #23：独立合成几何体 / 接近 / 选择 / 确认。此处不包含游戏真实场景。"))
    if not ResourceLoader.exists(REGION_SCENE, "PackedScene"):
        _blocked("PR #23 灰盒场景缺失")
        return
    var asset: Resource = ResourceLoader.load(REGION_SCENE, "PackedScene")
    if not asset is PackedScene:
        _blocked("PR #23 灰盒资源不可用")
        return
    var node: Node = (asset as PackedScene).instantiate()
    if not node is Node3D or not node.has_method("flow_snapshot"):
        node.free()
        _blocked("PR #23 缺少 Node3D/flow_snapshot() 候选接口")
        return
    var display := SubViewportContainer.new()
    display.name = "RegionViewport"
    display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    display.size_flags_vertical = Control.SIZE_EXPAND_FILL
    display.stretch = true
    _stage.add_child(display)
    var viewport := SubViewport.new()
    viewport.name = "IsolatedWorldViewport"
    viewport.size = Vector2i(1024, 640)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = true
    display.add_child(viewport)
    viewport.add_child(node)
    _region = node as Node3D
    _button(_stage, "ReadConfirm", "读取已确认占位目标并进入事件选择",
        Callable(self, "_follow_region"))
    _status.text = "源自 PR #23 的隔离副本。先在灰盒中交互确认；按钮只读取确认 ID。"


func _follow_region() -> void:
    if not is_instance_valid(_region):
        _status.text = "BLOCKED：区域实例缺失"
        return
    var value: Variant = _region.call("flow_snapshot")
    if typeof(value) != TYPE_DICTIONARY:
        _status.text = "BLOCKED：区域快照类型不符"
        return
    var snapshot: Dictionary = value
    if not bool(snapshot.get("loaded", false)) \
            or int(snapshot.get("confirm_count", 0)) < 1 \
            or str(snapshot.get("last_confirmed", "")).is_empty():
        _status.text = "尚无确认过的合成目标。请先完成灰盒交互；不会自动触发事件。"
        return
    _last_region_confirm = StringName(str(snapshot["last_confirmed"]))
    synthetic_region_confirmation.emit(_last_region_confirm)
    # No mapping from target IDs to PR #18 events is approved.
    # This is explicit menu navigation to a separate fixture graph.
    open_module("event")


func _build_event() -> void:
    _stage.add_child(_make_label(
        "PR #18：只读 Python 3.12+ 预览器依赖 PR #9 校验器，未在 Godot 执行。"
        + "此页只读取完全相同的三个公开 JSON fixture，以独立 GDScript "
        + "显示可选动作；checker_status 永远是 NOT_RUN。"))
    var loaded: Dictionary = _event_model.load_fixtures()
    if not loaded.get("ok", false):
        _blocked(str(loaded.get("reason", "事件数据不可用")))
        return
    var selector := OptionButton.new()
    selector.name = "EventChoices"
    _event_choice = selector
    _stage.add_child(selector)
    _button(_stage, "ChooseEvent", "确认选项（仅修改本页临时预览路径）",
        Callable(self, "_choose_event"))
    _button(_stage, "ResetEvent", "从 EVENT_START 重新预览",
        Callable(self, "_reset_event"))
    _button(_stage, "GoSaves", "前往只读存档浏览（不写入事件）",
        Callable(self, "open_module").bind("saves"))
    _render_event()


func _render_event() -> void:
    var state: Dictionary = _event_model.state()
    _event_snapshot = state.duplicate(true)
    if _event_choice == null:
        return
    _event_choice.clear()
    for option in state["choices"]:
        _event_choice.add_item(str(option["id"]) + " → " \
            + str(option["next"] if option["next"] != null else "TERMINAL"))
    if _event_choice.item_count > 0:
        _event_choice.select(0)
    var steps: Array = state["trace"]
    var path_lines: Array[String] = []
    for item in steps:
        path_lines.append(str(item["from"]) + " [" + str(item["choice"])
            + "] → " + ("TERMINAL" if item["to"] == "" else str(item["to"])))
    _status.text = "事件：" + ("TERMINAL" if state["terminal"] else str(state["event_id"])) \
        + " | Python 校验：NOT_RUN | 不产生任何游戏状态变化\n" \
        + ("\n".join(path_lines) if not path_lines.is_empty() else "等待选择")
    _event_choice.disabled = _event_choice.item_count == 0


func _choose_event() -> void:
    if _event_choice == null or _event_choice.selected < 0:
        _status.text = "当前无可选择事件动作；事件可能已终止。"
        return
    var state: Dictionary = _event_model.state()
    var i: int = _event_choice.selected
    if i >= state["choices"].size():
        _status.text = "候选选项已变化；请刷新。"
        return
    var action_id: String = state["choices"][i]["id"]
    var result: Dictionary = _event_model.choose(action_id)
    if not result.get("ok", false):
        _status.text = "选择被拒绝：" + str(result.get("reason", "未知"))
        return
    synthetic_event_choice.emit(action_id)
    _render_event()


func _reset_event() -> void:
    if not _event_model.reset():
        _status.text = "BLOCKED：事件模型未加载"
        return
    _render_event()


func _build_saves() -> void:
    _stage.add_child(_make_label(
        "PR #20：只读快照浏览。只有手工输入 user:// 目录并点击候选检查按钮才读取。"
        + "不会自动扫描、创建、修改、覆盖或导出存档。"))
    var attached: Dictionary = _mount_control(STATE_SCENE)
    if not attached.get("ok", false):
        _blocked(str(attached.get("reason", "只读浏览不可用")))
        return
    var browser: Node = attached["node"]
    if not browser.has_method("_inspect_pressed"):
        _status.text = "BLOCKED：PR #20 的浏览入口与核对结果不一致"
        browser.queue_free()
        return
    _instance = browser
    _status.text = "固定只读候选组件已装配；没有预填个人目录，也不承诺存在任何存档。"


func _build_characters() -> void:
    _stage.add_child(_make_label("PR #21：仅加载其公开合成资料列表、详情与返回。"))
    var attached: Dictionary = _mount_control(CHAR_SCENE)
    if not attached.get("ok", false):
        _blocked(str(attached.get("reason", "资料列表不可用")))
        return
    var widget: Node = attached["node"]
    if not widget.has_method("load_placeholder_profiles") \
            or not widget.has_signal("exit_requested"):
        _status.text = "BLOCKED：PR #21 合成资料装配接口缺失"
        widget.queue_free()
        return
    widget.connect("exit_requested", Callable(self, "return_menu"))
    if not bool(widget.call("load_placeholder_profiles")):
        _status.text = "BLOCKED：合成资料未通过候选加载器；没有使用真实角色数据"
        widget.queue_free()
        return
    _instance = widget
    _status.text = "仅本地合成资料；列表/详情状态由 PR #21 隔离副本管理。"


func _build_input() -> void:
    _stage.add_child(_make_label(
        "PR #19：使用其真实输入配置 backend 的 preview/rebind_memory/restore_defaults_memory。"
        + "所有磁盘保存、迁移、外部路由和 InputMap 入口均不在此页提供。"))
    _selected_action = OptionButton.new()
    _selected_action.name = "InputAction"
    for action_id in ACTION_IDS:
        _selected_action.add_item(action_id)
    _stage.add_child(_selected_action)
    _selected_key = OptionButton.new()
    _selected_key.name = "InputKey"
    for code in KEY_CHOICES:
        _selected_key.add_item(str(_input_backend.key_label(code)))
    _stage.add_child(_selected_key)
    _button(_stage, "PreviewInput", "预览冲突（不修改）",
        Callable(self, "_input_preview"))
    _button(_stage, "ApplyInput", "仅内存确认重绑定",
        Callable(self, "_input_apply"))
    _button(_stage, "ResetInput", "仅内存恢复默认",
        Callable(self, "_input_reset"))
    _refresh_input_status("未操作")


func _input_selection() -> Dictionary:
    if _selected_action == null or _selected_key == null:
        return {"ok": false}
    var a: int = _selected_action.selected
    var k: int = _selected_key.selected
    if a < 0 or a >= ACTION_IDS.size() or k < 0 or k >= KEY_CHOICES.size():
        return {"ok": false}
    return {"ok": true, "action": StringName(ACTION_IDS[a]),
        "keycode": int(KEY_CHOICES[k])}


func _refresh_input_status(message: String) -> void:
    var profile: Dictionary = _input_backend.profile()
    var rows: Array[String] = []
    for item in profile.get("bindings", []):
        if typeof(item) == TYPE_DICTIONARY:
            rows.append(str(item.get("action_id", "")) + " → " \
                + str(_input_backend.key_label(int(item.get("keycode", -1)))))
    _status.text = "仅内存配置 / 无游戏路由 / 无文件写入\n" \
        + message + "\n" + "\n".join(rows)


func _input_preview() -> void:
    var v: Dictionary = _input_selection()
    if not v.get("ok", false):
        _refresh_input_status("选择无效")
        return
    var result: Dictionary = _input_backend.preview(v["action"], v["keycode"])
    _refresh_input_status("预览：" + str(result.get("code", "INVALID")) \
        + " / " + str(result.get("message", "")))


func _input_apply() -> void:
    var v: Dictionary = _input_selection()
    if not v.get("ok", false):
        _refresh_input_status("选择无效")
        return
    var preview: Dictionary = _input_backend.preview(v["action"], v["keycode"])
    if not bool(preview.get("can_apply", false)):
        _refresh_input_status("拒绝：" + str(preview.get("message", "冲突或无效")))
        return
    var result: Dictionary = _input_backend.rebind_memory(v["action"], v["keycode"])
    _refresh_input_status("内存变更：" + str(result.get("code", "INVALID")))


func _input_reset() -> void:
    var outcome: Dictionary = _input_backend.restore_defaults_memory()
    _refresh_input_status("恢复结果：" + str(outcome.get("code", "UNKNOWN")))

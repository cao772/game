extends Control
## GAME-WEB-CONTINUE-REGION-003 / public fixture-only demo.
## No world objects, gameplay events, saves, or official shared interfaces.

const PlaceholderCatalog = preload("res://placeholder_catalog_candidate.gd")

@onready var prompt = $InteractionPromptCandidate
@onready var status_label: Label = $DemoPanel/StatusLabel
@onready var focus_label: Label = $DemoPanel/FocusStateLabel
@onready var target_a: Button = $DemoPanel/TargetAButton
@onready var target_b: Button = $DemoPanel/TargetBButton
@onready var multi_button: Button = $DemoPanel/MultiTargetButton
@onready var reorder_button: Button = $DemoPanel/ReorderButton
@onready var reduce_button: Button = $DemoPanel/ReduceButton
@onready var replace_button: Button = $DemoPanel/ReplaceButton
@onready var focus_host_button: Button = $DemoPanel/FocusHostButton
@onready var cycle_button: Button = $DemoPanel/CycleTargetButton
@onready var style_button: Button = $DemoPanel/StyleButton
@onready var hide_button: Button = $DemoPanel/HideButton

var _events: int = 0
var _high_contrast: bool = false
var _catalog: Dictionary = {}
var _catalog_error: String = ""


func _ready() -> void:
    _catalog = PlaceholderCatalog.load_catalog()
    if not _catalog.get("ok", false):
        _catalog_error = str(_catalog.get("error", "Unknown fixture error"))

    target_a.pressed.connect(_show_a)
    target_b.pressed.connect(_show_b)
    multi_button.pressed.connect(_show_multi)
    reorder_button.pressed.connect(_reorder)
    reduce_button.pressed.connect(_reduce)
    replace_button.pressed.connect(_replace)
    focus_host_button.pressed.connect(_focus_host)
    cycle_button.pressed.connect(_cycle)
    style_button.pressed.connect(_toggle_style)
    hide_button.pressed.connect(_hide)

    prompt.interaction_requested.connect(_on_interaction_requested)
    prompt.prompt_visibility_changed.connect(_on_visibility_changed)
    prompt.focus_state_changed.connect(_on_focus_state_changed)
    prompt.placeholder_changed.connect(_on_placeholder_changed)
    prompt.target_list_changed.connect(_on_target_list_changed)
    prompt.prompt_state_changed.connect(_on_prompt_state_changed)

    status_label.text = (
        "占位数据读取失败：" + _catalog_error
        if not _catalog_error.is_empty()
        else "占位数据就绪；不涉及游戏世界状态。"
    )
    _refresh_state()


func _set_message(message: String) -> void:
    status_label.text = message


func _show_a() -> void:
    if not prompt.show_for_target(&"placeholder_a", "占位目标 A", "确认 A"):
        _set_message("显示 A 被拒绝")
    _refresh_state()


func _show_b() -> void:
    if not prompt.show_for_target(&"placeholder_b", "占位目标 B", "确认 B"):
        _set_message("显示 B 被拒绝")
    _refresh_state()


func _read_set(name: String) -> Array:
    if not _catalog_error.is_empty():
        _set_message("无法读取占位数据：" + _catalog_error)
        return []
    return PlaceholderCatalog.get_set(_catalog, name)


func _show_multi() -> void:
    var items: Array = _read_set("initial")
    if items.is_empty():
        return
    if not prompt.show_for_targets(items, 0):
        _set_message("显示多目标被拒绝")
    _refresh_state()


func _reorder() -> void:
    var items: Array = _read_set("reordered")
    if items.is_empty():
        return
    if not prompt.synchronize_targets(items):
        _set_message("请先显示目标列表")
    else:
        _set_message("已按目标 ID 保持选择并更新排序（无交互请求）")
    _refresh_state()


func _reduce() -> void:
    var items: Array = _read_set("reduced")
    if items.is_empty():
        return
    if not prompt.synchronize_targets(items):
        _set_message("请先显示目标列表")
    else:
        _set_message("列表已精简；移除当前目标时按旧索引回退")
    _refresh_state()


func _replace() -> void:
    var items: Array = _read_set("alternate")
    if items.is_empty():
        return
    if not prompt.synchronize_targets(items, &"placeholder_e"):
        _set_message("请先显示目标列表")
    else:
        _set_message("列表已替换并尝试优先选择占位目标 E")
    _refresh_state()


func _focus_host() -> void:
    target_a.grab_focus()
    _set_message("焦点已尝试转移至宿主控件（仅测试展示）")
    _refresh_state()


func _cycle() -> void:
    if not prompt.cycle_target(1):
        _set_message("切换不可用：请先显示至少两个目标")
    _refresh_state()


func _toggle_style() -> void:
    var selected: StringName = &"high_contrast" if not _high_contrast else &"default"
    if prompt.apply_style_preset(selected):
        _high_contrast = not _high_contrast
        style_button.text = "切换样式：默认" if _high_contrast else "切换样式：高对比"
    else:
        _set_message("样式配置被拒绝")
    _refresh_state()


func _hide() -> void:
    prompt.hide_prompt()
    _refresh_state()


func _on_interaction_requested(target_id: StringName) -> void:
    _events += 1
    _set_message("第 %d 次请求：%s（仅信号，无状态写入）" % [
        _events, str(target_id)
    ])
    _refresh_state()


func _on_visibility_changed(_shown: bool) -> void:
    _refresh_state()


func _on_focus_state_changed(_role: StringName) -> void:
    _refresh_state()


func _on_placeholder_changed(_target_id: StringName) -> void:
    _refresh_state()


func _on_target_list_changed(_count: int) -> void:
    _refresh_state()


func _on_prompt_state_changed(_snapshot: Dictionary) -> void:
    _refresh_state()


func _refresh_state() -> void:
    # Reads current state instead of assuming signal order or stale IDs.
    var state: Dictionary = prompt.state_snapshot()
    focus_label.text = (
        "状态修订=%d | 可见=%s | 焦点=%s\n选中=%s | 位置=%d/%d | 请求=%d"
        % [
            int(state["revision"]),
            str(state["shown"]),
            str(state["focus_role"]),
            str(state["target_id"]),
            int(state["target_index"]) + 1 if state["shown"] else 0,
            int(state["target_count"]),
            int(state["request_count"])
        ]
    )

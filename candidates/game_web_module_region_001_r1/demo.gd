extends Control
## Isolated UI demo using public placeholders only; no existing game scene.

@onready var prompt = $InteractionPromptCandidate
@onready var status_label: Label = $DemoPanel/StatusLabel
@onready var focus_label: Label = $DemoPanel/FocusStateLabel
@onready var target_a: Button = $DemoPanel/TargetAButton
@onready var target_b: Button = $DemoPanel/TargetBButton
@onready var multi_button: Button = $DemoPanel/MultiTargetButton
@onready var cycle_button: Button = $DemoPanel/CycleTargetButton
@onready var style_button: Button = $DemoPanel/StyleButton
@onready var hide_button: Button = $DemoPanel/HideButton

var _events: int = 0
var _high_contrast: bool = false


func _ready() -> void:
    target_a.pressed.connect(_show_a)
    target_b.pressed.connect(_show_b)
    multi_button.pressed.connect(_show_multi)
    cycle_button.pressed.connect(_cycle)
    style_button.pressed.connect(_toggle_style)
    hide_button.pressed.connect(_hide)

    prompt.interaction_requested.connect(_on_interaction_requested)
    prompt.prompt_visibility_changed.connect(_on_visibility_changed)
    prompt.focus_state_changed.connect(_on_focus_state_changed)
    prompt.placeholder_changed.connect(_on_placeholder_changed)
    prompt.target_list_changed.connect(_on_target_list_changed)

    status_label.text = "仅占位目标。无游戏状态、叙事或存档行为。"
    _refresh_focus_label()


func _show_a() -> void:
    prompt.show_for_target(&"placeholder_a", "占位目标 A", "确认 A")
    _refresh_focus_label()


func _show_b() -> void:
    prompt.show_for_target(&"placeholder_b", "占位目标 B", "确认 B")
    _refresh_focus_label()


func _show_multi() -> void:
    prompt.show_for_targets([
        {"id": &"placeholder_a", "label": "占位目标 A", "action_caption": "确认 A"},
        {"id": &"placeholder_b", "label": "占位目标 B", "action_caption": "确认 B"},
        {"id": &"placeholder_c", "label": "占位目标 C", "action_caption": "确认 C"}
    ], 0)
    _refresh_focus_label()


func _cycle() -> void:
    prompt.cycle_target(1)
    _refresh_focus_label()


func _toggle_style() -> void:
    var selected: StringName = &"high_contrast" if not _high_contrast else &"default"
    if prompt.apply_style_preset(selected):
        _high_contrast = not _high_contrast
        style_button.text = "切换样式：默认" if _high_contrast else "切换样式：高对比"


func _hide() -> void:
    prompt.hide_prompt()
    _refresh_focus_label()


func _on_interaction_requested(target_id: StringName) -> void:
    _events += 1
    status_label.text = "第 %d 次请求：%s（只发信号）" % [_events, str(target_id)]


func _on_visibility_changed(shown: bool) -> void:
    if not shown:
        status_label.text = "提示已隐藏；请求累计 %d。" % _events
    _refresh_focus_label()


func _on_focus_state_changed(_role: StringName) -> void:
    _refresh_focus_label()


func _on_placeholder_changed(_target_id: StringName) -> void:
    _refresh_focus_label()


func _on_target_list_changed(_count: int) -> void:
    _refresh_focus_label()


func _refresh_focus_label() -> void:
    var state: Dictionary = prompt.focus_state()
    focus_label.text = "焦点=%s | 可见=%s | 目标=%s | 索引=%d/%d" % [
        str(state["role"]),
        str(state["shown"]),
        str(state["target_id"]),
        int(state["target_index"]) + 1 if state["shown"] else 0,
        int(state["target_count"])
    ]

extends Control
## Standalone UI-only placeholder demonstration, NOT a game scene.

@onready var prompt = $InteractionPromptCandidate
@onready var status_label: Label = $DemoPanel/StatusLabel
@onready var target_a: Button = $DemoPanel/TargetAButton
@onready var target_b: Button = $DemoPanel/TargetBButton
@onready var hide_button: Button = $DemoPanel/HideButton

var _events: int = 0


func _ready() -> void:
    target_a.pressed.connect(_show_a)
    target_b.pressed.connect(_show_b)
    hide_button.pressed.connect(_hide)
    prompt.interaction_requested.connect(_on_interaction_requested)
    prompt.prompt_visibility_changed.connect(_on_visibility_changed)
    status_label.text = "仅技术占位；选择目标 A 或 B 以显示提示。"


func _show_a() -> void:
    prompt.show_for_target(&"placeholder_a", "占位目标 A", "执行占位交互")


func _show_b() -> void:
    prompt.show_for_target(&"placeholder_b", "占位目标 B", "执行占位交互")


func _hide() -> void:
    prompt.hide_prompt()


func _on_interaction_requested(target_id: StringName) -> void:
    _events += 1
    status_label.text = "请求 %d：%s（仅信号，不更改世界状态）" % [
        _events, str(target_id)
    ]


func _on_visibility_changed(shown: bool) -> void:
    if not shown:
        status_label.text = "提示已隐藏；占位请求累计 %d。" % _events

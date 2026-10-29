extends Control
## Standalone synthetic host; dynamic fixed-path Flow load with visible fallback.
## No arbitrary resource path or shell control. NOT_RUN.

const FLOW_SCENE_PATH := "res://profile_flow_candidate.tscn"

var _flow: Control = null

@onready var _host: MarginContainer = $Host
@onready var _fallback: Label = $Host/Fallback
@onready var _retry: Button = $Toolbar/RetryFlow
@onready var _exit_notice: Label = $ExitNotice


func _ready() -> void:
    _retry.pressed.connect(reload_flow)
    _retry.focus_mode = Control.FOCUS_ALL
    _retry.tooltip_text = "重新读取固定的本地合成资料导航组件"
    reload_flow()


func _set_failure(message: String) -> void:
    _fallback.text = message
    _fallback.visible = true
    _exit_notice.visible = false


func _unmount() -> void:
    if _flow != null and is_instance_valid(_flow):
        if _flow.get_parent() != null:
            _flow.get_parent().remove_child(_flow)
        _flow.queue_free()
    _flow = null


func reload_flow() -> bool:
    _unmount()
    if not ResourceLoader.exists(FLOW_SCENE_PATH, "PackedScene"):
        _set_failure("占位浏览组件文件缺失；可重试。")
        return false
    var source: Resource = ResourceLoader.load(
        FLOW_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
    )
    if not source is PackedScene:
        _set_failure("占位浏览场景格式无效；可重试。")
        return false
    var node: Node = (source as PackedScene).instantiate()
    if not node is Control:
        if node != null:
            node.free()
        _set_failure("占位浏览场景根节点无效；可重试。")
        return false
    for required_method in ["load_placeholder_profiles", "set_profiles", "go_back"]:
        if not node.has_method(required_method):
            node.free()
            _set_failure("占位浏览组件接口不完整；可重试。")
            return false
    if not node.has_signal("exit_requested"):
        node.free()
        _set_failure("占位浏览组件缺少退出信号；可重试。")
        return false

    _flow = node as Control
    _flow.name = "Flow"
    _flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _host.add_child(_flow)
    _host.move_child(_flow, 0)
    _flow.connect("exit_requested", Callable(self, "_on_exit_requested"))
    _fallback.visible = false
    _exit_notice.visible = false
    # Fixed synthetic fixture only; failures are visibly handled within Flow.
    _flow.call("load_placeholder_profiles")
    return true


func _on_exit_requested() -> void:
    if _flow != null and is_instance_valid(_flow):
        _flow.hide()
    _exit_notice.show()

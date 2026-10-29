extends Control
## Standalone synthetic demonstration: no real characters or external shell.

@onready var _flow = $Flow
@onready var _exit_notice: Label = $ExitNotice


func _ready() -> void:
    _flow.exit_requested.connect(_on_exit_requested)
    _flow.load_placeholder_profiles()


func _on_exit_requested() -> void:
    _flow.hide()
    _exit_notice.show()

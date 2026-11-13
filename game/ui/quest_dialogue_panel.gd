extends VBoxContainer
## A reusable player-facing panel. It never infers or grants world observations.

const Application = preload("res://runtime/quest_application.gd")
signal command_finished(result: Dictionary)

var _application: Application = null
var _epoch: int = 0
var _busy: bool = false
var _speaker: Label
var _body: Label
var _notice: Label
var _choices: VBoxContainer


func bind_application(application: Application) -> void:
	_application = application
	_epoch += 1
	_ensure_ui()
	refresh()


func refresh() -> void:
	_ensure_ui()
	_clear_choices()
	if not is_instance_valid(_application):
		_speaker.text = ""
		_body.text = ""
		_notice.text = "对话暂不可用。"
		return
	var view: Dictionary = _application.present()
	if not view.get("ok", false):
		_speaker.text = ""
		_body.text = ""
		_notice.text = "对话暂不可用。"
		return
	_speaker.text = view["speaker"]
	_body.text = view["text"]
	if not view["started"]:
		_add_button("开始任务", _on_start.bind(view["revision"], _epoch))
	else:
		for option in view["options"]:
			_add_button(option["text"], _on_choice.bind(option["action_id"], option["revision"], _epoch))
	if view["terminal"]:
		_notice.text = "任务已完成。"
	elif view["started"] and view["options"].is_empty():
		_notice.text = "暂时没有可选行动，可以先探索附近。"
	else:
		_notice.text = ""


func _ensure_ui() -> void:
	if is_instance_valid(_choices):
		return
	_speaker = Label.new()
	_speaker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_speaker)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_choices = VBoxContainer.new()
	add_child(_choices)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_notice)


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _add_button(caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	_choices.add_child(button)


func _can_submit(epoch: int) -> bool:
	return not _busy and epoch == _epoch and is_instance_valid(_application) and is_inside_tree() and is_visible_in_tree() and not get_tree().paused


func _on_start(revision: int, epoch: int) -> void:
	if not _can_submit(epoch):
		return
	_busy = true
	_complete(_application.start(revision))


func _on_choice(action_id: String, revision: int, epoch: int) -> void:
	if not _can_submit(epoch):
		return
	_busy = true
	_complete(_application.choose(action_id, revision))


func _complete(result: Dictionary) -> void:
	refresh()
	if not result.get("ok", false):
		_notice.text = "情况已经变化，请重新选择。" if result.get("code") == "STALE_PRESENTATION" else "这项行动暂时无法完成。"
	# A listener may navigate/rebind; the old buttons already left the scene tree.
	command_finished.emit(result.duplicate(true))
	_busy = false

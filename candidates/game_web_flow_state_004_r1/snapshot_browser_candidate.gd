extends Control
## GAME-WEB-FLOW-STATE-004 r1 — isolated, read-only Godot UI candidate.
## No save/write/rename/delete/export/clipboard/network/command functions.
## No automatic scan. No live runtime connection. NOT_RUN / Canon N/A.

const BrowserModel = preload("res://snapshot_browser_model_candidate.gd")

var _model = BrowserModel.new()
var _left_folder: LineEdit
var _right_folder: LineEdit
var _mode: OptionButton
var _phase: OptionButton
var _door_open: CheckBox
var _tabs: TabContainer
var _inspect_output: TextEdit
var _compare_output: TextEdit
var _preview_output: TextEdit


func _ready() -> void:
	_build_interface()
	_reset_reports()


func _make_label(container: Node, text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)
	return label


func _make_folder_input(container: Node, title: String) -> LineEdit:
	var row := HBoxContainer.new()
	container.add_child(row)
	var caption := Label.new()
	caption.text = title
	caption.custom_minimum_size = Vector2(150, 0)
	row.add_child(caption)
	var entry := LineEdit.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.placeholder_text = "user://独立目录（手动输入，不自动读取）"
	entry.clear_button_enabled = true
	row.add_child(entry)
	entry.text_changed.connect(_on_folder_changed)
	return entry


func _make_button(container: Node, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	container.add_child(button)
	button.pressed.connect(callback)


func _make_output(name_value: String) -> TextEdit:
	var output := TextEdit.new()
	output.name = name_value
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.custom_minimum_size = Vector2(0, 230)
	_tabs.add_child(output)
	return output


func _build_interface() -> void:
	var panel := MarginContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 20)
	panel.add_theme_constant_override("margin_right", 20)
	panel.add_theme_constant_override("margin_top", 16)
	panel.add_theme_constant_override("margin_bottom", 16)
	add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)

	var heading := Label.new()
	heading.text = "快照只读浏览 · W-FLOW-STATE-004"
	heading.add_theme_font_size_override("font_size", 23)
	stack.add_child(heading)
	_make_label(
		stack,
		"独立技术候选 · NOT_RUN · 不保存、不恢复、不执行迁移；"
		+ "只读取指定模式的固定文件名"
	)

	_left_folder = _make_folder_input(stack, "目录 A（检查）")
	_right_folder = _make_folder_input(stack, "目录 B（比较）")

	var mode_row := HBoxContainer.new()
	stack.add_child(mode_row)
	_make_label(mode_row, "存档模式")
	_mode = OptionButton.new()
	_mode.custom_minimum_size = Vector2(135, 0)
	_mode.add_item("story")
	_mode.add_item("free")
	_mode.select(0)
	_mode.item_selected.connect(_on_mode_changed)
	mode_row.add_child(_mode)
	_make_label(
		mode_row,
		"仅按 mode 查找 story.round_snapshot.json / "
		+ "free.round_snapshot.json"
	)

	var actions := HBoxContainer.new()
	stack.add_child(actions)
	_make_button(actions, "检查 A", _inspect_pressed)
	_make_button(actions, "比较 A / B", _compare_pressed)
	_make_button(actions, "仅检查迁移需求", _preview_none_pressed)

	var proposal := HBoxContainer.new()
	stack.add_child(proposal)
	_make_label(proposal, "假设状态（仅供预览）")
	_phase = OptionButton.new()
	for phase in BrowserModel.PHASES:
		_phase.add_item(phase)
	_phase.select(0)
	_phase.item_selected.connect(_on_phase_changed)
	proposal.add_child(_phase)

	_door_open = CheckBox.new()
	_door_open.text = "假设 door_open = true"
	_door_open.button_pressed = false
	_door_open.toggled.connect(_on_door_changed)
	proposal.add_child(_door_open)
	_make_button(proposal, "预览状态差异（不应用）", _preview_candidate_pressed)

	_make_label(
		stack,
		"下方仅显示脱敏报告；不显示 round_id、JSON 原文、哈希或路径。"
		+ " 文件在两次读取之间可能变化，比较不是事务。"
	)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_tabs)
	_inspect_output = _make_output("校验与版本")
	_compare_output = _make_output("两文件差异")
	_preview_output = _make_output("迁移预览")

	var footer := Label.new()
	footer.text = (
		"禁止写入与迁移 · 未知版本仅提示缺少映射 · "
		+ "正常检查不代表正史或共享接口已批准"
	)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(footer)


func _current_mode() -> String:
	if _mode == null or _mode.selected < 0:
		return ""
	return _mode.get_item_text(_mode.selected)


func _current_phase() -> String:
	if _phase == null or _phase.selected < 0:
		return ""
	return _phase.get_item_text(_phase.selected)


func _render(output: TextEdit, data: Dictionary, tab_index: int) -> void:
	# Only model APIs that exclude raw snapshot payloads are used here.
	# JSON.stringify output is NOT sent to stdout, clipboard or disk.
	output.text = JSON.stringify(data, "\t", true, true)
	_tabs.current_tab = tab_index


func _reset_reports() -> void:
	if _inspect_output == null:
		return
	_inspect_output.text = "尚未检查（仅手动触发）。"
	_compare_output.text = "尚未比较（仅手动触发）。"
	_preview_output.text = "尚未预览（不执行迁移）。"


func _on_folder_changed(_new_value: String) -> void:
	_reset_reports()


func _on_mode_changed(_index: int) -> void:
	_reset_reports()


func _on_phase_changed(_index: int) -> void:
	if _preview_output != null:
		_preview_output.text = "假设状态已变化，请重新点击预览。"


func _on_door_changed(_checked: bool) -> void:
	if _preview_output != null:
		_preview_output.text = "假设状态已变化，请重新点击预览。"


func _inspect_pressed() -> void:
	var result: Dictionary = _model.inspect_folder(
		_left_folder.text, _current_mode()
	)
	_render(_inspect_output, result, 0)


func _compare_pressed() -> void:
	var result: Dictionary = _model.compare_folders(
		_left_folder.text, _right_folder.text, _current_mode()
	)
	_render(_compare_output, result, 1)


func _preview_none_pressed() -> void:
	var result: Dictionary = _model.preview_without_target(
		_left_folder.text, _current_mode()
	)
	_render(_preview_output, result, 2)


func _preview_candidate_pressed() -> void:
	var result: Dictionary = _model.preview_candidate(
		_left_folder.text,
		_current_mode(),
		_current_phase(),
		_door_open.button_pressed
	)
	_render(_preview_output, result, 2)

extends Control
## GAME-WEB-PLAY-STATE-005 r1 — standalone read-only Godot browser view.
## No save, delete, export, load-at-startup, external command or runtime API.
## Uses only sanitized model responses plus allowlisted presenter. NOT_RUN.

const BrowserModel = preload("res://snapshot_browser_model_candidate.gd")
const Presenter = preload("res://snapshot_report_presenter_candidate.gd")

var _model = BrowserModel.new()
var _presenter = Presenter.new()
var _left_folder: LineEdit
var _right_folder: LineEdit
var _mode: OptionButton
var _phase: OptionButton
var _door_open: CheckBox
var _tabs: TabContainer
var _inspect_output: TextEdit
var _compare_output: TextEdit
var _preview_output: TextEdit
var _status_label: Label


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
	caption.custom_minimum_size = Vector2(145, 0)
	row.add_child(caption)
	var input := LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "user://某个独立文件夹（仅按固定文件名读取）"
	input.clear_button_enabled = true
	input.tooltip_text = "本地手动输入，不上传、不自动搜索；输入路径自身不会写入报告"
	input.text_changed.connect(_on_folder_changed)
	row.add_child(input)
	return input


func _make_button(container: Node, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(callback)
	container.add_child(button)


func _make_output(name_value: String) -> TextEdit:
	var output := TextEdit.new()
	output.name = name_value
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output.custom_minimum_size = Vector2(0, 255)
	_tabs.add_child(output)
	return output


func _build_interface() -> void:
	var panel := MarginContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 18)
	panel.add_theme_constant_override("margin_right", 18)
	panel.add_theme_constant_override("margin_top", 14)
	panel.add_theme_constant_override("margin_bottom", 14)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(760, 690)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	scroll.add_child(stack)

	var title := Label.new()
	title.text = "存档快照 · 只读校验与迁移预览"
	title.add_theme_font_size_override("font_size", 24)
	stack.add_child(title)
	_make_label(
		stack,
		"独立研发候选 · NOT_RUN / 未验收 · 只读，不备份、不保存、不恢复、不迁移。"
	)

	_left_folder = _make_folder_input(stack, "目录 A（检查）")
	_right_folder = _make_folder_input(stack, "目录 B（比较）")

	var mode_row := HBoxContainer.new()
	stack.add_child(mode_row)
	_make_label(mode_row, "固定模式")
	_mode = OptionButton.new()
	_mode.custom_minimum_size = Vector2(140, 0)
	_mode.add_item("story")
	_mode.add_item("free")
	_mode.select(0)
	_mode.item_selected.connect(_on_mode_changed)
	mode_row.add_child(_mode)
	_make_label(mode_row, "仅按所选模式读取对应的 .round_snapshot.json")

	var buttons := HBoxContainer.new()
	stack.add_child(buttons)
	_make_button(buttons, "校验目录 A", _inspect_pressed)
	_make_button(buttons, "比较 A 与 B 的版本及差异", _compare_pressed)
	_make_button(buttons, "查看迁移需求（不执行）", _preview_none_pressed)

	var proposal := HBoxContainer.new()
	stack.add_child(proposal)
	_make_label(proposal, "假设字段（仅预览）")
	_phase = OptionButton.new()
	for candidate_phase in BrowserModel.PHASES:
		_phase.add_item(candidate_phase)
	_phase.select(0)
	_phase.item_selected.connect(_on_phase_changed)
	proposal.add_child(_phase)
	_door_open = CheckBox.new()
	_door_open.text = "假设 door_open = true"
	_door_open.button_pressed = false
	_door_open.toggled.connect(_on_door_changed)
	proposal.add_child(_door_open)
	_make_button(proposal, "预览假设差异", _preview_candidate_pressed)

	_status_label = _make_label(
		stack,
		"当前：尚未检查。操作需手动触发；更改路径、模式会清除旧报告。"
	)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_tabs)
	_inspect_output = _make_output("校验及版本")
	_compare_output = _make_output("字段差异")
	_preview_output = _make_output("迁移预览")

	_make_label(
		stack,
		"报告仅包含允许的状态、错误代码和字段名；不会显示源 JSON、"
		+ "回合标识、哈希或源字段值。时间、版本与剧情规则均不作推断。"
	)


func _current_mode() -> String:
	if _mode == null or _mode.selected < 0:
		return ""
	return _mode.get_item_text(_mode.selected)


func _current_phase() -> String:
	if _phase == null or _phase.selected < 0:
		return ""
	return _phase.get_item_text(_phase.selected)


func _reset_reports() -> void:
	if _inspect_output == null:
		return
	_inspect_output.text = "尚未检查（需要手动点击）。"
	_compare_output.text = "尚未比较（需要手动点击）。"
	_preview_output.text = "尚未预览（任何结果都不能应用）。"
	if _status_label != null:
		_status_label.text = "上下文已变更：原报告清空，等待手动检查。"


func _show(
	output: TextEdit, formatted: String, tab_index: int, is_blocked: bool
) -> void:
	# Only the allowlisted presenter is permitted to format display data.
	output.text = formatted
	_tabs.current_tab = tab_index
	if is_blocked:
		_status_label.text = "当前操作已阻断；源文件未修改。"
	else:
		_status_label.text = "只读报告已更新；源文件未修改，结果不构成迁移批准。"


func _on_folder_changed(_new_value: String) -> void:
	_reset_reports()


func _on_mode_changed(_index: int) -> void:
	_reset_reports()


func _on_phase_changed(_index: int) -> void:
	if _preview_output != null:
		_preview_output.text = "假设字段已改变，请重新点击预览。"
		_status_label.text = "假设字段已修改：旧预览作废。"


func _on_door_changed(_checked: bool) -> void:
	if _preview_output != null:
		_preview_output.text = "假设字段已改变，请重新点击预览。"
		_status_label.text = "假设字段已修改：旧预览作废。"


func _inspect_pressed() -> void:
	var result: Dictionary = _model.inspect_folder(
		_left_folder.text, _current_mode()
	)
	var blocked := result.has("status")
	_show(_inspect_output, _presenter.inspection(result), 0, blocked)


func _compare_pressed() -> void:
	var result: Dictionary = _model.compare_folders(
		_left_folder.text, _right_folder.text, _current_mode()
	)
	_show(
		_compare_output, _presenter.comparison(result), 1,
		result.get("status", "") != "comparable_v1"
	)


func _preview_none_pressed() -> void:
	var result: Dictionary = _model.preview_without_target(
		_left_folder.text, _current_mode()
	)
	_show(
		_preview_output, _presenter.preview(result), 2,
		["blocked", "mapping_required", "invalid_request", "source_unstable"].has(
			result.get("status", "")
		)
	)


func _preview_candidate_pressed() -> void:
	var result: Dictionary = _model.preview_candidate(
		_left_folder.text, _current_mode(),
		_current_phase(), _door_open.button_pressed
	)
	_show(
		_preview_output, _presenter.preview(result), 2,
		["blocked", "mapping_required", "invalid_request",
			"source_unstable", "invalid_target",
			"protected_field_review_blocked"].has(result.get("status", ""))
	)

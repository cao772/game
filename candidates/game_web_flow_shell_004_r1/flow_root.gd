extends Control
## GAME-WEB-FLOW-SHELL-004 r1 — isolated wrapper for a copy of Draft PR #17.
## Only local pinned copies of #10/#14/#15. No #6 routing or persistence.
## Independent, not approved, and NOT_RUN.

signal flow_step_changed(step_name: String)
signal synthetic_prompt_requested(target_id: StringName)
signal synthetic_binding_changed(action_id: String, keycode: int)

const PromptBridge = preload("res://adapters/prompt_isolated_adapter.gd")
const ProfileBridge = preload("res://adapters/profile_isolated_adapter.gd")
const InputBridge = preload("res://adapters/input_isolated_adapter.gd")
const STEPS := ["prompt", "profile", "bindings"]
const ACTIONS := ["observe", "open_door", "withdraw", "reset_round", "cancel"]
const MAX_HISTORY := 24

var _shell: Node
var _page_container: VBoxContainer
var _body: Label
var _legacy_preview: Button
var _stage: VBoxContainer
var _notice: Label
var _start_button: Button
var _next_button: Button
var _prompt_bridge = PromptBridge.new()
var _profile_bridge = ProfileBridge.new()
var _input_bridge = InputBridge.new()
var _settings: Variant = null
var _mounted: Node = null
var _flow_index: int = -1
var _visible_step: String = ""
var _action_select: OptionButton = null
var _key_select: OptionButton = null
var _configuration_text: Label = null
var _preview_text: Label = null
var _feedback: String = "全部为独立候选，尚未验证。"


func _ready() -> void:
    _shell = get_node("Shell")
    _page_container = _shell.get_node("Frame/Layout/Body/View/Inner/Page")
    _body = _page_container.get_node("PageBody")
    _legacy_preview = _page_container.get_node("PreviewButton")

    _stage = VBoxContainer.new()
    _stage.name = "IsolatedModuleStage"
    _stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _stage.add_theme_constant_override("separation", 10)
    _page_container.add_child(_stage)

    _notice = Label.new()
    _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _notice.add_theme_color_override("font_color", Color("#a8c9f5"))
    _notice.name = "FlowStatus"
    _page_container.add_child(_notice)

    _start_button = Button.new()
    _start_button.name = "StartFlow"
    _start_button.text = "开始合成演示流程"
    _start_button.pressed.connect(begin_flow)
    _page_container.add_child(_start_button)

    _next_button = Button.new()
    _next_button.name = "NextFlow"
    _next_button.text = "下一步（仅占位流程）"
    _next_button.pressed.connect(advance_flow)
    _page_container.add_child(_next_button)

    _shell.connect("page_changed", Callable(self, "_on_page_changed"))
    _shell.connect("assembly_changed", Callable(self, "_on_assembly_changed"))
    _show_current()


func current_flow_step() -> String:
    if _flow_index < 0 or _flow_index >= STEPS.size():
        return ""
    return STEPS[_flow_index]


func begin_flow() -> bool:
    _flow_index = 0
    var ok: bool = bool(_shell.call("show_page", STEPS[0]))
    if not ok:
        _flow_index = -1
    return ok


func advance_flow() -> bool:
    if _flow_index < 0 or _flow_index >= STEPS.size():
        return false
    if _flow_index == STEPS.size() - 1:
        _flow_index = -1
        return bool(_shell.call("show_page", "home"))
    _flow_index += 1
    return bool(_shell.call("show_page", STEPS[_flow_index]))


func show_page(page_id: String) -> bool:
    return bool(_shell.call("show_page", page_id))


func module_status(slot: String) -> Dictionary:
    return _shell.call("module_status", slot)


func _on_page_changed(page: String) -> void:
    if _flow_index >= 0 and page != STEPS[_flow_index]:
        _flow_index = -1
    _show_current()
    flow_step_changed.emit(page)


func _on_assembly_changed(_slot: String, _state: String) -> void:
    _show_current()


func _dispose_stage() -> void:
    if is_instance_valid(_mounted) and _mounted.has_method("hide_prompt"):
        _mounted.call("hide_prompt")
    _mounted = null
    for child in _stage.get_children():
        _stage.remove_child(child)
        child.queue_free()
    _action_select = null
    _key_select = null
    _configuration_text = null
    _preview_text = null


func _show_current() -> void:
    _dispose_stage()
    var page: String = str(_shell.call("current_page"))
    _visible_step = page
    _start_button.visible = page == "home"
    _next_button.visible = _flow_index >= 0 and page == current_flow_step()
    _next_button.text = "完成并返回概览" if page == "bindings" else "继续下一步（合成数据）"

    var supported: bool = STEPS.has(page)
    _stage.visible = false
    _body.visible = true
    if supported:
        # Hide legacy mock button on any bridge page; never silently fall back
        # to an unrelated action when the real local copy is unavailable.
        _legacy_preview.visible = false
    # Restore the original r1 shell's UI for missing/disabled/pending modules.
    if not supported:
        _notice.text = "独立主菜单候选；所有来源 PR 均未获批准。"
        return

    var status: Dictionary = _shell.call("module_status", page)
    if str(status.get("status", "")) != "synthetic_ready":
        _notice.text = "安全降级：" + str(status.get("reason", "缺失依赖"))
        return

    _stage.visible = true
    _body.visible = false
    var result: Dictionary = {"ok": false, "reason": "候选桥接不可用"}
    match page:
        "prompt":
            result = _prompt_bridge.mount(_stage, Callable(self, "_on_prompt_requested"))
        "profile":
            result = _profile_bridge.mount(_stage)
        "bindings":
            result = _mount_bindings()
    if not bool(result.get("ok", false)):
        _stage.visible = false
        _body.visible = true
        _notice.text = "安全降级：" + str(result.get("reason", "未知原因"))
        return

    if result.has("instance") and result["instance"] is Node:
        _mounted = result["instance"]
    _stage.visible = true
    _body.visible = false
    _legacy_preview.visible = false
    _notice.text = "本地候选副本（NOT_RUN）： " + str(result.get("reason", ""))


func _on_prompt_requested(target_id: StringName) -> void:
    # No game event, no save, no PR #6 dispatch.
    _feedback = "已收到合成提示请求：" + str(target_id) + "；未执行玩法操作。"
    _notice.text = _feedback
    synthetic_prompt_requested.emit(target_id)


func _label(text_value: String) -> Label:
    var result := Label.new()
    result.text = text_value
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return result


func _mount_bindings() -> Dictionary:
    if _settings == null:
        var created: Dictionary = _input_bridge.create_settings()
        if not created.get("ok", false):
            return created
        _settings = created["instance"]

    var layout := VBoxContainer.new()
    layout.name = "InputCandidateControls"
    layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation", 8)
    _stage.add_child(layout)

    layout.add_child(_label("PR #15 输入配置隔离副本：仅编辑本进程内存，不绑定键盘路由或游戏事件。"))
    _configuration_text = _label("")
    layout.add_child(_configuration_text)

    layout.add_child(_label("选择逻辑动作"))
    _action_select = OptionButton.new()
    _action_select.name = "ActionSelector"
    for action_id in ACTIONS:
        _action_select.add_item(action_id)
    layout.add_child(_action_select)

    layout.add_child(_label("候选键（先预览冲突，再明确应用）"))
    _key_select = OptionButton.new()
    _key_select.name = "KeySelector"
    for code in InputBridge.KEY_CHOICES:
        _key_select.add_item(str(_settings.call("key_display", code)))
    _key_select.select(5)
    layout.add_child(_key_select)

    var actions := HBoxContainer.new()
    layout.add_child(actions)
    var preview_button := Button.new()
    preview_button.text = "预览更改"
    preview_button.pressed.connect(_preview_binding)
    actions.add_child(preview_button)
    var apply_button := Button.new()
    apply_button.text = "应用（仅内存）"
    apply_button.pressed.connect(_apply_binding)
    actions.add_child(apply_button)
    var reset_button := Button.new()
    reset_button.text = "恢复默认（仅内存）"
    reset_button.pressed.connect(_restore_bindings)
    layout.add_child(reset_button)

    _preview_text = _label("尚未进行按键预览。")
    _preview_text.name = "PreviewFeedback"
    layout.add_child(_preview_text)
    _refresh_bindings_text()
    return {"ok": true, "reason": "PR #15 本地候选输入设置；不加载依赖 #6 的路由器"}


func _selected_binding() -> Dictionary:
    if _action_select == null or _key_select == null:
        return {"ok": false}
    var a: int = _action_select.selected
    var k: int = _key_select.selected
    if a < 0 or a >= ACTIONS.size() or k < 0 or k >= InputBridge.KEY_CHOICES.size():
        return {"ok": false}
    return {
        "ok": true,
        "action": StringName(ACTIONS[a]),
        "keycode": int(InputBridge.KEY_CHOICES[k])
    }


func _refresh_bindings_text() -> void:
    if _configuration_text == null or _settings == null:
        return
    var profile: Variant = _settings.call("current_profile")
    if typeof(profile) != TYPE_DICTIONARY or not profile.has("bindings"):
        _configuration_text.text = "输入配置接口返回无效数据。"
        return
    var lines: Array[String] = ["当前按键（合成演示，不参与实际输入）："]
    for item in profile["bindings"]:
        if typeof(item) == TYPE_DICTIONARY:
            var key_label: String = str(_settings.call("key_display", int(item.get("keycode", -1))))
            lines.append(str(item.get("action_id", "")) + " → " + key_label)
    _configuration_text.text = "\n".join(lines)


func _preview_binding() -> void:
    var selected: Dictionary = _selected_binding()
    if not selected.get("ok", false):
        _preview_text.text = "请选择动作和键位。"
        return
    var feedback: Dictionary = _input_bridge.preview(
        _settings, selected["action"], selected["keycode"])
    var message: String = str(feedback.get("message", feedback.get("reason", "预览失败")))
    if not feedback.get("can_apply", false):
        message += " · 冲突/无效，不能应用"
    else:
        message += " · 可应用（尚未修改）"
    _preview_text.text = message


func _apply_binding() -> void:
    var selected: Dictionary = _selected_binding()
    if not selected.get("ok", false):
        _preview_text.text = "请选择动作和键位。"
        return
    var proposed: Dictionary = _input_bridge.preview(
        _settings, selected["action"], selected["keycode"])
    if not proposed.get("can_apply", false):
        _preview_text.text = "拒绝应用：" + str(proposed.get("message", "冲突或无效键位"))
        return
    var applied: Dictionary = _input_bridge.apply(
        _settings, selected["action"], selected["keycode"])
    _preview_text.text = "仅内存应用：" + str(applied.get("message", "未修改"))
    _refresh_bindings_text()
    if bool(applied.get("ok", false)) and bool(applied.get("changed", false)):
        synthetic_binding_changed.emit(String(selected["action"]), int(selected["keycode"]))


func _restore_bindings() -> void:
    var outcome: Dictionary = _input_bridge.restore(_settings)
    _preview_text.text = "仅内存恢复：" + str(outcome.get("message", "未修改"))
    _refresh_bindings_text()

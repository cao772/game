extends RefCounted
## Flow-Shell-004: PR #15 in-memory settings only; no #6 router and NO IO.
## Never expose load/save/rebind_and_save methods through this bridge.

const LOCAL_SCRIPT := "res://vendor/input/input_settings_controller_candidate.gd"
const KEY_CHOICES := [KEY_1, KEY_2, KEY_3, KEY_R, KEY_ESCAPE,
    KEY_4, KEY_5, KEY_6, KEY_Q, KEY_W, KEY_T, KEY_F1]

func create_settings() -> Dictionary:
    if not ResourceLoader.exists(LOCAL_SCRIPT, "Script"):
        return {"ok": false, "reason": "输入设置脚本缺失"}
    var script: Resource = ResourceLoader.load(LOCAL_SCRIPT, "Script")
    if not script is Script:
        return {"ok": false, "reason": "输入设置资源类型错误"}
    var settings: Variant = (script as Script).new()
    if settings == null:
        return {"ok": false, "reason": "输入设置实例未创建"}
    for method_name in ["current_profile", "preview_rebind", "rebind",
        "restore_defaults", "key_display"]:
        if not settings.has_method(method_name):
            return {"ok": false, "reason": "PR #15 缺少 " + method_name}
    return {"ok": true, "instance": settings, "reason": "仅内存键位配置；无输入派发"}

func preview(settings: Object, action_id: StringName, keycode: int) -> Dictionary:
    if settings == null or not is_instance_valid(settings):
        return {"ok": false, "reason": "输入配置实例缺失"}
    var value: Variant = settings.call("preview_rebind", action_id, keycode)
    if typeof(value) != TYPE_DICTIONARY:
        return {"ok": false, "reason": "预览返回值无效"}
    return (value as Dictionary).duplicate(true)

func apply(settings: Object, action_id: StringName, keycode: int) -> Dictionary:
    if settings == null or not is_instance_valid(settings):
        return {"ok": false, "message": "输入配置实例缺失"}
    var value: Variant = settings.call("rebind", action_id, keycode)
    if typeof(value) != TYPE_DICTIONARY:
        return {"ok": false, "message": "修改返回值无效"}
    return (value as Dictionary).duplicate(true)

func restore(settings: Object) -> Dictionary:
    if settings == null or not is_instance_valid(settings):
        return {"ok": false, "message": "输入配置实例缺失"}
    var value: Variant = settings.call("restore_defaults")
    if typeof(value) != TYPE_DICTIONARY:
        return {"ok": false, "message": "恢复返回值无效"}
    return (value as Dictionary).duplicate(true)

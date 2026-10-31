extends RefCounted
## Flow-Shell-004: uses pinned PR #14 scene + validator, NOT_RUN.
## All fields are manufactured for technical UI demonstration only.

const LOCAL_SCENE := "res://vendor/profile/character_profile_panel.tscn"

func _fixture() -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": "sample-record-a",
        "display_name": "占位资料 A",
        "subtitle": "独立演示用合成条目",
        "summary": "这里只验证资料面板的布局与可注入接口，不代表任何真实人物、剧情或正史。",
        "status_label": "未连接任何业务数据",
        "tags": ["合成", "仅供测试"],
        "sections": [
            {
                "section_id": "display-fields",
                "heading": "展示字段",
                "items": [
                    {"label": "编号", "value": "SAMPLE-A"},
                    {"label": "来源", "value": "本地代码生成的占位资料"}
                ]
            },
            {
                "section_id": "instructions",
                "heading": "交互说明",
                "items": [
                    {"label": "边界", "value": "只读展示；不写入游戏状态或角色数据库。"}
                ]
            }
        ]
    }

func mount(stage: VBoxContainer) -> Dictionary:
    if not ResourceLoader.exists(LOCAL_SCENE, "PackedScene"):
        return {"ok": false, "reason": "资料面板场景缺失"}
    var resource: Resource = ResourceLoader.load(LOCAL_SCENE, "PackedScene")
    if not resource is PackedScene:
        return {"ok": false, "reason": "资料面板资源类型不符"}
    var instance: Node = (resource as PackedScene).instantiate()
    if not instance is Control:
        instance.queue_free()
        return {"ok": false, "reason": "资料面板不是 Control"}
    if not instance.has_method("set_profile") or not instance.has_method("clear_profile"):
        instance.queue_free()
        return {"ok": false, "reason": "PR #14 注入接口缺失"}
    var widget: Control = instance as Control
    widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stage.add_child(widget)
    if not bool(instance.call("set_profile", _fixture())):
        var issue: String = "校验拒绝"
        if instance.has_method("last_error"):
            issue = str(instance.call("last_error"))
        stage.remove_child(instance)
        instance.queue_free()
        return {"ok": false, "reason": "合成资料校验失败：" + issue}
    return {"ok": true, "instance": widget, "reason": "PR #14 隔离只读面板副本"}

func unmount(instance: Node) -> void:
    if not is_instance_valid(instance):
        return
    if instance.has_method("clear_profile"):
        instance.call("clear_profile")
    if instance.get_parent() != null:
        instance.get_parent().remove_child(instance)
    instance.queue_free()

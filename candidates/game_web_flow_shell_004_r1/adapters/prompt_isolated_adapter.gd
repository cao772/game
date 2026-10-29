extends RefCounted
## Flow-Shell-004: explicitly pinned PR #10 source copy, NOT_RUN.
## Local scene lifecycle only; interaction requests become display feedback.

const LOCAL_SCENE := "res://vendor/prompt/interaction_prompt_candidate.tscn"

func mount(stage: VBoxContainer, on_request: Callable) -> Dictionary:
    if not ResourceLoader.exists(LOCAL_SCENE, "PackedScene"):
        return {"ok": false, "reason": "交互提示场景缺失"}
    var resource: Resource = ResourceLoader.load(LOCAL_SCENE, "PackedScene")
    if not resource is PackedScene:
        return {"ok": false, "reason": "交互提示资源类型不符"}
    var instance: Node = (resource as PackedScene).instantiate()
    if not instance is Control:
        instance.queue_free()
        return {"ok": false, "reason": "交互提示不是 Control"}
    if not instance.has_method("show_for_targets")             or not instance.has_method("hide_prompt")             or not instance.has_signal("interaction_requested"):
        instance.queue_free()
        return {"ok": false, "reason": "PR #10 候选接口缺失"}
    var widget: Control = instance as Control
    widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage.add_child(widget)
    instance.connect("interaction_requested", on_request)
    var sample_targets: Array = [
        {"id": &"demo-target-a", "label": "合成目标 A", "action_caption": "仅发送模拟请求"},
        {"id": &"demo-target-b", "label": "合成目标 B", "action_caption": "仅发送模拟请求"}
    ]
    if not bool(instance.call("show_for_targets", sample_targets, 0)):
        stage.remove_child(instance)
        instance.queue_free()
        return {"ok": false, "reason": "show_for_targets 拒绝了合成目标"}
    return {"ok": true, "instance": widget, "reason": "PR #10 隔离副本，非真实游戏组件"}

func unmount(instance: Node) -> void:
    if not is_instance_valid(instance):
        return
    if instance.has_method("hide_prompt") and instance.is_inside_tree():
        instance.call("hide_prompt")
    if instance.get_parent() != null:
        instance.get_parent().remove_child(instance)
    instance.queue_free()

extends RefCounted
## Dynamic PackedScene validation seam for the standalone synthetic preview.
## Never accepts a path: the caller owns a single fixed res:// source.

static func _failure(message: String) -> Dictionary:
    return {"ok": false, "node": null, "error": message}


static func instantiate_panel(candidate: Resource) -> Dictionary:
    if not candidate is PackedScene:
        return _failure("资料展示组件资源类型无效")
    var scene := candidate as PackedScene
    var node: Node = scene.instantiate()
    if node == null:
        return _failure("资料展示组件无法实例化")
    if not node is Control:
        node.free()
        return _failure("资料展示组件根节点类型无效")
    for method_name in ["set_profile", "clear_profile", "profile_copy", "last_error"]:
        if not node.has_method(method_name):
            node.free()
            return _failure("资料展示组件接口不完整")
    # The preview's focus setup depends on these exact local scene children.
    # Reject a foreign or incomplete PackedScene before attaching it.
    for required_path in [
        "Layout/Scroll",
        "Layout/SectionNav",
        "Layout/SectionNav/SectionChoice",
        "Layout/SectionNav/SectionJump"
    ]:
        if node.get_node_or_null(required_path) == null:
            node.free()
            return _failure("资料展示组件场景结构不完整")
    return {"ok": true, "node": node, "error": ""}

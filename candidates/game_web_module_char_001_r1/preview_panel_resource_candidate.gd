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
    return {"ok": true, "node": node, "error": ""}

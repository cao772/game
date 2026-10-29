extends MarginContainer
## Standalone preview only: loads synthetic placeholder JSON, never private files.

const ProfileContract = preload("res://profile_contract_candidate.gd")
const FIXTURE_PATH := "res://placeholder_profiles.json"

var _examples: Array[Dictionary] = []

@onready var _choice: OptionButton = $Layout/Toolbar/Choice
@onready var _clear_button: Button = $Layout/Toolbar/Clear
@onready var _status: Label = $Layout/Status
@onready var _panel = $Layout/Panel


func _ready() -> void:
    _choice.item_selected.connect(_on_chosen)
    _clear_button.pressed.connect(_on_clear)
    _load_examples()


func _load_examples() -> void:
    var source := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
    if source == null:
        _status.text = "占位数据缺失：无法预览"
        return
    var raw := source.get_as_text()
    source.close()

    var parser := JSON.new()
    if parser.parse(raw) != OK or typeof(parser.data) != TYPE_ARRAY:
        _status.text = "占位 JSON 格式错误"
        return

    var candidates: Array = parser.data
    for candidate in candidates:
        var result: Dictionary = ProfileContract.validate(candidate)
        if not result["ok"]:
            _examples.clear()
            _choice.clear()
            _panel.clear_profile()
            _status.text = "占位数据校验失败：" + result["error"]
            return
        _examples.append(result["data"])
        _choice.add_item(result["data"]["display_name"])

    if _examples.is_empty():
        _status.text = "占位数据为空"
        return
    _choice.select(0)
    _on_chosen(0)


func _on_chosen(index: int) -> void:
    if index < 0 or index >= _examples.size():
        _status.text = "索引无效"
        return
    if _panel.set_profile(_examples[index]):
        _status.text = "仅供技术预览，未关联正式人物或正史"
    else:
        _status.text = "展示失败：" + _panel.last_error()


func _on_clear() -> void:
    _panel.clear_profile()
    _choice.select(-1)
    _status.text = "已清空展示数据"

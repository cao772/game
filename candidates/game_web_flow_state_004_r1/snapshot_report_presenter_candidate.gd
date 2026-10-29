extends RefCounted
## GAME-WEB-PLAY-STATE-005 r1 — allowlisted Chinese text presenter.
## Pure formatting; does not read files, invoke external commands or log.
## Source fields/values/paths/hashes are NEVER interpolated.

const FIELDS := [
	"version", "mode", "round_id", "phase", "door_open", "clock_seconds"
]
const STATUSES := {
	"valid": "格式 v1 校验有效（仅格式，不证明游戏语义）",
	"missing": "未找到所选模式的快照",
	"unreadable": "无法读取快照",
	"too_large": "超过检查器候选大小上限",
	"malformed_json": "JSON 无法解析",
	"invalid_schema": "字段或类型不符合已知格式",
	"unsupported_version": "版本不受支持：尚无迁移映射",
	"mode_mismatch": "内容模式与所选模式不一致",
	"invalid_request": "请求路径或模式不合法",
	"no_migration_needed": "已知 v1 格式，无需版本迁移",
	"no_changes": "候选内容与已知格式一致",
	"same_version_review_only": "同版本假设差异，仅供复核",
	"protected_field_review_blocked": "包含受保护字段的修改，禁止应用",
	"mapping_required": "缺少已批准的版本迁移映射",
	"blocked": "已阻断：不可比较或预览",
	"invalid_target": "假设目标字段不合法",
	"source_unstable": "源文件前后读取不一致，请停止使用本次结果",
	"comparable_v1": "两份 v1 快照可作字段结构比较",
	"unmapped_versions": "存在未知版本，禁止字段语义比较",
	"source_not_stable": "源文件发生变化，本次结果已作废"
}
const COMPATIBILITY := {
	"compatible_v1": "已知 v1 格式匹配（仅格式）",
	"unsupported": "未知版本，不能推断可迁移",
	"incompatible_mode": "模式不兼容",
	"invalid": "格式无效",
	"indeterminate": "无法确定兼容性"
}


func _status(code: Variant) -> String:
	if typeof(code) != TYPE_STRING:
		return "未知状态"
	if STATUSES.has(code):
		return STATUSES[code]
	return "未知状态"


func _known_mode(value: Variant) -> String:
	if value == "story" or value == "free":
		return value
	return "未知"


func _compat(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return "未知"
	var code: Variant = value.get("classification", "")
	if typeof(code) == TYPE_STRING and COMPATIBILITY.has(code):
		return COMPATIBILITY[code] + " [" + code + "]"
	return "未知"


func _code(value: Variant) -> String:
	# Only upper-case ASCII status keys are rendered. No attacker-supplied
	# path, JSON text, arbitrary field/value or exception is ever reflected.
	if typeof(value) != TYPE_STRING:
		return ""
	if value.length() > 72:
		return ""
	for character in value:
		var ordinal := character.unicode_at(0)
		if not ((ordinal >= 65 and ordinal <= 90)
			or (ordinal >= 48 and ordinal <= 57) or ordinal == 95):
			return ""
	return value


func _label(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return "未知"
	if value == "1":
		return "1"
	if value == "unknown" or value == "nonfinite" 			or value == "invalid_type" 			or value == "numeric_out_of_display_range":
		return value
	if value.length() > 20:
		return "未知"
	# Numeric version labels are public metadata in this candidate only.
	for character in value:
		var ordinal := character.unicode_at(0)
		if not ((ordinal >= 48 and ordinal <= 57)
			or ordinal == 46 or ordinal == 45 or ordinal == 43):
			return "未知"
	return value


func _section(title: String, value: Dictionary) -> String:
	var status_code: Variant = value.get("status", "unknown")
	var lines: Array[String] = [
		title,
		"  状态：" + _status(status_code) + " [" + str(status_code) + "]"
	]
	var error_code := _code(value.get("error_code", ""))
	if not error_code.is_empty():
		lines.append("  错误代码：" + error_code)
	return "\n".join(lines)


func _changes(value: Variant) -> String:
	if typeof(value) != TYPE_ARRAY:
		return "  无可展示的差异"
	var lines: Array[String] = []
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var field: Variant = entry.get("field", "")
		var kind: Variant = entry.get("kind", "")
		if not FIELDS.has(field):
			continue
		if not ["add", "remove", "change"].has(kind):
			continue
		lines.append("  - " + field + " : " + kind)
	if lines.is_empty():
		return "  无可展示的差异"
	return "\n".join(lines)


func inspection(report: Dictionary) -> String:
	if report.get("status", "") == "invalid_request" 			or report.get("status", "") == "source_unstable":
		return _section("检查已阻断", report) + "\n结果不可作为存档状态证据。"
	var check: Variant = report.get("inspection", {})
	var version: Variant = report.get("version_delta", {})
	if typeof(check) != TYPE_DICTIONARY or typeof(version) != TYPE_DICTIONARY:
		return "检查未完成：返回结构缺失。"
	var c: Dictionary = check
	var v: Dictionary = version
	var lines: Array[String] = [
		_section("校验报告", c),
		"  模式：" + _known_mode(c.get("expected_mode", "")),
		"  版本：" + _label(c.get("version_label", "unknown")),
		"  兼容性：" + _compat(c.get("compatibility", {})),
		"",
		_section("与已知 v1 的版本关系", v)
	]
	var relation: Variant = v.get("numeric_relation", "unknown")
	match relation:
		"lower_numeric_version":
			lines.append("  数字版本关系：低于 1（不代表可升级）")
		"same_numeric_version":
			lines.append("  数字版本关系：等于 1")
		"higher_numeric_version":
			lines.append("  数字版本关系：高于 1（不代表可降级）")
		_:
			lines.append("  数字版本关系：不可判定")
	lines.append("")
	lines.append("仅格式诊断；多次读取不构成原子快照。")
	return "\n".join(lines)


func comparison(report: Dictionary) -> String:
	var lines: Array[String] = [
		_section("版本与结构比较", report)
	]
	if report.has("left") and typeof(report["left"]) == TYPE_DICTIONARY:
		lines.append("")
		lines.append(_section("目录 A", report["left"]))
	if report.has("right") and typeof(report["right"]) == TYPE_DICTIONARY:
		lines.append("")
		lines.append(_section("目录 B", report["right"]))
	var relation: Variant = report.get("version_relation", "unknown")
	if relation == "same_numeric_version":
		lines.append("数字版本相同（不等于内容一致）")
	elif relation == "lower_numeric_version":
		lines.append("A 的数字版本低于 B")
	elif relation == "higher_numeric_version":
		lines.append("A 的数字版本高于 B")
	else:
		lines.append("数字版本关系不可判定")
	lines.append("")
	lines.append("差异字段（只显示名称和变化类型）：")
	lines.append(_changes(report.get("changed_fields", [])))
	lines.append("")
	lines.append("未知版本不作字段语义比较；两次读取并非事务。")
	return "\n".join(lines)


func preview(report: Dictionary) -> String:
	var lines: Array[String] = [
		_section("迁移需求与假设预览", report),
		"",
		"状态：只读预览，不能应用、不能保存、不能恢复。",
		"已批准迁移映射：无",
		"",
		"候选差异（仅字段名称）：",
		_changes(report.get("changes", [])),
		""
	]
	if report.get("status", "") == "mapping_required":
		lines.append("尚无旧版本结构和合法映射，禁止猜测转换。")
	elif report.get("status", "") == "protected_field_review_blocked":
		lines.append("受保护标识或时钟发生变化，仅能人工审查。")
	elif report.get("status", "") == "source_unstable":
		lines.append("源文件前后读取不一致，本次结果必须作废。")
	else:
		lines.append("此报告不构成状态转移或正史批准。")
	return "\n".join(lines)

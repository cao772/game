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
const ALLOWED_ERROR_CODES := [
	"INVALID_EXPECTED_MODE", "UNSUPPORTED_PATH_SCHEME", "UNSAFE_PATH",
	"FILENAME_MODE_MISMATCH", "PATH_IS_DIRECTORY", "FILE_MISSING",
	"OPEN_FAILED", "FILE_TOO_LARGE", "JSON_PARSE_FAILED", "ROOT_NOT_OBJECT",
	"MISSING_FIELD", "INVALID_VERSION_TYPE", "NONFINITE_VERSION",
	"UNSUPPORTED_VERSION", "INVALID_MODE", "SOURCE_MODE_MISMATCH",
	"UNEXPECTED_FIELD", "INVALID_ROUND_ID_TYPE", "BLANK_ROUND_ID",
	"INVALID_PHASE", "INVALID_DOOR_OPEN", "INVALID_CLOCK_TYPE",
	"NONFINITE_CLOCK", "NEGATIVE_CLOCK", "REFERENCE_NOT_APPROVED_V1",
	"UNCOMPARABLE_SOURCES", "VERSION_MAPPING_NOT_PROVIDED",
	"TARGET_MODE_MISMATCH", "PROTECTED_FIELDS_DIFFER",
	"FOLDER_REQUIRED", "FOLDER_WHITESPACE", "FOLDER_TOO_LONG",
	"USER_SCHEME_REQUIRED", "INVALID_FOLDER", "INVALID_PROPOSED_PHASE",
	"INVALID_PROPOSED_DOOR", "SOURCE_CHANGED_OR_UNREADABLE",
	"LEFT_FOLDER_REQUIRED", "RIGHT_FOLDER_REQUIRED",
	"LEFT_FOLDER_WHITESPACE", "RIGHT_FOLDER_WHITESPACE",
	"LEFT_FOLDER_TOO_LONG", "RIGHT_FOLDER_TOO_LONG",
	"LEFT_USER_SCHEME_REQUIRED", "RIGHT_USER_SCHEME_REQUIRED",
	"LEFT_INVALID_FOLDER", "RIGHT_INVALID_FOLDER",
	"LEFT_INVALID_EXPECTED_MODE", "RIGHT_INVALID_EXPECTED_MODE"
]
const NOTICE_MESSAGES := {
	"READ_ONLY": "只读操作：无保存或迁移入口。",
	"NO_ATOMICITY": "多次读取不构成文件锁或原子快照。",
	"SOURCE_UNSTABLE": "检测到来源变化或不可继续读取，请重新检查。",
	"INVALID_REQUEST": "路径、模式或候选字段不符合约束。",
	"FILE_UNAVAILABLE": "所选模式快照缺失或不可读取；不会自动切换到其他模式。",
	"CORRUPT_OR_INVALID": "文件损坏、过大或不符合已知格式；不能自行修复。",
	"MODE_MISMATCH": "来源模式与所选模式不同；禁止混用。",
	"VERSION_MAPPING_ABSENT": "版本结构未知，未提供已批准的迁移映射。",
	"V1_FORMAT_ONLY": "v1 格式有效并不保证游戏状态、历史时钟或剧情语义有效。",
	"DIFF_PRESENT": "检测到已知字段差异，仅展示字段名称和变化类型。",
	"NO_KNOWN_DIFF": "未发现已知 v1 字段差异，但不证明两次读取完全相同。",
	"PROTECTED_DIFFERENCE": "受保护字段（标识、模式或时钟）有差异；不得视为可执行修改。",
	"UNCOMPARABLE": "无法安全进行字段语义比较。",
	"SAME_SOURCE_SELECTED": "目录 A 与 B 相同：本次为同一来源的重复读取，不是备份比对。",
	"PREVIEW_NEVER_APPLIES": "迁移预览只能查看，永远不会应用或覆盖。",
	"NO_PAYLOAD_VERIFICATION": "缺少可验证的内容指纹，无法证明文件内容稳定。",
	"METADATA_ONLY": "结果仅包含脱敏的技术元数据。",
	"UNKNOWN_DIAGNOSTIC": "出现未识别的诊断状态，不能宣称成功。",
	"AUTHOR_REVIEW_REQUIRED": "该候选不能批准任何状态迁移，需作者最终验收。"
}
const LEVEL_LABELS := {
	"informational": "信息",
	"review_required": "需人工复核",
	"blocked": "已阻断"
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
	# Only known static codes can appear in the public-facing UI.
	if typeof(value) != TYPE_STRING:
		return ""
	if ALLOWED_ERROR_CODES.has(value):
		return value
	return ""


func _label(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return "未知"
	if value == "1":
		return "1"
	if value == "unknown" or value == "nonfinite" \
			or value == "invalid_type" \
			or value == "numeric_out_of_display_range":
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
	var safe_status := "unknown"
	if typeof(status_code) == TYPE_STRING and STATUSES.has(status_code):
		safe_status = status_code
	var lines: PackedStringArray = [
		title,
		"  状态：" + _status(status_code) + " [" + safe_status + "]"
	]
	var error_code := _code(value.get("error_code", ""))
	if not error_code.is_empty():
		lines.append("  错误代码：" + error_code)
	return "\n".join(lines)


func _diagnostic_lines(report: Dictionary) -> String:
	var info: Variant = report.get("diagnostics", {})
	if typeof(info) != TYPE_DICTIONARY:
		return "判定：无完整诊断信息；不得据此执行操作。"
	var level: Variant = info.get("level", "blocked")
	if typeof(level) != TYPE_STRING or not LEVEL_LABELS.has(level):
		level = "blocked"
	var lines: PackedStringArray = [
		"安全判定：" + LEVEL_LABELS[level] + "（仅供查看）"
	]
	var codes: Variant = info.get("notice_codes", [])
	if typeof(codes) == TYPE_ARRAY:
		for code in codes:
			# No raw issue strings or arbitrary values are interpolated.
			if typeof(code) == TYPE_STRING and NOTICE_MESSAGES.has(code):
				lines.append("  • " + NOTICE_MESSAGES[code])
	return "\n".join(lines)


func _changes(value: Variant) -> String:
	if typeof(value) != TYPE_ARRAY:
		return "  无可展示的差异"
	var lines: PackedStringArray = []
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
	if report.get("status", "") == "invalid_request" \
			or report.get("status", "") == "source_unstable":
		return _section("检查已阻断", report) + "\n结果不可作为存档状态证据。\n" + _diagnostic_lines(report)
	var check: Variant = report.get("inspection", {})
	var version: Variant = report.get("version_delta", {})
	if typeof(check) != TYPE_DICTIONARY or typeof(version) != TYPE_DICTIONARY:
		return "检查未完成：返回结构缺失。"
	var c: Dictionary = check
	var v: Dictionary = version
	var lines: PackedStringArray = [
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
	lines.append("")
	lines.append(_diagnostic_lines(report))
	return "\n".join(lines)


func comparison(report: Dictionary) -> String:
	var lines: PackedStringArray = [
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
	if report.get("status", "") == "comparable_v1":
		lines.append(_changes(report.get("changed_fields", [])))
	else:
		lines.append("  不可比较：不显示任何字段差异。")
	lines.append("")
	lines.append("未知版本不作字段语义比较；两次读取并非事务。")
	lines.append("")
	lines.append(_diagnostic_lines(report))
	return "\n".join(lines)


func preview(report: Dictionary) -> String:
	var lines: PackedStringArray = [
		_section("迁移需求与假设预览", report),
		"",
		"状态：只读预览，不能应用、不能保存、不能恢复。",
		"已批准迁移映射：无",
		"",
		"候选差异（仅字段名称）："
	]
	var status: Variant = report.get("status", "")
	if ["no_changes", "same_version_review_only", "protected_field_review_blocked"].has(status):
		lines.append(_changes(report.get("changes", [])))
	else:
		lines.append("  当前结果不可展示候选差异。")
	lines.append("")
	]
	if report.get("status", "") == "mapping_required":
		lines.append("尚无旧版本结构和合法映射，禁止猜测转换。")
	elif report.get("status", "") == "protected_field_review_blocked":
		lines.append("受保护标识或时钟发生变化，仅能人工审查。")
	elif report.get("status", "") == "source_unstable":
		lines.append("源文件前后读取不一致，本次结果必须作废。")
	else:
		lines.append("此报告不构成状态转移或正史批准。")
	lines.append("")
	lines.append(_diagnostic_lines(report))
	return "\n".join(lines)

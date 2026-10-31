extends RefCounted
## GAME-WEB-STATE-006 r1 — pure allowlisted diagnostics for read-only UI.
## Never reads files, logs, embeds save data, or returns private values.
## Risk is a display recommendation, NOT a game/canon/migration judgment.
## NOT_RUN / NOT_VERIFIED.

const FIELDS := ["version", "mode", "round_id", "phase", "door_open", "clock_seconds"]
const PROTECTED_FIELDS := ["version", "mode", "round_id", "clock_seconds"]
const STATUSES := [
	"valid", "missing", "unreadable", "too_large", "malformed_json",
	"invalid_schema", "unsupported_version", "mode_mismatch",
	"invalid_request", "source_unstable", "comparable_v1",
	"unmapped_versions", "blocked", "mapping_required",
	"no_migration_needed", "no_changes", "same_version_review_only",
	"protected_field_review_blocked", "invalid_target"
]
const NOTICE_CODES := [
	"READ_ONLY", "NO_ATOMICITY", "SOURCE_UNSTABLE", "INVALID_REQUEST",
	"FILE_UNAVAILABLE", "CORRUPT_OR_INVALID", "MODE_MISMATCH",
	"VERSION_MAPPING_ABSENT", "V1_FORMAT_ONLY", "DIFF_PRESENT",
	"NO_KNOWN_DIFF", "PROTECTED_DIFFERENCE", "UNCOMPARABLE",
	"SAME_SOURCE_SELECTED", "PREVIEW_NEVER_APPLIES",
	"NO_PAYLOAD_VERIFICATION", "METADATA_ONLY",
	"UNKNOWN_DIAGNOSTIC", "AUTHOR_REVIEW_REQUIRED"
]


func _add_unique(target: Array, code: String) -> void:
	if NOTICE_CODES.has(code) and not target.has(code):
		target.append(code)


func _known_status(value: Variant) -> String:
	if typeof(value) == TYPE_STRING and STATUSES.has(value):
		return value
	return "unknown"


func _known_changes(source: Variant) -> Array:
	# Do not pass through unknown field names, values, nested structures,
	# arbitrary source keys or a false changed_field_count.
	var result: Array = []
	if typeof(source) != TYPE_ARRAY:
		return result
	for element in source:
		if typeof(element) != TYPE_DICTIONARY:
			continue
		var field: Variant = element.get("field", "")
		var kind: Variant = element.get("kind", "")
		if not FIELDS.has(field) or not ["add", "remove", "change"].has(kind):
			continue
		var already := false
		for prior in result:
			if prior["field"] == field:
				already = true
				break
		if not already:
			result.append({"field": field, "kind": kind})
	return result


func build(kind: String, report: Dictionary, same_source: bool = false) -> Dictionary:
	# This return type is safe to display by an allowlisted presenter,
	# but never an authorization, audit record or proof of file integrity.
	var status := _known_status(report.get("status", ""))
	var notes: Array = []
	var severity := "informational"
	_add_unique(notes, "READ_ONLY")
	_add_unique(notes, "NO_ATOMICITY")
	_add_unique(notes, "METADATA_ONLY")

	if kind == "inspection":
		if status == "source_unstable":
			severity = "blocked"
			_add_unique(notes, "SOURCE_UNSTABLE")
		elif status == "invalid_request":
			severity = "blocked"
			_add_unique(notes, "INVALID_REQUEST")
		else:
			var inner: Variant = report.get("inspection", {})
			var detail := ""
			if typeof(inner) == TYPE_DICTIONARY:
				detail = _known_status(inner.get("status", ""))
			match detail:
				"valid":
					_add_unique(notes, "V1_FORMAT_ONLY")
				"unsupported_version":
					severity = "review_required"
					_add_unique(notes, "VERSION_MAPPING_ABSENT")
				"mode_mismatch":
					severity = "blocked"
					_add_unique(notes, "MODE_MISMATCH")
				"invalid_schema", "malformed_json", "too_large":
					severity = "blocked"
					_add_unique(notes, "CORRUPT_OR_INVALID")
				"missing", "unreadable":
					severity = "review_required"
					_add_unique(notes, "FILE_UNAVAILABLE")
				_:
					severity = "blocked"
					_add_unique(notes, "UNKNOWN_DIAGNOSTIC")
			if report.get("consistency", "") == "no_payload_to_verify":
				_add_unique(notes, "NO_PAYLOAD_VERIFICATION")

	elif kind == "comparison":
		if same_source:
			_add_unique(notes, "SAME_SOURCE_SELECTED")
		if status == "comparable_v1":
			var changes := _known_changes(report.get("changed_fields", []))
			if changes.is_empty():
				_add_unique(notes, "NO_KNOWN_DIFF")
			else:
				severity = "review_required"
				_add_unique(notes, "DIFF_PRESENT")
				for entry in changes:
					if PROTECTED_FIELDS.has(entry["field"]):
						_add_unique(notes, "PROTECTED_DIFFERENCE")
						break
		elif status == "unmapped_versions":
			severity = "blocked"
			_add_unique(notes, "VERSION_MAPPING_ABSENT")
			_add_unique(notes, "UNCOMPARABLE")
		elif status == "source_unstable":
			severity = "blocked"
			_add_unique(notes, "SOURCE_UNSTABLE")
		elif status == "invalid_request":
			severity = "blocked"
			_add_unique(notes, "INVALID_REQUEST")
		else:
			severity = "blocked"
			_add_unique(notes, "UNCOMPARABLE")
		if status != "comparable_v1":
			_add_unique(notes, "NO_PAYLOAD_VERIFICATION")

	elif kind == "preview":
		_add_unique(notes, "PREVIEW_NEVER_APPLIES")
		_add_unique(notes, "AUTHOR_REVIEW_REQUIRED")
		match status:
			"no_migration_needed", "no_changes":
				pass
			"same_version_review_only":
				severity = "review_required"
				_add_unique(notes, "DIFF_PRESENT")
			"protected_field_review_blocked":
				severity = "blocked"
				_add_unique(notes, "PROTECTED_DIFFERENCE")
			"mapping_required":
				severity = "blocked"
				_add_unique(notes, "VERSION_MAPPING_ABSENT")
			"source_unstable":
				severity = "blocked"
				_add_unique(notes, "SOURCE_UNSTABLE")
			"invalid_request", "invalid_target":
				severity = "blocked"
				_add_unique(notes, "INVALID_REQUEST")
			_:
				severity = "blocked"
				_add_unique(notes, "UNCOMPARABLE")
	else:
		severity = "blocked"
		_add_unique(notes, "UNKNOWN_DIAGNOSTIC")

	return {
		"task_id": "GAME-WEB-STATE-006",
		"kind": kind if ["inspection", "comparison", "preview"].has(kind) else "unknown",
		"level": severity,
		"notice_codes": notes.duplicate(true),
		"known_changed_fields": _known_changes(
			report.get("changed_fields", report.get("changes", []))
		),
		"same_source_reference": same_source if kind == "comparison" else false,
		"verified": false,
		"can_apply": false,
		"writes": false,
		"contains_snapshot_payload": false
	}

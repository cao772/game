extends RefCounted
## GAME-WEB-MODULE-STATE-002 r1 (extends STATE-001 r1, same isolated PR).
## Standalone read-only snapshot inspection, compatibility and preview.
## No disk writes, process calls or runtime wiring. NOT_RUN.

const VERSION := 1
const REPORT_VERSION := 1
const MAX_BYTES := 1048576 # Inspection-only candidate guard, NOT a save limit.
const FIELDS := [
	"version", "mode", "round_id", "phase", "door_open", "clock_seconds"
]
const MODES := ["story", "free"]
const PHASES := ["ready", "observing", "resolved", "deferred"]
const PROTECTED_FIELDS := [
	"version", "mode", "round_id", "clock_seconds"
]


func _issue(code: String, field: String = "", message: String = "") -> Dictionary:
	return {"code": code, "field": field, "message": message}


func _path_issue(path: String, expected_mode: String) -> Dictionary:
	if not MODES.has(expected_mode):
		return _issue("INVALID_EXPECTED_MODE")
	if not path.begins_with("user://"):
		return _issue("UNSUPPORTED_PATH_SCHEME")
	var relative := path.trim_prefix("user://")
	if relative.is_empty() or relative.contains("\\") or relative.contains(":"):
		return _issue("UNSAFE_PATH")
	for segment in relative.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return _issue("UNSAFE_PATH")
	if path.get_file() != expected_mode + ".round_snapshot.json":
		return _issue("FILENAME_MODE_MISMATCH")
	return _issue("")


func _schema_issue(value: Variant) -> Dictionary:
	# Mirrors the six-field STATE r1 proposal from Draft PR #6.
	# Only emits known field names; unrecognized source keys are not echoed.
	if typeof(value) != TYPE_DICTIONARY:
		return _issue("ROOT_NOT_OBJECT")
	var data: Dictionary = value
	for field in FIELDS:
		if not data.has(field):
			return _issue("MISSING_FIELD", field)
	if data.size() != FIELDS.size():
		return _issue("UNEXPECTED_FIELD")
	var version_type := typeof(data["version"])
	if version_type != TYPE_INT and version_type != TYPE_FLOAT:
		return _issue("INVALID_VERSION_TYPE", "version")
	if not is_finite(float(data["version"])):
		return _issue("NONFINITE_VERSION", "version")
	if float(data["version"]) != 1.0:
		return _issue("UNSUPPORTED_VERSION", "version")
	if typeof(data["mode"]) != TYPE_STRING or not MODES.has(data["mode"]):
		return _issue("INVALID_MODE", "mode")
	if typeof(data["round_id"]) != TYPE_STRING:
		return _issue("INVALID_ROUND_ID_TYPE", "round_id")
	if data["round_id"].strip_edges().is_empty():
		return _issue("BLANK_ROUND_ID", "round_id")
	if typeof(data["phase"]) != TYPE_STRING or not PHASES.has(data["phase"]):
		return _issue("INVALID_PHASE", "phase")
	if typeof(data["door_open"]) != TYPE_BOOL:
		return _issue("INVALID_DOOR_OPEN", "door_open")
	var seconds_type := typeof(data["clock_seconds"])
	if seconds_type != TYPE_INT and seconds_type != TYPE_FLOAT:
		return _issue("INVALID_CLOCK_TYPE", "clock_seconds")
	if not is_finite(float(data["clock_seconds"])):
		return _issue("NONFINITE_CLOCK", "clock_seconds")
	if float(data["clock_seconds"]) < 0.0:
		return _issue("NEGATIVE_CLOCK", "clock_seconds")
	return _issue("")


func _safe_version_label(value: Variant) -> String:
	var vt := typeof(value)
	if vt != TYPE_INT and vt != TYPE_FLOAT:
		return "invalid_type"
	if not is_finite(float(value)):
		return "nonfinite"
	if absf(float(value)) > 1000000.0:
		return "numeric_out_of_display_range"
	if float(value) == 1.0:
		return "1"
	return str(value)


func _probe(path: String, expected_mode: String) -> Dictionary:
	# raw is PRIVATE to this instance and never emitted by report_snapshot.
	var r := {
		"status": "invalid_request",
		"error_code": "",
		"error_field": "",
		"version_label": "unknown",
		"source_mode": "",
		"text_sha256": "",
		"byte_length": 0,
		"data": {},
		"raw": {}
	}
	var path_issue := _path_issue(path, expected_mode)
	if not path_issue["code"].is_empty():
		r["error_code"] = path_issue["code"]
		return r
	if DirAccess.dir_exists_absolute(path):
		r["status"] = "unreadable"
		r["error_code"] = "PATH_IS_DIRECTORY"
		return r
	if not FileAccess.file_exists(path):
		r["status"] = "missing"
		r["error_code"] = "FILE_MISSING"
		return r
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		r["status"] = "unreadable"
		r["error_code"] = "OPEN_FAILED"
		return r
	r["byte_length"] = file.get_length()
	if r["byte_length"] > MAX_BYTES:
		file.close()
		r["status"] = "too_large"
		r["error_code"] = "FILE_TOO_LARGE"
		return r
	var content := file.get_as_text()
	file.close()
	# Historical inspector API hash is of decoded text, not original bytes.
	r["text_sha256"] = content.sha256_text()
	var parser := JSON.new()
	if parser.parse(content) != OK:
		r["status"] = "malformed_json"
		r["error_code"] = "JSON_PARSE_FAILED"
		return r
	if typeof(parser.data) != TYPE_DICTIONARY:
		r["status"] = "invalid_schema"
		r["error_code"] = "ROOT_NOT_OBJECT"
		return r
	var raw: Dictionary = parser.data
	r["raw"] = raw.duplicate(true)
	if not raw.has("version"):
		r["status"] = "invalid_schema"
		r["error_code"] = "MISSING_FIELD"
		r["error_field"] = "version"
		return r
	r["version_label"] = _safe_version_label(raw["version"])
	var vt := typeof(raw["version"])
	if vt != TYPE_INT and vt != TYPE_FLOAT:
		r["status"] = "invalid_schema"
		r["error_code"] = "INVALID_VERSION_TYPE"
		r["error_field"] = "version"
		return r
	if not is_finite(float(raw["version"])):
		r["status"] = "invalid_schema"
		r["error_code"] = "NONFINITE_VERSION"
		r["error_field"] = "version"
		return r
	# Establish a valid source mode before claiming version compatibility
	# or allowing ANY form of manual preview.
	if not raw.has("mode") or typeof(raw["mode"]) != TYPE_STRING or not MODES.has(raw["mode"]):
		r["status"] = "invalid_schema"
		r["error_code"] = "INVALID_MODE"
		r["error_field"] = "mode"
		return r
	r["source_mode"] = raw["mode"] # Always enum-only, never arbitrary input.
	if raw["mode"] != expected_mode:
		r["status"] = "mode_mismatch"
		r["error_code"] = "SOURCE_MODE_MISMATCH"
		r["error_field"] = "mode"
		return r
	if float(raw["version"]) != 1.0:
		r["status"] = "unsupported_version"
		r["error_code"] = "UNSUPPORTED_VERSION"
		r["error_field"] = "version"
		return r
	var issue := _schema_issue(raw)
	if not issue["code"].is_empty():
		r["status"] = "invalid_schema"
		r["error_code"] = issue["code"]
		r["error_field"] = issue["field"]
		return r
	r["status"] = "valid"
	var data: Dictionary = raw.duplicate(true)
	data["version"] = VERSION
	r["data"] = data
	return r


func _compatibility_from_probe(probe: Dictionary) -> Dictionary:
	var classification := "indeterminate"
	var reason := probe["error_code"]
	match probe["status"]:
		"valid":
			classification = "compatible_v1"
			reason = "VALID_V1"
		"unsupported_version":
			classification = "unsupported"
			reason = "NO_APPROVED_MAPPING"
		"mode_mismatch":
			classification = "incompatible_mode"
			reason = "SOURCE_MODE_MISMATCH"
		"invalid_schema":
			classification = "invalid"
		"invalid_request", "missing", "unreadable", "too_large", "malformed_json":
			classification = "indeterminate"
	return {
		"classification": classification,
		"reason_code": reason,
		"source_version": probe["version_label"],
		"target_version": VERSION,
		"automatic_migration_supported": false
	}


func _safe_report(probe: Dictionary, expected_mode: String) -> Dictionary:
	# Never include raw JSON, ID, user path, field values, diff values or hash.
	var compatibility := _compatibility_from_probe(probe)
	return {
		"report_version": REPORT_VERSION,
		"task_id": "GAME-WEB-MODULE-STATE-002",
		"status": probe["status"],
		"valid": probe["status"] == "valid",
		"error_code": probe["error_code"],
		"error_field": probe["error_field"],
		"version_label": probe["version_label"],
		"expected_mode": expected_mode if MODES.has(expected_mode) else "invalid",
		"source_mode": probe["source_mode"],
		"byte_length": probe["byte_length"],
		"compatibility": compatibility.duplicate(true),
		"read_only": true,
		"contains_snapshot_payload": false,
		"verified": false
	}


func report_snapshot(path: String, expected_mode: String) -> Dictionary:
	return _safe_report(_probe(path, expected_mode), expected_mode)


func compatibility_snapshot(path: String, expected_mode: String) -> Dictionary:
	var safe := report_snapshot(path, expected_mode)
	return safe["compatibility"].duplicate(true)


func report_pair(folder: String) -> Dictionary:
	# Two sequential independent reads; no pair-wide atomic guarantee.
	return {
		"story": report_snapshot(folder.path_join("story.round_snapshot.json"), "story"),
		"free": report_snapshot(folder.path_join("free.round_snapshot.json"), "free"),
		"atomic_pair": false
	}


func inspect_snapshot(path: String, expected_mode: String) -> Dictionary:
	# Legacy detailed API: returns a COPY of valid snapshot data only.
	# For public reporting, use report_snapshot() instead.
	var probe := _probe(path, expected_mode)
	return {
		"ok": probe["status"] == "valid",
		"status": probe["status"],
		"error": probe["error_code"],
		"error_code": probe["error_code"],
		"error_field": probe["error_field"],
		"version_label": probe["version_label"],
		"source_mode": probe["source_mode"],
		"expected_mode": expected_mode,
		"text_sha256": probe["text_sha256"],
		"byte_length": probe["byte_length"],
		"data": probe["data"].duplicate(true)
	}


func inspect_pair(folder: String) -> Dictionary:
	return {
		"story": inspect_snapshot(folder.path_join("story.round_snapshot.json"), "story"),
		"free": inspect_snapshot(folder.path_join("free.round_snapshot.json"), "free")
	}


func _safe_changes(source: Dictionary, target: Dictionary) -> Array:
	# No field VALUES in output; unknown source key NAMES are not emitted.
	# Stable, ordered, known-field-only structural differences.
	var changes: Array = []
	for field in FIELDS:
		var from_exists := source.has(field)
		var to_exists := target.has(field)
		var kind := ""
		if not from_exists and to_exists:
			kind = "add"
		elif from_exists and not to_exists:
			kind = "remove"
		elif from_exists and to_exists:
			# Godot JSON decodes 1 as 1.0 on some paths. Preserve
			# numeric equivalence for version/clock, not bool equivalence.
			var same := false
			var source_type := typeof(source[field])
			var target_type := typeof(target[field])
			var source_numeric := source_type == TYPE_INT or source_type == TYPE_FLOAT
			var target_numeric := target_type == TYPE_INT or target_type == TYPE_FLOAT
			if (field == "version" or field == "clock_seconds") and source_numeric and target_numeric:
				same = float(source[field]) == float(target[field])
			else:
				same = source_type == target_type and source[field] == target[field]
			if not same:
				kind = "change"
		if not kind.is_empty():
			changes.append({"field": field, "kind": kind})
	return changes


func preview_migration(path: String, expected_mode: String, proposed_target: Variant = null) -> Dictionary:
	# No mapping inferred; no write, repair, rename or save method.
	var source := _probe(path, expected_mode)
	var compatibility := _compatibility_from_probe(source)
	var report := {
		"ok": false,
		"status": "blocked",
		"source_status": source["status"],
		"source_version": source["version_label"],
		"target_version": VERSION,
		"expected_mode": expected_mode if MODES.has(expected_mode) else "invalid",
		"text_sha256": source["text_sha256"], # Detailed local API; don't publish.
		"changes": [],
		"unrecognized_source_field_count": 0,
		"compatibility": compatibility,
		"requires_review": true,
		"mapping_approved": false,
		"can_apply": false,
		"writes": false,
		"error": source["error_code"],
		"error_code": source["error_code"]
	}
	# Non-readable, corrupt, v1-schema-invalid and cross-mode source
	# cannot be "rescued" by a caller-supplied target.
	if source["status"] != "valid" and source["status"] != "unsupported_version":
		return report
	if proposed_target == null:
		if source["status"] == "valid":
			report["ok"] = true
			report["status"] = "no_migration_needed"
			report["error"] = ""
			report["error_code"] = ""
		else:
			report["status"] = "mapping_required"
			report["error"] = "NO_APPROVED_MAPPING"
			report["error_code"] = "NO_APPROVED_MAPPING"
		return report
	var target_issue := _schema_issue(proposed_target)
	if not target_issue["code"].is_empty():
		report["status"] = "invalid_target"
		report["error"] = target_issue["code"]
		report["error_code"] = target_issue["code"]
		return report
	if proposed_target["mode"] != expected_mode:
		report["status"] = "invalid_target"
		report["error"] = "TARGET_MODE_MISMATCH"
		report["error_code"] = "TARGET_MODE_MISMATCH"
		return report
	var raw: Dictionary = source["raw"]
	var target: Dictionary = proposed_target
	# Source data from unsupported versions is untrusted; permit
	# structural comparison of six known fields only, never migration.
	report["changes"] = _safe_changes(raw, target)
	var extension_count := 0
	for key in raw.keys():
		if not FIELDS.has(key):
			extension_count += 1
	report["unrecognized_source_field_count"] = extension_count
	report["ok"] = true # Preview formed; NOT source compatibility.
	report["error"] = ""
	report["error_code"] = ""
	if source["status"] == "unsupported_version":
		report["status"] = "manual_unverified_preview"
	elif report["changes"].is_empty():
		report["status"] = "no_changes"
	else:
		report["status"] = "same_version_proposal"
	return report

# CONTINUE-STATE-003 r1: safe version-difference & guarded preview.
# All added reports contain fixed status codes / known field NAMES only.
# No payload, round identifier, source path or checksum is returned.

func _numeric_relation(left: Variant, right: Variant) -> String:
	var left_type := typeof(left)
	var right_type := typeof(right)
	if (left_type != TYPE_INT and left_type != TYPE_FLOAT):
		return "unknown"
	if (right_type != TYPE_INT and right_type != TYPE_FLOAT):
		return "unknown"
	if not is_finite(float(left)) or not is_finite(float(right)):
		return "unknown"
	if float(left) < float(right):
		return "lower_numeric_version"
	if float(left) > float(right):
		return "higher_numeric_version"
	return "same_numeric_version"


func report_version_delta(
	path: String, expected_mode: String, reference_version: Variant = 1
) -> Dictionary:
	# Reference v1 is the ONLY known schema; no arbitrary target support.
	var reference_type := typeof(reference_version)
	var valid_reference := (
		(reference_type == TYPE_INT or reference_type == TYPE_FLOAT)
		and is_finite(float(reference_version))
		and float(reference_version) == float(VERSION)
	)
	var report := {
		"report_version": REPORT_VERSION,
		"task_id": "GAME-WEB-CONTINUE-STATE-003",
		"status": "invalid_reference",
		"error_code": "REFERENCE_NOT_APPROVED_V1",
		"expected_mode": expected_mode if MODES.has(expected_mode) else "invalid",
		"reference_version": VERSION,
		"source_version": "unknown",
		"numeric_relation": "unknown",
		"format_compatibility": "indeterminate",
		"migration_mapping": "not_provided",
		"can_migrate": false,
		"read_only": true,
		"verified": false
	}
	if not valid_reference:
		return report
	var probe := _probe(path, expected_mode)
	var compatibility := _compatibility_from_probe(probe)
	report["status"] = probe["status"]
	report["error_code"] = probe["error_code"]
	report["source_version"] = probe["version_label"]
	report["format_compatibility"] = compatibility["classification"]
	if probe["status"] == "valid" or probe["status"] == "unsupported_version":
		report["numeric_relation"] = _numeric_relation(
			probe["raw"]["version"], VERSION
		)
	return report


func compare_snapshot_versions(
	left_path: String, right_path: String, expected_mode: String
) -> Dictionary:
	# Independent sequential read per path; never a transaction / lock.
	var left := _probe(left_path, expected_mode)
	var right := _probe(right_path, expected_mode)
	var result := {
		"report_version": REPORT_VERSION,
		"task_id": "GAME-WEB-CONTINUE-STATE-003",
		"status": "blocked",
		"error_code": "UNCOMPARABLE_SOURCES",
		"left": _safe_report(left, expected_mode),
		"right": _safe_report(right, expected_mode),
		"version_relation": "unknown",
		"payload_comparison": "unavailable",
		"changed_fields": [],
		"changed_field_count": 0,
		"mapping_approved": false,
		"can_migrate": false,
		"atomic_pair": false,
		"read_only": true,
		"verified": false
	}
	var left_usable := (
		left["status"] == "valid" or left["status"] == "unsupported_version"
	)
	var right_usable := (
		right["status"] == "valid" or right["status"] == "unsupported_version"
	)
	if not left_usable or not right_usable:
		return result
	# Both sources have a finite numeric version and a verified matching mode.
	result["version_relation"] = _numeric_relation(
		left["raw"]["version"], right["raw"]["version"]
	)
	if left["status"] != "valid" or right["status"] != "valid":
		result["status"] = "unmapped_versions"
		result["error_code"] = "VERSION_MAPPING_NOT_PROVIDED"
		return result
	var changes := _safe_changes(left["data"], right["data"])
	result["changed_fields"] = changes.duplicate(true)
	result["changed_field_count"] = changes.size()
	result["payload_comparison"] = "known_v1_fields_only"
	result["status"] = "comparable_v1"
	result["error_code"] = ""
	return result


func preview_migration_safe(
	path: String, expected_mode: String, proposed_target: Variant = null
) -> Dictionary:
	# Strictly safer report-only API than the historical detailed preview:
	# no text_sha256, raw content, user path, or before/after values.
	var source := _probe(path, expected_mode)
	var safe := _safe_report(source, expected_mode)
	var result := {
		"report_version": REPORT_VERSION,
		"task_id": "GAME-WEB-CONTINUE-STATE-003",
		"status": "blocked",
		"error_code": source["error_code"],
		"source_status": source["status"],
		"compatibility": safe["compatibility"].duplicate(true),
		"expected_mode": safe["expected_mode"],
		"changes": [],
		"changed_field_count": 0,
		"protected_field_changes": [],
		"manual_mapping_required": true,
		"requires_review": true,
		"mapping_approved": false,
		"can_apply": false,
		"writes": false,
		"contains_snapshot_payload": false,
		"verified": false
	}
	# Unknown schemas are not comparable to v1 for actionable preview.
	# Never let a proposed target "rescue" invalid source JSON/schema/mode.
	if source["status"] == "unsupported_version":
		result["status"] = "mapping_required"
		result["error_code"] = "VERSION_MAPPING_NOT_PROVIDED"
		return result
	if source["status"] != "valid":
		return result
	if proposed_target == null:
		result["status"] = "no_migration_needed"
		result["error_code"] = ""
		result["manual_mapping_required"] = false
		return result
	var target_issue := _schema_issue(proposed_target)
	if not target_issue["code"].is_empty():
		result["status"] = "invalid_target"
		result["error_code"] = target_issue["code"]
		return result
	if proposed_target["mode"] != expected_mode:
		result["status"] = "invalid_target"
		result["error_code"] = "TARGET_MODE_MISMATCH"
		return result
	var target: Dictionary = proposed_target
	var changes := _safe_changes(source["data"], target)
	result["changes"] = changes.duplicate(true)
	result["changed_field_count"] = changes.size()
	result["manual_mapping_required"] = false
	for entry in changes:
		if PROTECTED_FIELDS.has(entry["field"]):
			result["protected_field_changes"].append(entry["field"])
	if not result["protected_field_changes"].is_empty():
		result["status"] = "protected_field_review_blocked"
		result["error_code"] = "PROTECTED_FIELDS_DIFFER"
	elif changes.is_empty():
		result["status"] = "no_changes"
		result["error_code"] = ""
	else:
		result["status"] = "same_version_review_only"
		result["error_code"] = ""
	return result

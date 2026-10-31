extends RefCounted
## GAME-WEB-STATE-006 r1
## Independent, read-only snapshot browser controller for model/report APIs.
## Pinned PR #13 inspector, explicit lexical path guards and safe alerts.
## NOT_RUN. No writer, file enumeration, migration or shared API approval.

const Inspector = preload("res://snapshot_inspector_dependency.gd")
const Diagnostics = preload("res://snapshot_diagnostics_candidate.gd")
const MODES := ["story", "free"]
const PHASES := ["ready", "observing", "resolved", "deferred"]
const MAX_FOLDER_LENGTH := 512

var _inspector = Inspector.new()
var _diagnostics = Diagnostics.new()


func _folder_issue(folder: String) -> String:
	if folder.is_empty():
		return "FOLDER_REQUIRED"
	if folder != folder.strip_edges():
		return "FOLDER_WHITESPACE"
	if folder.length() > MAX_FOLDER_LENGTH:
		return "FOLDER_TOO_LONG"
	if not folder.begins_with("user://"):
		return "USER_SCHEME_REQUIRED"
	var relative := folder.trim_prefix("user://")
	if relative.is_empty() or relative.contains("\\") or relative.contains(":"):
		return "INVALID_FOLDER"
	for segment in relative.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return "INVALID_FOLDER"
	for i in range(relative.length()):
		var scalar := relative.unicode_at(i)
		if scalar < 32 or scalar == 127:
			return "INVALID_FOLDER"
	return ""


func _context_issue(folder: String, mode: String) -> String:
	if not MODES.has(mode):
		return "INVALID_EXPECTED_MODE"
	return _folder_issue(folder)


func _file_for(folder: String, mode: String) -> String:
	# Paths are built only after _context_issue; no file discovery.
	return folder.path_join(mode + ".round_snapshot.json")


func _decorate(result: Dictionary, kind: String, same_source: bool = false) -> Dictionary:
	var safe: Dictionary = result.duplicate(true)
	safe["diagnostics"] = _diagnostics.build(kind, safe, same_source)
	safe["read_only"] = true
	safe["verified"] = false
	safe["contains_snapshot_payload"] = false
	return safe


func _rejected(kind: String, code: String) -> Dictionary:
	var r := {
		"task_id": "GAME-WEB-STATE-006",
		"kind": kind,
		"status": "invalid_request",
		"error_code": code,
		"can_apply": false,
		"writes": false,
		"read_only": true,
		"verified": false,
		"contains_snapshot_payload": false
	}
	return _decorate(r, _kind_for_diagnostics(kind))


func _kind_for_diagnostics(kind: String) -> String:
	if kind == "version_difference":
		return "comparison"
	if kind == "migration_preview":
		return "preview"
	return "inspection"


func _stale_result(kind: String = "migration_preview") -> Dictionary:
	var r := {
		"task_id": "GAME-WEB-STATE-006",
		"kind": kind,
		"status": "source_unstable",
		"error_code": "SOURCE_CHANGED_OR_UNREADABLE",
		"changed_fields": [],
		"changes": [],
		"changed_field_count": 0,
		"requires_review": true,
		"mapping_approved": false,
		"can_apply": false,
		"writes": false,
		"read_only": true,
		"atomic_reads": false,
		"contains_snapshot_payload": false,
		"verified": false
	}
	return _decorate(r, _kind_for_diagnostics(kind))


func _same_observation(first: Dictionary, last: Dictionary) -> bool:
	# Best effort: status + length + decoded text hash, never an atomic read.
	return first.get("status", "") == last.get("status", "") \
		and first.get("text_sha256", "") == last.get("text_sha256", "") \
		and first.get("byte_length", -1) == last.get("byte_length", -2)


func _consistency_tag(reference: Dictionary) -> String:
	# For missing/unreadable/oversize/invalid-request there is no read
	# fingerprint. Do NOT imply that source bytes were confirmed stable.
	if reference.get("text_sha256", "").is_empty():
		return "no_payload_to_verify"
	return "best_effort_observed_same"


func inspect_folder(folder: String, mode: String) -> Dictionary:
	var issue := _context_issue(folder, mode)
	if not issue.is_empty():
		return _rejected("inspection", issue)
	var path := _file_for(folder, mode)
	var first: Dictionary = _inspector.inspect_snapshot(path, mode)
	var report: Dictionary = _inspector.report_snapshot(path, mode)
	var version: Dictionary = _inspector.report_version_delta(path, mode)
	var last: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not _same_observation(first, last):
		return _stale_result("inspection")
	if report.get("status", "") != first.get("status", "") \
		or version.get("status", "") != first.get("status", ""):
		return _stale_result("inspection")
	var safe := {
		"task_id": "GAME-WEB-STATE-006",
		"kind": "inspection",
		"inspection": report.duplicate(true),
		"version_delta": version.duplicate(true),
		"read_only": true,
		"atomic_reads": false,
		"consistency": _consistency_tag(first),
		"verified": false,
		"contains_snapshot_payload": false
	}
	return _decorate(safe, "inspection")


func compare_folders(left_folder: String, right_folder: String, mode: String) -> Dictionary:
	var left_issue := _context_issue(left_folder, mode)
	if not left_issue.is_empty():
		return _rejected("version_difference", "LEFT_" + left_issue)
	var right_issue := _context_issue(right_folder, mode)
	if not right_issue.is_empty():
		return _rejected("version_difference", "RIGHT_" + right_issue)
	var a := _file_for(left_folder, mode)
	var b := _file_for(right_folder, mode)
	var before_a: Dictionary = _inspector.inspect_snapshot(a, mode)
	var before_b: Dictionary = _inspector.inspect_snapshot(b, mode)
	var result: Dictionary = _inspector.compare_snapshot_versions(a, b, mode)
	var after_a: Dictionary = _inspector.inspect_snapshot(a, mode)
	var after_b: Dictionary = _inspector.inspect_snapshot(b, mode)
	if not _same_observation(before_a, after_a) \
		or not _same_observation(before_b, after_b):
		return _stale_result("version_difference")
	var left_report: Variant = result.get("left", {})
	var right_report: Variant = result.get("right", {})
	if typeof(left_report) != TYPE_DICTIONARY or typeof(right_report) != TYPE_DICTIONARY:
		return _stale_result("version_difference")
	if left_report.get("status", "") != before_a.get("status", "") \
		or right_report.get("status", "") != before_b.get("status", ""):
		return _stale_result("version_difference")
	result["consistency"] = "no_payload_to_verify" \
		if before_a.get("text_sha256", "").is_empty() \
		or before_b.get("text_sha256", "").is_empty() \
		else "best_effort_observed_same"
	return _decorate(result, "comparison", left_folder == right_folder)


func preview_without_target(folder: String, mode: String) -> Dictionary:
	var issue := _context_issue(folder, mode)
	if not issue.is_empty():
		return _rejected("migration_preview", issue)
	var path := _file_for(folder, mode)
	var first: Dictionary = _inspector.inspect_snapshot(path, mode)
	var report: Dictionary = _inspector.preview_migration_safe(path, mode)
	var last: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not _same_observation(first, last):
		return _stale_result("migration_preview")
	if report.get("source_status", "") != first.get("status", ""):
		return _stale_result("migration_preview")
	report["consistency"] = _consistency_tag(first)
	return _decorate(report, "preview")


func preview_candidate(
	folder: String, mode: String, phase: String, door_open: Variant
) -> Dictionary:
	var issue := _context_issue(folder, mode)
	if not issue.is_empty():
		return _rejected("migration_preview", issue)
	if not PHASES.has(phase):
		return _rejected("migration_preview", "INVALID_PROPOSED_PHASE")
	if typeof(door_open) != TYPE_BOOL:
		return _rejected("migration_preview", "INVALID_PROPOSED_DOOR")
	var path := _file_for(folder, mode)
	var first: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not first["ok"]:
		# Unknown, corrupt and foreign modes cannot be repaired.
		return preview_without_target(folder, mode)
	var target: Dictionary = first["data"].duplicate(true)
	target["phase"] = phase
	target["door_open"] = door_open
	var preview: Dictionary = _inspector.preview_migration_safe(path, mode, target)
	var last: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not last["ok"] or preview.get("source_status", "") != "valid":
		return _stale_result("migration_preview")
	if not _same_observation(first, last):
		return _stale_result("migration_preview")
	preview["consistency"] = _consistency_tag(first)
	# No payload, target dictionary or fingerprint returned to UI.
	return _decorate(preview, "preview")

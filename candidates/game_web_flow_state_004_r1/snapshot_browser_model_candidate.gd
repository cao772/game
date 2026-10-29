extends RefCounted
## GAME-WEB-PLAY-STATE-005 r1 — read-only browser application model.
## Uses unchanged pinned inspector candidate from Draft PR #13.
## Only fixed paths and allowlisted, redacted inspector APIs are exposed.
## NOT_RUN / NOT_VERIFIED / Canon N/A.

const Inspector = preload("res://snapshot_inspector_dependency.gd")
const MODES := ["story", "free"]
const PHASES := ["ready", "observing", "resolved", "deferred"]
const MAX_FOLDER_LENGTH := 512

var _inspector = Inspector.new()


func _folder_issue(folder: String) -> String:
	# No enumeration, relative-path lookup, implicit discover or scan.
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
	# Only called after checking folder/mode. No file discovery.
	return folder.path_join(mode + ".round_snapshot.json")


func _rejected(kind: String, code: String) -> Dictionary:
	return {
		"task_id": "GAME-WEB-PLAY-STATE-005",
		"kind": kind,
		"status": "invalid_request",
		"error_code": code,
		"read_only": true,
		"verified": false,
		"contains_snapshot_payload": false
	}


func _stale_result(kind: String = "migration_preview") -> Dictionary:
	return {
		"task_id": "GAME-WEB-PLAY-STATE-005",
		"kind": kind,
		"status": "source_unstable",
		"error_code": "SOURCE_CHANGED_OR_UNREADABLE",
		"changes": [],
		"changed_fields": [],
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


func _same_observation(first: Dictionary, last: Dictionary) -> bool:
	# A best-effort consistency check, NOT a file lock or atomic snapshot.
	# Detects differences between two independent decoded-text reads.
	return first.get("status", "") == last.get("status", "") 		and first.get("text_sha256", "") == last.get("text_sha256", "") 		and first.get("byte_length", -1) == last.get("byte_length", -2)


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
	if report.get("status", "") != first.get("status", "") 			or version.get("status", "") != first.get("status", ""):
		return _stale_result("inspection")
	return {
		"task_id": "GAME-WEB-PLAY-STATE-005",
		"kind": "inspection",
		"inspection": report.duplicate(true),
		"version_delta": version.duplicate(true),
		"read_only": true,
		"atomic_reads": false,
		"consistency": "best_effort_observed_same",
		"verified": false,
		"contains_snapshot_payload": false
	}


func compare_folders(
	left_folder: String, right_folder: String, mode: String
) -> Dictionary:
	var issue_left := _context_issue(left_folder, mode)
	if not issue_left.is_empty():
		return _rejected("version_difference", "LEFT_" + issue_left)
	var issue_right := _context_issue(right_folder, mode)
	if not issue_right.is_empty():
		return _rejected("version_difference", "RIGHT_" + issue_right)
	var left_path := _file_for(left_folder, mode)
	var right_path := _file_for(right_folder, mode)
	var left_before: Dictionary = _inspector.inspect_snapshot(left_path, mode)
	var right_before: Dictionary = _inspector.inspect_snapshot(right_path, mode)
	var result: Dictionary = _inspector.compare_snapshot_versions(
		left_path, right_path, mode
	)
	var left_after: Dictionary = _inspector.inspect_snapshot(left_path, mode)
	var right_after: Dictionary = _inspector.inspect_snapshot(right_path, mode)
	if not _same_observation(left_before, left_after) 			or not _same_observation(right_before, right_after):
		return _stale_result("version_difference")
	if result.get("left", {}).get("status", "") != left_before.get("status", "") 			or result.get("right", {}).get("status", "") != right_before.get("status", ""):
		return _stale_result("version_difference")
	result["consistency"] = "best_effort_observed_same"
	return result.duplicate(true)


func preview_without_target(folder: String, mode: String) -> Dictionary:
	var issue := _context_issue(folder, mode)
	if not issue.is_empty():
		return _rejected("migration_preview", issue)
	var path := _file_for(folder, mode)
	var before: Dictionary = _inspector.inspect_snapshot(path, mode)
	var preview: Dictionary = _inspector.preview_migration_safe(path, mode)
	var after: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not _same_observation(before, after):
		return _stale_result()
	if preview.get("source_status", "") != before.get("status", ""):
		return _stale_result()
	preview["consistency"] = "best_effort_observed_same"
	return preview.duplicate(true)


func preview_candidate(
	folder: String, mode: String, phase: String, door_open: Variant
) -> Dictionary:
	# No arbitrary JSON editor or exposed protected field setter.
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
		return preview_without_target(folder, mode)
	var target: Dictionary = first["data"].duplicate(true)
	# Only ephemeral hypothetical fields; source is never mutated.
	target["phase"] = phase
	target["door_open"] = door_open
	var preview: Dictionary = _inspector.preview_migration_safe(
		path, mode, target
	)
	var last: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not last["ok"] or preview.get("source_status", "") != "valid":
		return _stale_result()
	if not _same_observation(first, last):
		return _stale_result()
	preview["consistency"] = "best_effort_observed_same"
	# Never return target/detailed data/hash/path. No persistence operation.
	return preview.duplicate(true)

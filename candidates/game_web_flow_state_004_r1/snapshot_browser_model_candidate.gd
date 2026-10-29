extends RefCounted
## GAME-WEB-FLOW-STATE-004 r1
## Pure read-only UI application model. No persisted state / commands / logs.
## Uses pinned, unchanged public inspector candidate from Draft PR #13.
## NOT_RUN. Canon N/A. No approved runtime/shared API.

const Inspector = preload("res://snapshot_inspector_dependency.gd")
const MODES := ["story", "free"]
const PHASES := ["ready", "observing", "resolved", "deferred"]
const MAX_FOLDER_LENGTH := 512

var _inspector = Inspector.new()


func _folder_issue(folder: String) -> String:
	# Restrict UI to an explicitly entered user:// directory, never
	# directory enumeration, file picking, implicit search or scanning.
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
	return ""


func _context_issue(folder: String, mode: String) -> String:
	if not MODES.has(mode):
		return "INVALID_EXPECTED_MODE"
	return _folder_issue(folder)


func _file_for(folder: String, mode: String) -> String:
	# Caller must have validated _context_issue first.
	return folder.path_join(mode + ".round_snapshot.json")


func _rejected(kind: String, code: String) -> Dictionary:
	return {
		"task_id": "GAME-WEB-FLOW-STATE-004",
		"kind": kind,
		"status": "invalid_request",
		"error_code": code,
		"read_only": true,
		"verified": false,
		"contains_snapshot_payload": false
	}


func inspect_folder(folder: String, mode: String) -> Dictionary:
	var issue := _context_issue(folder, mode)
	if not issue.is_empty():
		return _rejected("inspection", issue)
	var path := _file_for(folder, mode)
	# Independent reads: not a consistency/transaction promise.
	return {
		"task_id": "GAME-WEB-FLOW-STATE-004",
		"kind": "inspection",
		"inspection": _inspector.report_snapshot(path, mode),
		"version_delta": _inspector.report_version_delta(path, mode),
		"read_only": true,
		"atomic_reads": false,
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
	return _inspector.compare_snapshot_versions(
		_file_for(left_folder, mode),
		_file_for(right_folder, mode),
		mode
	)


func preview_without_target(folder: String, mode: String) -> Dictionary:
	var issue := _context_issue(folder, mode)
	if not issue.is_empty():
		return _rejected("migration_preview", issue)
	return _inspector.preview_migration_safe(_file_for(folder, mode), mode)


func _stale_result() -> Dictionary:
	# Never return detailed inspection content or checksums on errors.
	return {
		"task_id": "GAME-WEB-FLOW-STATE-004",
		"status": "source_unstable",
		"error_code": "SOURCE_CHANGED_OR_UNREADABLE",
		"changes": [],
		"changed_field_count": 0,
		"requires_review": true,
		"mapping_approved": false,
		"can_apply": false,
		"writes": false,
		"read_only": true,
		"contains_snapshot_payload": false,
		"verified": false
	}


func preview_candidate(
	folder: String, mode: String, phase: String, door_open: Variant
) -> Dictionary:
	# UI never accepts or reconstructs a whole legacy save and never
	# fabricates a migration mapping for unknown versions.
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
		# Safe error/mapping-required report; no copy of a bad source.
		return _inspector.preview_migration_safe(path, mode)
	var target: Dictionary = first["data"].duplicate(true)
	# Only these two hypothetical fields are offered by this browser.
	# No setters for version, mode, round_id, clock_seconds.
	target["phase"] = phase
	target["door_open"] = door_open
	var preview: Dictionary = _inspector.preview_migration_safe(
		path, mode, target
	)
	var last: Dictionary = _inspector.inspect_snapshot(path, mode)
	if not last["ok"] or not preview.get("source_status", "") == "valid":
		return _stale_result()
	if first["text_sha256"] != last["text_sha256"] \
			or first["byte_length"] != last["byte_length"]:
		return _stale_result()
	# The target and copied full snapshot are never placed in the report,
	# node state, editor, logs, clipboard or filesystem.
	return preview.duplicate(true)

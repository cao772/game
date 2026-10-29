extends RefCounted
## GAME-WEB-MODULE-STATE-001 r1
## Independent, read-only inspector and manual migration-preview candidate.
## Source contract: PR #6's unchanged round_snapshot_candidate.gd (STATE r1).
## No FileAccess.WRITE, remove, rename, mkdir, global mutation, or runtime hooks.

const VERSION := 1
const MAX_BYTES := 1048576 # Candidate inspection guard; not a storage limit.
const FIELDS := [
	"version", "mode", "round_id", "phase", "door_open", "clock_seconds"
]
const MODES := ["story", "free"]
const PHASES := ["ready", "observing", "resolved", "deferred"]


func _path_error(path: String, expected_mode: String) -> String:
	if not MODES.has(expected_mode):
		return "expected_mode must be story or free"
	if not path.begins_with("user://"):
		return "Only user:// paths are supported"
	var relative := path.trim_prefix("user://")
	if relative.is_empty() or relative.contains("\\") or relative.contains(":"):
		return "Unsafe or empty path"
	for segment in relative.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return "Unsafe path segment"
	if path.get_file() != expected_mode + ".round_snapshot.json":
		return "Filename must match expected_mode"
	return ""


func _schema_error(value: Variant) -> String:
	# Intentionally mirrors the validated-field contract in PR #6,
	# not a new approved shared interface.
	if typeof(value) != TYPE_DICTIONARY:
		return "Root must be a JSON object"
	var data: Dictionary = value
	if data.size() != FIELDS.size():
		return "Unexpected or missing fields"
	for field in FIELDS:
		if not data.has(field):
			return "Missing field: " + field
	var vt := typeof(data["version"])
	if vt != TYPE_INT and vt != TYPE_FLOAT:
		return "version must be numeric 1"
	if not is_finite(float(data["version"])):
		return "version is non-finite"
	if float(data["version"]) != 1.0:
		return "Unsupported version"
	if typeof(data["mode"]) != TYPE_STRING or not MODES.has(data["mode"]):
		return "mode must be story or free"
	if typeof(data["round_id"]) != TYPE_STRING:
		return "round_id must be a string"
	if data["round_id"].strip_edges().is_empty():
		return "round_id must not be blank"
	if typeof(data["phase"]) != TYPE_STRING or not PHASES.has(data["phase"]):
		return "Invalid phase"
	if typeof(data["door_open"]) != TYPE_BOOL:
		return "door_open must be boolean"
	var clock_type := typeof(data["clock_seconds"])
	if clock_type != TYPE_INT and clock_type != TYPE_FLOAT:
		return "clock_seconds must be numeric (not boolean)"
	if not is_finite(float(data["clock_seconds"])):
		return "clock_seconds must be finite"
	if float(data["clock_seconds"]) < 0.0:
		return "clock_seconds must be non-negative"
	return ""


func _probe(path: String, expected_mode: String) -> Dictionary:
	# The 'raw' key is internal, never returned by inspect_snapshot().
	var r := {
		"status": "invalid_request",
		"error": "",
		"version_label": "unknown",
		"source_mode": "",
		"text_sha256": "",
		"byte_length": 0,
		"data": {},
		"raw": {}
	}
	var path_problem := _path_error(path, expected_mode)
	if not path_problem.is_empty():
		r["error"] = path_problem
		return r
	if DirAccess.dir_exists_absolute(path):
		r["status"] = "unreadable"
		r["error"] = "Path names a directory"
		return r
	if not FileAccess.file_exists(path):
		r["status"] = "missing"
		r["error"] = "Snapshot file does not exist"
		return r
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		r["status"] = "unreadable"
		r["error"] = "Cannot open snapshot"
		return r
	r["byte_length"] = f.get_length()
	if r["byte_length"] > MAX_BYTES:
		f.close()
		r["status"] = "too_large"
		r["error"] = "Inspection size guard exceeded"
		return r
	var content := f.get_as_text()
	f.close()
	r["text_sha256"] = content.sha256_text()
	var parser := JSON.new()
	var parse_code := parser.parse(content)
	if parse_code != OK:
		r["status"] = "malformed_json"
		r["error"] = parser.get_error_message()
		return r
	if typeof(parser.data) != TYPE_DICTIONARY:
		r["status"] = "invalid_schema"
		r["error"] = "Root must be a JSON object"
		return r
	var raw: Dictionary = parser.data
	r["raw"] = raw.duplicate(true)
	if not raw.has("version"):
		r["status"] = "invalid_schema"
		r["error"] = "Missing version"
		return r
	r["version_label"] = str(raw["version"])
	var vt := typeof(raw["version"])
	if vt != TYPE_INT and vt != TYPE_FLOAT:
		r["status"] = "invalid_schema"
		r["error"] = "Invalid version type"
		return r
	if not is_finite(float(raw["version"])):
		r["status"] = "invalid_schema"
		r["error"] = "Non-finite version"
		return r
	if float(raw["version"]) != 1.0:
		r["status"] = "unsupported_version"
		r["error"] = "No approved source-version mapping"
		return r
	if raw.has("mode") and typeof(raw["mode"]) == TYPE_STRING:
		r["source_mode"] = raw["mode"]
		if MODES.has(raw["mode"]) and raw["mode"] != expected_mode:
			r["status"] = "mode_mismatch"
			r["error"] = "Contents belong to a different mode"
			return r
	var problem := _schema_error(raw)
	if not problem.is_empty():
		r["status"] = "invalid_schema"
		r["error"] = problem
		return r
	r["status"] = "valid"
	var copy: Dictionary = raw.duplicate(true)
	copy["version"] = VERSION
	r["data"] = copy.duplicate(true)
	return r


func inspect_snapshot(path: String, expected_mode: String) -> Dictionary:
	var result := _probe(path, expected_mode)
	# Copy only the validated data, not arbitrary corrupt/legacy payload.
	return {
		"ok": result["status"] == "valid",
		"status": result["status"],
		"error": result["error"],
		"version_label": result["version_label"],
		"source_mode": result["source_mode"],
		"expected_mode": expected_mode,
		"text_sha256": result["text_sha256"],
		"byte_length": result["byte_length"],
		"data": result["data"].duplicate(true)
	}


func inspect_pair(folder: String) -> Dictionary:
	# Two independent reads: not an atomic pair or cross-file transaction.
	var story_path := folder.path_join("story.round_snapshot.json")
	var free_path := folder.path_join("free.round_snapshot.json")
	return {
		"story": inspect_snapshot(story_path, "story"),
		"free": inspect_snapshot(free_path, "free")
	}


func _changes(source: Dictionary, proposed: Dictionary) -> Array:
	var keys: Array = []
	for key in source.keys():
		if not keys.has(key):
			keys.append(key)
	for key in proposed.keys():
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var changes: Array = []
	for key in keys:
		var from_exists := source.has(key)
		var to_exists := proposed.has(key)
		var kind := ""
		if not from_exists:
			kind = "add"
		elif not to_exists:
			kind = "remove"
		elif source[key] != proposed[key]:
			kind = "change"
		if not kind.is_empty():
			changes.append({
				"field": key,
				"kind": kind,
				"before": source[key] if from_exists else null,
				"after": proposed[key] if to_exists else null
			})
	return changes


func preview_migration(
	path: String, expected_mode: String, proposed_target: Variant = null
) -> Dictionary:
	# No inferred v0 schema, no automatic repair, no write API.
	# A caller-provided target must be a complete valid v1 object.
	var source := _probe(path, expected_mode)
	var report := {
		"ok": false,
		"status": "blocked",
		"source_status": source["status"],
		"source_version": source["version_label"],
		"target_version": VERSION,
		"expected_mode": expected_mode,
		"text_sha256": source["text_sha256"],
		"changes": [],
		"requires_review": true,
		"can_apply": false,
		"writes": false,
		"error": source["error"]
	}
	if source["status"] == "valid" and proposed_target == null:
		report["ok"] = true
		report["status"] = "no_migration_needed"
		report["error"] = ""
		return report
	if proposed_target == null:
		if source["status"] == "unsupported_version":
			report["status"] = "mapping_required"
		return report
	if typeof(source["raw"]) != TYPE_DICTIONARY or source["raw"].is_empty():
		report["error"] = "Source is not a parsable JSON object"
		return report
	if source["status"] == "mode_mismatch":
		report["error"] = "Cross-mode preview is prohibited"
		return report
	var target_problem := _schema_error(proposed_target)
	if not target_problem.is_empty():
		report["status"] = "invalid_target"
		report["error"] = target_problem
		return report
	if proposed_target["mode"] != expected_mode:
		report["status"] = "invalid_target"
		report["error"] = "Target mode does not match expected_mode"
		return report
	var source_object: Dictionary = source["raw"]
	var target_object: Dictionary = proposed_target
	report["changes"] = _changes(
		source_object.duplicate(true), target_object.duplicate(true)
	)
	report["ok"] = true
	report["error"] = ""
	if source["status"] == "valid" and report["changes"].is_empty():
		report["status"] = "no_changes"
	elif source["status"] == "valid":
		report["status"] = "same_version_proposal"
	else:
		report["status"] = "manual_unverified_preview"
	return report

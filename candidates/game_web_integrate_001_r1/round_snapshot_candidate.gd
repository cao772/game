extends RefCounted
## GAME-WEB-STATE-001 r1
## Independent round snapshot candidate.
## Single-writer proposal. No global state or runtime integration.

const VERSION := 1
const FIELDS := [
	"version",
	"mode",
	"round_id",
	"phase",
	"door_open",
	"clock_seconds"
]
const MODES := ["story", "free"]
const PHASES := ["ready", "observing", "resolved", "deferred"]


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": message
	}


func _schema_error(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return "Root must be a JSON object"

	var data: Dictionary = value

	if data.size() != FIELDS.size():
		return "Unexpected or missing fields"

	for field in FIELDS:
		if not data.has(field):
			return "Missing field: " + field

	var version_value: Variant = data["version"]
	var version_type := typeof(version_value)

	# Godot JSON may decode JSON numbers as floats.
	if version_type != TYPE_INT and version_type != TYPE_FLOAT:
		return "version must be numeric 1"

	if not is_finite(float(version_value)):
		return "version is non-finite"

	if float(version_value) != 1.0:
		return "Unsupported version"

	if typeof(data["mode"]) != TYPE_STRING:
		return "mode must be a string"

	if not MODES.has(data["mode"]):
		return "Unsupported mode"

	if typeof(data["round_id"]) != TYPE_STRING:
		return "round_id must be a string"

	if data["round_id"].strip_edges().is_empty():
		return "round_id must not be empty"

	if typeof(data["phase"]) != TYPE_STRING:
		return "phase must be a string"

	if not PHASES.has(data["phase"]):
		return "Unsupported phase"

	if typeof(data["door_open"]) != TYPE_BOOL:
		return "door_open must be boolean"

	var clock_value: Variant = data["clock_seconds"]
	var clock_type := typeof(clock_value)

	if clock_type != TYPE_INT and clock_type != TYPE_FLOAT:
		return "clock_seconds must be numeric, not boolean"

	var seconds := float(clock_value)

	if not is_finite(seconds):
		return "clock_seconds must be finite"

	if seconds < 0.0:
		return "clock_seconds must be non-negative"

	return ""


func _path_error(path: String, mode: String) -> String:
	if not MODES.has(mode):
		return "Invalid expected mode"

	if not path.begins_with("user://"):
		return "Only user:// paths are allowed"

	var relative := path.trim_prefix("user://")

	if relative.is_empty():
		return "Empty path"

	if relative.contains("\\") or relative.contains(":"):
		return "Invalid path syntax"

	for segment in relative.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return "Unsafe path segment"

	var required_name := mode + ".round_snapshot.json"

	if path.get_file() != required_name:
		return "Snapshot filename does not match mode"

	return ""


func load_snapshot(path: String, expected_mode: String) -> Dictionary:
	var path_problem := _path_error(path, expected_mode)

	if not path_problem.is_empty():
		return _failure(path_problem)

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return _failure("Cannot open snapshot for reading")

	var content := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var parse_error := parser.parse(content)

	if parse_error != OK:
		return _failure("Invalid JSON: " + parser.get_error_message())

	var parsed: Variant = parser.data
	var schema_problem := _schema_error(parsed)

	if not schema_problem.is_empty():
		return _failure(schema_problem)

	if parsed["mode"] != expected_mode:
		return _failure("Snapshot mode mismatch")

	# Normalize JSON numeric representation of protocol version.
	var result: Dictionary = parsed.duplicate(true)
	result["version"] = VERSION

	return {
		"ok": true,
		"data": result.duplicate(true),
		"error": ""
	}


func save_snapshot(path: String, data: Variant) -> Dictionary:
	var schema_problem := _schema_error(data)

	if not schema_problem.is_empty():
		return _failure(schema_problem)

	var mode: String = data["mode"]
	var path_problem := _path_error(path, mode)

	if not path_problem.is_empty():
		return _failure(path_problem)

	var folder := path.get_base_dir()

	if not DirAccess.dir_exists_absolute(folder):
		return _failure("Destination directory does not exist")

	if DirAccess.dir_exists_absolute(path):
		return _failure("Destination is a directory")

	# Never silently replace corrupt or foreign-mode content.
	if FileAccess.file_exists(path):
		var old_result := load_snapshot(path, mode)

		if not old_result["ok"]:
			return _failure(
				"Existing snapshot rejected: " + old_result["error"]
			)

	# Fixed same-directory temporary name, single writer only.
	var temporary_path := path + ".tmp"

	if FileAccess.file_exists(temporary_path):
		return _failure("Temporary file already exists")

	if DirAccess.dir_exists_absolute(temporary_path):
		return _failure("Temporary path is occupied")

	var output := FileAccess.open(
		temporary_path,
		FileAccess.WRITE
	)

	if output == null:
		return _failure("Cannot create temporary file")

	var serialized := JSON.stringify(data, "", true, true)

	var wrote: bool = output.store_string(serialized)
	output.flush()

	var io_ok := wrote and output.get_error() == OK
	output.close()

	if not io_ok:
		DirAccess.remove_absolute(temporary_path)
		return _failure("Temporary write failed")

	# No delete-before-rename. A failed rename leaves
	# the original destination untouched by this code.
	var rename_error := DirAccess.rename_absolute(
		temporary_path,
		path
	)

	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return _failure(
			"Rename failed: " + str(rename_error)
		)

	return {
		"ok": true,
		"error": ""
	}

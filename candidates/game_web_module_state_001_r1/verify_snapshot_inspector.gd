extends SceneTree
## GAME-WEB-MODULE-STATE-001 r1
## FUTURE ACCEPTANCE ONLY. Do not infer a PASS without Codex execution.
## Fixture creation and cleanup are confined to a unique user:// directory.

const Inspector = preload("res://snapshot_inspector_candidate.gd")

var _root := ""
var _owned_files: Array[String] = []
var _owned_dirs: Array[String] = []
var _passes := 0
var _failures := 0


func _check(condition: bool, name: String) -> void:
	if condition:
		_passes += 1
		print("PASS ", name)
	else:
		_failures += 1
		printerr("FAIL ", name)


func _sample(mode: String, round_id: String) -> Dictionary:
	return {
		"version": 1,
		"mode": mode,
		"round_id": round_id,
		"phase": "ready",
		"door_open": false,
		"clock_seconds": 12.5
	}


func _case_dir(name: String) -> String:
	var path := _root.path_join(name)
	if DirAccess.dir_exists_absolute(path):
		_check(false, "No pre-existing case directory " + name)
		return ""
	var error := DirAccess.make_dir_absolute(path)
	if error != OK:
		_check(false, "Create case directory " + name)
		return ""
	_owned_dirs.append(path)
	return path


func _write(path: String, content: String) -> bool:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_check(false, "Fixture path collision")
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_check(false, "Create fixture file")
		return false
	_owned_files.append(path)
	f.store_string(content)
	f.flush()
	var good := f.get_error() == OK
	f.close()
	_check(good, "Fixture written " + path.get_base_dir().get_file())
	return good


func _fixture(label: String, mode: String, raw: String) -> String:
	var folder := _case_dir(label)
	if folder.is_empty():
		return ""
	var path := folder.path_join(mode + ".round_snapshot.json")
	if not _write(path, raw):
		return ""
	return path


func _invalid(
	inspector, label: String, raw: String, status: String
) -> void:
	var path := _fixture(label, "story", raw)
	if path.is_empty():
		return
	var bytes_before := FileAccess.get_file_as_bytes(path)
	var result: Dictionary = inspector.inspect_snapshot(path, "story")
	var expected_status := result["status"] == status
	if label == "nonfinite":
		# Parser may reject overflow itself or produce an invalid float.
		expected_status = result["status"] == "malformed_json" or result["status"] == "invalid_schema"
	_check(not result["ok"] and expected_status,
		"Inspect " + label + " as invalid")
	_check(result["data"].is_empty(), "No unsafe data exposure " + label)
	var preview: Dictionary = inspector.preview_migration(path, "story")
	_check(not preview["ok"], "No automatic migration " + label)
	_check(FileAccess.get_file_as_bytes(path) == bytes_before,
		"Read-only invalid inspection " + label)


func _run() -> void:
	var inspector = Inspector.new()
	var story := _sample("story", "s-001")
	var free := _sample("free", "f-001")
	var story_path := _root.path_join("story.round_snapshot.json")
	var free_path := _root.path_join("free.round_snapshot.json")
	if not _write(story_path, JSON.stringify(story)):
		return
	if not _write(free_path, JSON.stringify(free)):
		return
	var before_story := FileAccess.get_file_as_bytes(story_path)
	var before_free := FileAccess.get_file_as_bytes(free_path)

	# 1. Both modes and exact v1 schema.
	var pair: Dictionary = inspector.inspect_pair(_root)
	_check(pair["story"]["ok"] and pair["free"]["ok"],
		"Inspect both independent modes")
	_check(pair["story"]["data"]["round_id"] == "s-001",
		"Story content")
	_check(pair["free"]["data"]["round_id"] == "f-001",
		"Free content")
	_check(pair["story"]["version_label"] != "unknown",
		"Version recognized")
	_check(inspector.preview_migration(story_path, "story")["status"]
		== "no_migration_needed", "Current v1 requires no migration")
	_check(not inspector.inspect_snapshot(story_path, "free")["ok"],
		"Cross-mode filename not accepted")
	_check(not inspector.inspect_snapshot(free_path, "story")["ok"],
		"Reverse cross-mode filename not accepted")

	# 2. Deep copy and same-version manual preview (no commit).
	var first: Dictionary = inspector.inspect_snapshot(story_path, "story")
	var second: Dictionary = inspector.inspect_snapshot(story_path, "story")
	first["data"]["round_id"] = "tampered-locally"
	_check(second["data"]["round_id"] == "s-001",
		"Independent result dictionaries")
	_check(inspector.inspect_snapshot(story_path, "story")["data"]["round_id"]
		== "s-001", "Inspector never mutates disk or shared data")

	var target := story.duplicate(true)
	target["phase"] = "resolved"
	target["door_open"] = true
	var diff: Dictionary = inspector.preview_migration(
		story_path, "story", target
	)
	_check(diff["ok"] and diff["status"] == "same_version_proposal",
		"Preview only, no same-version migration claim")
	_check(diff["changes"].size() == 2,
		"Exact two-field differences")
	_check(diff["requires_review"] and not diff["can_apply"]
		and not diff["writes"], "Preview cannot apply")
	target["phase"] = "deferred"
	var redacted := true
	for change in diff["changes"]:
		if change.has("before") or change.has("after"):
			redacted = false
	_check(redacted, "Preview never leaks before/after field values")
	_check(diff["changes"].size() == 2,
		"Changes independent of target later mutation")

	# 3. Unsupported version: detect, no guessed automatic mapping.
	var legacy := _sample("story", "legacy-01")
	legacy["version"] = 0
	var legacy_path := _fixture(
		"legacy_v0", "story", JSON.stringify(legacy)
	)
	if not legacy_path.is_empty():
		var unknown := inspector.inspect_snapshot(legacy_path, "story")
		_check(unknown["status"] == "unsupported_version",
			"Recognize unsupported numeric version")
		_check(inspector.preview_migration(legacy_path, "story")["status"]
			== "mapping_required", "No invented v0 mapping")
		var legacy_before := FileAccess.get_file_as_bytes(legacy_path)
		var manual: Dictionary = inspector.preview_migration(
			legacy_path, "story", story
		)
		_check(manual["ok"]
			and manual["status"] == "manual_unverified_preview",
			"Caller-supplied target creates unverified diff only")
		_check(manual["changes"].size() >= 1 and not manual["can_apply"],
			"Legacy preview is never executable")
		_check(FileAccess.get_file_as_bytes(legacy_path) == legacy_before,
			"Legacy source bytes unchanged")

	# 4. Unsupported target / cross-mode target.
	var bad_target := story.duplicate(true)
	bad_target["phase"] = "unapproved"
	_check(inspector.preview_migration(
		story_path, "story", bad_target
	)["status"] == "invalid_target", "Reject malformed target")
	_check(inspector.preview_migration(
		story_path, "story", free
	)["status"] == "invalid_target", "Reject cross-mode target")

	# 5. Damaged JSON, v2, missing/extra fields, illegal types.
	_invalid(inspector, "broken", '{"version":',
		"malformed_json")
	_invalid(inspector, "root_array", "[]", "invalid_schema")
	var v2 := story.duplicate(true)
	v2["version"] = 2
	_invalid(inspector, "v2", JSON.stringify(v2),
		"unsupported_version")
	var missing := story.duplicate(true)
	missing.erase("phase")
	_invalid(inspector, "missing_field", JSON.stringify(missing),
		"invalid_schema")
	var extra := story.duplicate(true)
	extra["unexpected"] = "x"
	_invalid(inspector, "extra_field", JSON.stringify(extra),
		"invalid_schema")
	var boolean_clock := story.duplicate(true)
	boolean_clock["clock_seconds"] = true
	_invalid(inspector, "bool_clock", JSON.stringify(boolean_clock),
		"invalid_schema")
	var negative_clock := story.duplicate(true)
	negative_clock["clock_seconds"] = -1.0
	_invalid(inspector, "negative_clock", JSON.stringify(negative_clock),
		"invalid_schema")
	var wrong_mode := _sample("free", "wrong-file")
	_invalid(inspector, "foreign_content", JSON.stringify(wrong_mode),
		"mode_mismatch")
	_invalid(inspector, "nonfinite", '{"version":1,"mode":"story",'
		+ '"round_id":"n","phase":"ready","door_open":false,'
		+ '"clock_seconds":1e999}', "invalid_schema")

	# 6. Max byte guard and missing path.
	var large := story.duplicate(true)
	large["round_id"] = "z".repeat(Inspector.MAX_BYTES + 1)
	var large_path := _fixture(
		"too_large", "story", JSON.stringify(large)
	)
	if not large_path.is_empty():
		_check(inspector.inspect_snapshot(large_path, "story")["status"]
			== "too_large", "Oversized input guarded")
	_check(inspector.inspect_snapshot(
		_root.path_join("absent/story.round_snapshot.json"), "story"
	)["status"] == "missing", "Missing source recognized")
	_check(inspector.inspect_snapshot(
		_root + "/../story.round_snapshot.json", "story"
	)["status"] == "invalid_request", "Reject traversal")
	_check(inspector.inspect_snapshot(
		"res://story.round_snapshot.json", "story"
	)["status"] == "invalid_request", "Reject res:// access")

	# 7. Read-only proof: compare raw bytes after ALL operations.
	_check(FileAccess.get_file_as_bytes(story_path) == before_story,
		"Story bytes unchanged across all previews")
	_check(FileAccess.get_file_as_bytes(free_path) == before_free,
		"Free bytes unchanged across all previews")
	_check(not FileAccess.file_exists(story_path + ".tmp"),
		"Inspector created no story temporary file")
	_check(not FileAccess.file_exists(free_path + ".tmp"),
		"Inspector created no free temporary file")


func _cleanup() -> void:
	for path in _owned_files:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK,
				"Cleanup owned fixture " + path.get_file())
	for i in range(_owned_dirs.size() - 1, -1, -1):
		var dir_path := _owned_dirs[i]
		if DirAccess.dir_exists_absolute(dir_path):
			_check(DirAccess.remove_absolute(dir_path) == OK,
				"Cleanup owned fixture directory")


func _init() -> void:
	_root = "user://w_module_state_%s_%s" % [
		str(OS.get_process_id()), str(Time.get_ticks_usec())
	]
	if DirAccess.dir_exists_absolute(_root):
		printerr("FAIL: test directory collision")
		quit(1)
		return
	if DirAccess.make_dir_absolute(_root) != OK:
		printerr("FAIL: cannot create test directory")
		quit(1)
		return
	_owned_dirs.append(_root)
	_run()
	_cleanup()
	print("GAME-WEB-MODULE-STATE-001 r1: ", _passes,
		" passed; ", _failures, " failed")
	if _failures > 0:
		printerr("FAIL GAME-WEB-MODULE-STATE-001 r1")
		quit(1)
	else:
		print("PASS GAME-WEB-MODULE-STATE-001 r1")
		quit(0)

extends SceneTree
## GAME-WEB-FLOW-STATE-004 r1
## FUTURE TEST SOURCE ONLY: DO NOT RUN DURING AUTHORING. NOT_RUN.
## Only synthetic fixtures under this script's fresh user:// directory.
const Model = preload("res://snapshot_browser_model_candidate.gd")

const MARKER := "synthetic-secret-004"
var _root := ""
var _files: Array[String] = []
var _dirs: Array[String] = []
var _passed := 0
var _failed := 0


func _check(ok: bool, case_name: String) -> void:
	if ok:
		_passed += 1
		print("PASS ", case_name)
	else:
		_failed += 1
		printerr("FAIL ", case_name)


func _snapshot(mode: String = "story") -> Dictionary:
	return {
		"version": 1,
		"mode": mode,
		"round_id": MARKER,
		"phase": "ready",
		"door_open": false,
		"clock_seconds": 12.5
	}


func _new_folder(name: String) -> String:
	var path := _root.path_join(name)
	if DirAccess.dir_exists_absolute(path):
		_check(false, "fixture-directory-collision")
		return ""
	if DirAccess.make_dir_absolute(path) != OK:
		_check(false, "fixture-directory-create")
		return ""
	_dirs.append(path)
	return path


func _write(folder: String, mode: String, data: String) -> bool:
	var path := folder.path_join(mode + ".round_snapshot.json")
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_check(false, "fixture-file-collision")
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "fixture-open")
		return false
	_files.append(path)
	file.store_string(data)
	file.flush()
	var good := file.get_error() == OK
	file.close()
	_check(good, "fixture-write")
	return good


func _safe(report: Dictionary) -> bool:
	var text_value := JSON.stringify(report)
	return not text_value.contains(MARKER) \
		and not text_value.contains(_root) \
		and not text_value.contains("text_sha256") \
		and not text_value.contains('"data"') \
		and not text_value.contains('"raw"')


func _run_cases() -> void:
	var model = Model.new()
	var empty := model.inspect_folder("", "story")
	_check(empty["status"] == "invalid_request"
		and empty["error_code"] == "FOLDER_REQUIRED", "M01 empty is denied")
	_check(model.inspect_folder("res://foo", "story")["status"]
		== "invalid_request", "M02 non-user path denied")
	_check(model.inspect_folder("user://a/../b", "story")["status"]
		== "invalid_request", "M03 traversal denied")
	_check(model.inspect_folder("user://foo/", "story")["status"]
		== "invalid_request", "M04 trailing slash denied")
	_check(model.inspect_folder("user://foo", "invalid")["status"]
		== "invalid_request", "M05 invalid mode denied")
	_check(model.compare_folders("user://good", "", "story")["error_code"]
		== "RIGHT_FOLDER_REQUIRED", "M06 right missing is clear")
	_check(model.preview_without_target("user://missing", "story")["status"]
		== "blocked", "M07 missing snapshot safely blocks preview")
	_check(_safe(model.inspect_folder("user://missing", "story")),
		"M08 safe error report")

	var left := _new_folder("left")
	var right := _new_folder("right")
	var unsupported := _new_folder("unsupported")
	var broken := _new_folder("broken")
	var foreign := _new_folder("foreign")
	if left.is_empty() or right.is_empty() or unsupported.is_empty() \
			or broken.is_empty() or foreign.is_empty():
		return
	if not _write(left, "story", JSON.stringify(_snapshot())):
		return
	if not _write(left, "free", JSON.stringify(_snapshot("free"))):
		return
	var right_value := _snapshot()
	right_value["door_open"] = true
	right_value["phase"] = "resolved"
	if not _write(right, "story", JSON.stringify(right_value)):
		return
	var old_value := _snapshot()
	old_value["version"] = 2
	if not _write(unsupported, "story", JSON.stringify(old_value)):
		return
	if not _write(broken, "story", "{\"version\":"):
		return
	if not _write(foreign, "story", JSON.stringify(_snapshot("free"))):
		return
	var left_story_path := left.path_join("story.round_snapshot.json")
	var right_story_path := right.path_join("story.round_snapshot.json")
	var left_before := FileAccess.get_file_as_bytes(left_story_path)
	var right_before := FileAccess.get_file_as_bytes(right_story_path)

	var overview := model.inspect_folder(left, "story")
	_check(overview["kind"] == "inspection"
		and overview["inspection"]["valid"], "M09 story inspection")
	_check(overview["version_delta"]["status"] == "valid",
		"M10 version delta displayed")
	_check(overview["version_delta"]["numeric_relation"]
		== "same_numeric_version", "M11 same version")
	_check(not overview["atomic_reads"], "M12 no atomic read claim")
	_check(_safe(overview), "M13 inspected report redacted")

	var free := model.inspect_folder(left, "free")
	_check(free["inspection"]["valid"]
		and free["inspection"]["source_mode"] == "free",
		"M14 free slot independent")
	var missing_right := model.inspect_folder(right, "free")
	_check(missing_right["inspection"]["status"] == "missing",
		"M15 never fall back from missing free to story")

	var diff := model.compare_folders(left, right, "story")
	_check(diff["status"] == "comparable_v1"
		and diff["changed_field_count"] == 2,
		"M16 valid v1 field comparison")
	_check(not diff["can_migrate"] and not diff["atomic_pair"],
		"M17 version differences never authorize migration")
	_check(_safe(diff), "M18 diff redacted")
	var field_only := true
	for entry in diff["changed_fields"]:
		if entry.has("before") or entry.has("after") \
				or not Model.PHASES.has(entry.get("field", "")) \
				and not ["door_open", "version", "mode", "round_id", "clock_seconds"].has(entry.get("field", "")):
			field_only = false
	_check(field_only, "M19 only known changes")

	var empty_preview := model.preview_without_target(left, "story")
	_check(empty_preview["status"] == "no_migration_needed",
		"M20 existing v1 needs no migration")
	_check(_safe(empty_preview), "M21 no target preview safe")
	var phase_preview := model.preview_candidate(
		left, "story", "observing", false
	)
	_check(phase_preview["status"] == "same_version_review_only"
		and phase_preview["changed_field_count"] == 1,
		"M22 phase hypothetical change")
	_check(not phase_preview["can_apply"]
		and not phase_preview["writes"], "M23 preview never writes")
	_check(_safe(phase_preview), "M24 hypothetical preview redacted")
	var door_preview := model.preview_candidate(
		left, "story", "ready", true
	)
	_check(door_preview["status"] == "same_version_review_only"
		and door_preview["changed_field_count"] == 1,
		"M25 boolean hypothetical change")
	_check(model.preview_candidate(left, "story", "invalid_phase", false)["status"]
		== "invalid_request", "M26 invalid proposed phase denied")
	_check(model.preview_candidate(left, "story", "ready", 1)["status"]
		== "invalid_request", "M27 proposed door rejects nonboolean")

	var legacy := model.preview_candidate(unsupported, "story", "ready", false)
	_check(legacy["status"] == "mapping_required"
		and not legacy["can_apply"], "M28 unsupported cannot be migrated")
	var damaged := model.preview_candidate(broken, "story", "ready", false)
	_check(damaged["status"] == "blocked" and damaged["changes"].is_empty(),
		"M29 damaged file not repaired")
	var wrong_mode := model.preview_candidate(foreign, "story", "ready", false)
	_check(wrong_mode["status"] == "blocked",
		"M30 foreign mode not previewed")
	var no_map_diff := model.compare_folders(unsupported, left, "story")
	_check(no_map_diff["status"] == "unmapped_versions"
		and no_map_diff["changed_fields"].is_empty(),
		"M31 different schema cannot compare field values")

	_check(FileAccess.get_file_as_bytes(left_story_path) == left_before,
		"M32 inspected source unchanged")
	_check(FileAccess.get_file_as_bytes(right_story_path) == right_before,
		"M33 compared source unchanged")
	_check(not FileAccess.file_exists(left_story_path + ".tmp"),
		"M34 no file write temp artifact")


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK, "cleanup-file")
	for i in range(_dirs.size() - 1, -1, -1):
		if DirAccess.dir_exists_absolute(_dirs[i]):
			_check(DirAccess.remove_absolute(_dirs[i]) == OK, "cleanup-folder")


func _init() -> void:
	_root = "user://w_flow_state_004_%s_%s" % [
		str(OS.get_process_id()), str(Time.get_ticks_usec())
	]
	if DirAccess.dir_exists_absolute(_root):
		printerr("FAIL isolated directory collision")
		quit(1)
		return
	if DirAccess.make_dir_absolute(_root) != OK:
		printerr("FAIL isolated directory creation")
		quit(1)
		return
	_dirs.append(_root)
	_run_cases()
	_cleanup()
	print("W-FLOW-STATE-004 model future cases: ", _passed,
		" passed; ", _failed, " failed")
	quit(1 if _failed > 0 else 0)

extends SceneTree
## GAME-WEB-MODULE-STATE-002 r1 — FUTURE TEST SOURCE, NOT_RUN.
## Only this test writes synthetic fixtures under one new user:// directory.
const Inspector = preload("res://snapshot_inspector_candidate.gd")
const PRIVATE_MARKER := "synthetic_private_marker_do_not_publish"

var _root := ""
var _files: Array[String] = []
var _dirs: Array[String] = []
var _pass := 0
var _fail := 0


func _assert(ok: bool, case_id: String) -> void:
	if ok:
		_pass += 1
		print("PASS ", case_id)
	else:
		_fail += 1
		printerr("FAIL ", case_id)


func _sample(mode: String = "story") -> Dictionary:
	return {
		"version": 1, "mode": mode, "round_id": PRIVATE_MARKER,
		"phase": "ready", "door_open": false, "clock_seconds": 10.25
	}


func _fixture(name: String, mode: String, json_text: String) -> String:
	var folder := _root.path_join(name)
	if DirAccess.dir_exists_absolute(folder):
		_assert(false, "fixture-dir-collision")
		return ""
	if DirAccess.make_dir_absolute(folder) != OK:
		_assert(false, "fixture-dir-create")
		return ""
	_dirs.append(folder)
	var path := folder.path_join(mode + ".round_snapshot.json")
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_assert(false, "fixture-file-collision")
		return ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_assert(false, "fixture-file-open")
		return ""
	_files.append(path)
	file.store_string(json_text)
	file.flush()
	var valid := file.get_error() == OK
	file.close()
	_assert(valid, "fixture-file-write")
	if not valid:
		return ""
	return path


func _has_no_payload(value: Dictionary) -> bool:
	var text := JSON.stringify(value)
	return not text.contains(PRIVATE_MARKER) \
		and not text.contains("round_id") \
		and not text.contains(_root) \
		and not text.contains("text_sha256")


func _run() -> void:
	var inspector = Inspector.new()
	var story := _sample()
	var story_path := _fixture("valid_story", "story", JSON.stringify(story))
	if story_path.is_empty():
		return
	var before := FileAccess.get_file_as_bytes(story_path)
	var report: Dictionary = inspector.report_snapshot(story_path, "story")
	_assert(report["valid"] and report["status"] == "valid",
		"R01 valid report")
	_assert(report["compatibility"]["classification"] == "compatible_v1",
		"R02 v1 compatibility")
	_assert(report["compatibility"]["automatic_migration_supported"] == false,
		"R03 never auto-upgrade")
	_assert(report["source_mode"] == "story" and report["version_label"] == "1",
		"R04 safe metadata")
	_assert(_has_no_payload(report), "R05 report redacted")
	_assert(not report.has("data") and not report.has("raw"),
		"R06 no source payload in report")
	_assert(inspector.compatibility_snapshot(story_path, "story")["classification"]
		== "compatible_v1", "R07 compatibility helper")
	_assert(inspector.preview_migration(story_path, "story")["status"]
		== "no_migration_needed", "R08 valid v1 no migration")

	var target := story.duplicate(true)
	target["phase"] = "resolved"
	target["round_id"] = "changed_" + PRIVATE_MARKER
	var change: Dictionary = inspector.preview_migration(story_path, "story", target)
	_assert(change["ok"] and change["status"] == "same_version_proposal",
		"R09 current-format proposal")
	_assert(change["changes"].size() == 2, "R10 structural diff only")
	_assert(not change["can_apply"] and not change["writes"]
		and not change["mapping_approved"], "R11 explicitly unappliable")
	var safe_changes := true
	for item in change["changes"]:
		if item.has("before") or item.has("after") or not Inspector.FIELDS.has(item["field"]):
			safe_changes = false
	_assert(safe_changes, "R12 no values or arbitrary keys leaked")
	_assert(not JSON.stringify(change).contains(PRIVATE_MARKER),
		"R13 preview redacted")
	target["phase"] = "deferred"
	_assert(change["changes"].size() == 2, "R14 copied diff")

	var legacy := _sample()
	legacy["version"] = 0
	legacy[PRIVATE_MARKER] = "secret_" + PRIVATE_MARKER
	var v0_path := _fixture("unsupported", "story", JSON.stringify(legacy))
	if not v0_path.is_empty():
		var v0_report: Dictionary = inspector.report_snapshot(v0_path, "story")
		_assert(v0_report["status"] == "unsupported_version",
			"R15 unsupported numeric version")
		_assert(v0_report["compatibility"]["classification"] == "unsupported",
			"R16 no inferred version mapping")
		_assert(inspector.preview_migration(v0_path, "story")["status"]
			== "mapping_required", "R17 no target requires mapping")
		var manually := inspector.preview_migration(v0_path, "story", story)
		_assert(manually["ok"] and manually["status"] == "manual_unverified_preview",
			"R18 caller-supplied structural preview only")
		_assert(manually["unrecognized_source_field_count"] == 1,
			"R19 opaque unknown field count")
		_assert(not manually["can_apply"] and not manually["mapping_approved"],
			"R20 no approval of unknown layout")
		_assert(not JSON.stringify(manually).contains(PRIVATE_MARKER),
			"R21 no private key/value in output")

	var foreign := _sample("free")
	foreign["version"] = 0
	var foreign_path := _fixture("cross_mode_old", "story", JSON.stringify(foreign))
	if not foreign_path.is_empty():
		_assert(inspector.report_snapshot(foreign_path, "story")["status"]
			== "mode_mismatch", "R22 cross mode takes precedence")
		_assert(not inspector.preview_migration(foreign_path, "story", story)["ok"],
			"R23 cross-mode cannot preview")

	var mode_missing := legacy.duplicate(true)
	mode_missing.erase("mode")
	var missing_mode_path := _fixture(
		"missing_mode_old", "story", JSON.stringify(mode_missing)
	)
	if not missing_mode_path.is_empty():
		var unknown_mode := inspector.report_snapshot(missing_mode_path, "story")
		_assert(unknown_mode["status"] == "invalid_schema",
			"R24 unknown mode is invalid")
		_assert(unknown_mode["compatibility"]["classification"] == "invalid",
			"R25 unknown mode cannot claim support")
		_assert(not inspector.preview_migration(
			missing_mode_path, "story", story
		)["ok"], "R26 no preview if source mode unverified")

	var invalid_schema := _sample()
	invalid_schema.erase("phase")
	var bad_v1_path := _fixture("invalid_v1", "story", JSON.stringify(invalid_schema))
	if not bad_v1_path.is_empty():
		var bad_report := inspector.report_snapshot(bad_v1_path, "story")
		_assert(bad_report["status"] == "invalid_schema"
			and bad_report["error_code"] == "MISSING_FIELD"
			and bad_report["error_field"] == "phase",
			"R27 structured schema failure")
		_assert(not inspector.preview_migration(bad_v1_path, "story", story)["ok"],
			"R28 invalid v1 cannot be rescued by target")
		_assert(_has_no_payload(bad_report), "R29 invalid report sanitized")

	var damaged_path := _fixture("damaged", "story", '{"version":')
	if not damaged_path.is_empty():
		_assert(inspector.report_snapshot(damaged_path, "story")["status"]
			== "malformed_json", "R30 malformed JSON")
		_assert(not inspector.preview_migration(damaged_path, "story", story)["ok"],
			"R31 malformed source blocks preview")

	var invalid_version := _sample()
	invalid_version["version"] = true
	var bad_version_path := _fixture(
		"bool_version", "story", JSON.stringify(invalid_version)
	)
	if not bad_version_path.is_empty():
		var version_report := inspector.report_snapshot(bad_version_path, "story")
		_assert(version_report["status"] == "invalid_schema"
			and version_report["error_code"] == "INVALID_VERSION_TYPE",
			"R32 bool is not valid version")
		_assert(version_report["compatibility"]["classification"] == "invalid",
			"R33 incompatible vs invalid version differentiated")

	var invalid_target := story.duplicate(true)
	invalid_target["clock_seconds"] = true
	_assert(inspector.preview_migration(story_path, "story", invalid_target)["status"]
		== "invalid_target", "R34 target validation")
	_assert(inspector.preview_migration(story_path, "story", _sample("free"))["status"]
		== "invalid_target", "R35 target mode mismatch")

	var free_path := _fixture("valid_free", "free", JSON.stringify(_sample("free")))
	if not free_path.is_empty():
		var pair_dir := free_path.get_base_dir()
		var pair: Dictionary = inspector.report_pair(pair_dir)
		_assert(pair["free"]["valid"] and pair["story"]["status"] == "missing",
			"R36 pair is two independent results")
		_assert(not pair["atomic_pair"], "R37 no atomic-pair claim")

	_assert(inspector.report_snapshot(
		_root + "/../story.round_snapshot.json", "story"
	)["status"] == "invalid_request", "R38 traversal denied")
	_assert(inspector.report_snapshot(
		"res://story.round_snapshot.json", "story"
	)["status"] == "invalid_request", "R39 non-user scheme denied")

	var huge := _sample()
	huge["round_id"] = "x".repeat(Inspector.MAX_BYTES + 1)
	var huge_path := _fixture("oversized", "story", JSON.stringify(huge))
	if not huge_path.is_empty():
		var large_report := inspector.report_snapshot(huge_path, "story")
		_assert(large_report["status"] == "too_large",
			"R40 inspection bound")
		_assert(not inspector.preview_migration(huge_path, "story", story)["ok"],
			"R41 oversized input cannot preview")

	_assert(FileAccess.get_file_as_bytes(story_path) == before,
		"R42 fixture bytes unchanged")
	_assert(not FileAccess.file_exists(story_path + ".tmp"),
		"R43 no temporary write")


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			_assert(DirAccess.remove_absolute(path) == OK, "cleanup-file")
	for i in range(_dirs.size() - 1, -1, -1):
		if DirAccess.dir_exists_absolute(_dirs[i]):
			_assert(DirAccess.remove_absolute(_dirs[i]) == OK, "cleanup-dir")


func _init() -> void:
	_root = "user://w_module_state_002_%s_%s" % [
		str(OS.get_process_id()), str(Time.get_ticks_usec())
	]
	if DirAccess.dir_exists_absolute(_root):
		printerr("FAIL test directory already exists")
		quit(1)
		return
	if DirAccess.make_dir_absolute(_root) != OK:
		printerr("FAIL cannot create test directory")
		quit(1)
		return
	_dirs.append(_root)
	_run()
	_cleanup()
	print("GAME-WEB-MODULE-STATE-002 r1: ", _pass, " pass, ", _fail, " fail")
	if _fail > 0:
		quit(1)
	else:
		quit(0)

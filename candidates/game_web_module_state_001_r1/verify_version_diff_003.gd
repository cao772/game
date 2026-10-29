extends SceneTree
## GAME-WEB-CONTINUE-STATE-003 r1 -- FUTURE ACCEPTANCE SOURCE ONLY.
## NOT_RUN. Creates/removes only named synthetic user:// fixtures.
const Inspector = preload("res://snapshot_inspector_candidate.gd")
const SECRET := "synthetic-only-private-round-003"

var _root := ""
var _files: Array[String] = []
var _dirs: Array[String] = []
var _passed := 0
var _failed := 0


func _check(ok: bool, case_id: String) -> void:
	if ok:
		_passed += 1
		print("PASS ", case_id)
	else:
		_failed += 1
		printerr("FAIL ", case_id)


func _sample(mode: String = "story") -> Dictionary:
	return {
		"version": 1,
		"mode": mode,
		"round_id": SECRET,
		"phase": "ready",
		"door_open": false,
		"clock_seconds": 4.5
	}


func _fixture(group: String, data: String) -> String:
	var folder := _root.path_join(group)
	if DirAccess.dir_exists_absolute(folder):
		_check(false, "fixture collision")
		return ""
	if DirAccess.make_dir_absolute(folder) != OK:
		_check(false, "fixture create folder")
		return ""
	_dirs.append(folder)
	var path := folder.path_join("story.round_snapshot.json")
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_check(false, "fixture file collision")
		return ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "fixture file open")
		return ""
	_files.append(path)
	file.store_string(data)
	file.flush()
	var good := file.get_error() == OK
	file.close()
	_check(good, "fixture file write")
	if not good:
		return ""
	return path


func _safe(text_value: Variant) -> bool:
	var encoded := JSON.stringify(text_value)
	return not encoded.contains(SECRET) and not encoded.contains(_root) 		and not encoded.contains("text_sha256") 		and not encoded.contains("synthetic_secret_key")


func _cases() -> void:
	var inspector = Inspector.new()
	var base := _sample()
	var original_path := _fixture("v1", JSON.stringify(base))
	if original_path.is_empty():
		return
	var original_bytes := FileAccess.get_file_as_bytes(original_path)

	# v1 baseline is a numeric format check, not a migration guarantee.
	var delta := inspector.report_version_delta(original_path, "story")
	_check(delta["status"] == "valid" and
		delta["numeric_relation"] == "same_numeric_version",
		"V001 v1 format baseline")
	_check(delta["format_compatibility"] == "compatible_v1" and
		not delta["can_migrate"], "V002 format vs migration")
	_check(_safe(delta), "V003 version delta is redacted")
	_check(inspector.report_version_delta(original_path, "story", 1.0)["status"]
		== "valid", "V004 numeric 1.0 reference accepted")
	_check(inspector.report_version_delta(original_path, "story", true)["status"]
		== "invalid_reference", "V005 bool reference rejected")
	_check(inspector.report_version_delta(original_path, "story", 2)["error_code"]
		== "REFERENCE_NOT_APPROVED_V1", "V006 arbitrary reference rejected")
	_check(inspector.report_version_delta(original_path, "free")["status"]
		== "invalid_request", "V007 wrong expected mode rejected")

	var changed := _sample()
	changed["phase"] = "resolved"
	changed["door_open"] = true
	var changed_path := _fixture("changed", JSON.stringify(changed))
	if not changed_path.is_empty():
		var diff := inspector.compare_snapshot_versions(
			original_path, changed_path, "story"
		)
		_check(diff["status"] == "comparable_v1" and
			diff["payload_comparison"] == "known_v1_fields_only",
			"V008 valid v1 pair comparable")
		_check(diff["changed_field_count"] == 2 and
			diff["changed_fields"].size() == 2, "V009 exact structural changes")
		_check(diff["version_relation"] == "same_numeric_version",
			"V010 same-format pair")
		_check(not diff["atomic_pair"] and not diff["can_migrate"],
			"V011 not atomic or migration")
		_check(_safe(diff), "V012 pair summary is redacted")
		var expected := true
		for entry in diff["changed_fields"]:
			if (not Inspector.FIELDS.has(entry["field"])
				or entry.has("before") or entry.has("after")):
				expected = false
		_check(expected, "V013 only known field names + change types")

	var identical := inspector.compare_snapshot_versions(
		original_path, original_path, "story"
	)
	_check(identical["status"] == "comparable_v1" and
		identical["changed_field_count"] == 0,
		"V014 same file two reads; empty diff does not imply atomic read")

	var unknown := _sample()
	unknown["version"] = 0
	unknown["synthetic_secret_key"] = SECRET
	var old_path := _fixture("unknown_old", JSON.stringify(unknown))
	if not old_path.is_empty():
		var old_delta := inspector.report_version_delta(old_path, "story")
		_check(old_delta["status"] == "unsupported_version" and
			old_delta["numeric_relation"] == "lower_numeric_version",
			"V015 numeric old version observed")
		_check(old_delta["format_compatibility"] == "unsupported" and
			old_delta["migration_mapping"] == "not_provided",
			"V016 missing schema cannot be approved")
		_check(_safe(old_delta), "V017 unknown version metadata redacted")
		var cross_diff := inspector.compare_snapshot_versions(
			old_path, original_path, "story"
		)
		_check(cross_diff["status"] == "unmapped_versions" and
			cross_diff["version_relation"] == "lower_numeric_version",
			"V018 unmatched version detected")
		_check(cross_diff["changed_field_count"] == 0 and
			cross_diff["payload_comparison"] == "unavailable",
			"V019 never compare fields across unknown schema")
		_check(_safe(cross_diff), "V020 unmapped version report redacted")
		var old_preview := inspector.preview_migration_safe(
			old_path, "story", base
		)
		_check(old_preview["status"] == "mapping_required" and
			old_preview["changes"].is_empty() and not old_preview["can_apply"],
			"V021 source mapping required even with target")

	var higher := _sample()
	higher["version"] = 2
	var higher_path := _fixture("unknown_new", JSON.stringify(higher))
	if not higher_path.is_empty():
		var v2 := inspector.report_version_delta(higher_path, "story")
		_check(v2["status"] == "unsupported_version" and
			v2["numeric_relation"] == "higher_numeric_version",
			"V022 higher numeric version unsupported")

	var broken_path := _fixture("damaged", "{broken")
	if not broken_path.is_empty():
		var blocked_diff := inspector.compare_snapshot_versions(
			original_path, broken_path, "story"
		)
		_check(blocked_diff["status"] == "blocked" and
			blocked_diff["changed_fields"].is_empty(),
			"V023 broken pair never produces payload diff")
		var bad_preview := inspector.preview_migration_safe(
			broken_path, "story", base
		)
		_check(bad_preview["status"] == "blocked" and
			bad_preview["changes"].is_empty(),
			"V024 damaged source not rescued by target")

	var no_target := inspector.preview_migration_safe(original_path, "story")
	_check(no_target["status"] == "no_migration_needed" and
		not no_target["can_apply"], "V025 v1 needs no migration")
	_check(_safe(no_target), "V026 safe preview excludes checksum")
	var same := inspector.preview_migration_safe(
		original_path, "story", base.duplicate(true)
	)
	_check(same["status"] == "no_changes" and
		same["changed_field_count"] == 0,
		"V027 equal target no-op")
	var phase := base.duplicate(true)
	phase["phase"] = "observing"
	var phase_preview := inspector.preview_migration_safe(
		original_path, "story", phase
	)
	_check(phase_preview["status"] == "same_version_review_only" and
		phase_preview["changed_field_count"] == 1 and
		phase_preview["protected_field_changes"].is_empty(),
		"V028 nonprotected delta still review-only")
	_check(_safe(phase_preview), "V029 safe preview is redacted")
	_check(not phase_preview["mapping_approved"] and
		not phase_preview["writes"] and
		not phase_preview["can_apply"] and
		phase_preview["requires_review"],
		"V030 no migration authorization anywhere")

	var clock := base.duplicate(true)
	clock["clock_seconds"] = 20.0
	var clock_preview := inspector.preview_migration_safe(
		original_path, "story", clock
	)
	_check(clock_preview["status"] == "protected_field_review_blocked" and
		clock_preview["error_code"] == "PROTECTED_FIELDS_DIFFER",
		"V031 clock changes blocked")
	_check(clock_preview["protected_field_changes"].has("clock_seconds"),
		"V032 protected field named without value")
	var identity := base.duplicate(true)
	identity["round_id"] = "changed-" + SECRET
	var id_preview := inspector.preview_migration_safe(
		original_path, "story", identity
	)
	_check(id_preview["status"] == "protected_field_review_blocked" and
		id_preview["protected_field_changes"].has("round_id"),
		"V033 round identity guard")
	_check(_safe(id_preview), "V034 changed private identifier not leaked")

	var wrong_target := _sample("free")
	var mismatch := inspector.preview_migration_safe(
		original_path, "story", wrong_target
	)
	_check(mismatch["status"] == "invalid_target" and
		mismatch["error_code"] == "TARGET_MODE_MISMATCH",
		"V035 target cannot cross modes")
	var invalid_target := base.duplicate(true)
	invalid_target["clock_seconds"] = true
	_check(inspector.preview_migration_safe(
		original_path, "story", invalid_target
	)["status"] == "invalid_target", "V036 reject boolean clock")
	var unexpected_target := base.duplicate(true)
	unexpected_target["private_extra"] = SECRET
	_check(inspector.preview_migration_safe(
		original_path, "story", unexpected_target
	)["status"] == "invalid_target", "V037 reject extra target fields")

	var untrusted := base.duplicate(true)
	untrusted.erase("phase")
	var incomplete_path := _fixture("missing_field", JSON.stringify(untrusted))
	if not incomplete_path.is_empty():
		var incomplete_preview := inspector.preview_migration_safe(
			incomplete_path, "story", base
		)
		_check(incomplete_preview["status"] == "blocked" and
			incomplete_preview["changes"].is_empty(),
			"V038 invalid v1 schema blocks preview")
		_check(_safe(incomplete_preview), "V039 invalid preview redacted")

	var wrong_mode := _sample("free")
	var foreign_path := _fixture("foreign", JSON.stringify(wrong_mode))
	if not foreign_path.is_empty():
		_check(inspector.preview_migration_safe(
			foreign_path, "story", base
		)["status"] == "blocked", "V040 foreign mode blocked")

	_check(FileAccess.get_file_as_bytes(original_path) == original_bytes,
		"V041 source bytes unchanged across reports")
	_check(not FileAccess.file_exists(original_path + ".tmp"),
		"V042 no temporary save created")


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK,
				"cleanup owned file")
	for i in range(_dirs.size() - 1, -1, -1):
		var folder := _dirs[i]
		if DirAccess.dir_exists_absolute(folder):
			_check(DirAccess.remove_absolute(folder) == OK,
				"cleanup owned folder")


func _init() -> void:
	_root = "user://w_state_003_%s_%s" % [
		str(OS.get_process_id()), str(Time.get_ticks_usec())
	]
	if DirAccess.dir_exists_absolute(_root):
		printerr("FAIL fixture directory exists")
		quit(1)
		return
	if DirAccess.make_dir_absolute(_root) != OK:
		printerr("FAIL fixture root creation")
		quit(1)
		return
	_dirs.append(_root)
	_cases()
	_cleanup()
	print("STATE-003 future acceptance: ", _passed,
		" passed; ", _failed, " failed")
	if _failed > 0:
		quit(1)
	else:
		quit(0)

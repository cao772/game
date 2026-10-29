extends SceneTree
## GAME-WEB-FLOW-STATE-004 r1 UI smoke contract — FUTURE ONLY / NOT_RUN.
## This test creates disposable synthetic fixtures, not actual saves.
const Browser = preload("res://snapshot_browser_candidate.gd")
const SECRET := "synthetic-only-ui-check-004"

var _root := ""
var _files: Array[String] = []
var _dirs: Array[String] = []
var _passes := 0
var _fails := 0


func _assert(condition: bool, name_value: String) -> void:
	if condition:
		_passes += 1
		print("PASS ", name_value)
	else:
		_fails += 1
		printerr("FAIL ", name_value)


func _write_fixture(folder: String) -> String:
	var path := folder.path_join("story.round_snapshot.json")
	var fixture := {
		"version": 1,
		"mode": "story",
		"round_id": SECRET,
		"phase": "ready",
		"door_open": false,
		"clock_seconds": 6.5
	}
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_assert(false, "UI fixture file collision")
		return ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_assert(false, "UI fixture open")
		return ""
	_files.append(path)
	file.store_string(JSON.stringify(fixture))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	_assert(ok, "UI fixture write")
	if not ok:
		return ""
	return path


func _safe_output(value: String) -> bool:
	return not value.contains(SECRET) and not value.contains(_root) \
		and not value.contains("text_sha256")


func _run_ui() -> void:
	var browser = Browser.new()
	get_root().add_child(browser)

	var left: LineEdit = browser.get("_left_folder")
	var right: LineEdit = browser.get("_right_folder")
	var mode: OptionButton = browser.get("_mode")
	var phase: OptionButton = browser.get("_phase")
	var door: CheckBox = browser.get("_door_open")
	var tabs: TabContainer = browser.get("_tabs")
	var inspected: TextEdit = browser.get("_inspect_output")
	var compared: TextEdit = browser.get("_compare_output")
	var preview: TextEdit = browser.get("_preview_output")

	_assert(left != null and right != null and mode != null,
		"U01 path and mode controls exist")
	_assert(tabs != null and tabs.get_tab_count() == 3,
		"U02 all three report tabs exist")
	_assert(inspected.text.contains("尚未检查"),
		"U03 no scan on UI creation")
	_assert(left.text.is_empty() and right.text.is_empty(),
		"U04 no default path or silent user data access")
	_assert(mode.get_item_count() == 2,
		"U05 only story/free modes offered")
	_assert(phase.get_item_count() == 4 and not door.button_pressed,
		"U06 only known proposed fields available")

	var folder := _root.path_join("left")
	if DirAccess.make_dir_absolute(folder) != OK:
		_assert(false, "UI fixture directory creation")
		browser.free()
		return
	_dirs.append(folder)
	var source := _write_fixture(folder)
	if source.is_empty():
		browser.free()
		return
	var before := FileAccess.get_file_as_bytes(source)

	left.text = folder
	browser.call("_inspect_pressed")
	_assert(inspected.text.contains("compatible_v1"),
		"U07 inspection callback shows version compatibility")
	_assert(_safe_output(inspected.text), "U08 inspection output redacted")
	_assert(tabs.current_tab == 0, "U09 inspection tab selected")

	right.text = folder
	browser.call("_compare_pressed")
	_assert(compared.text.contains("comparable_v1"),
		"U10 comparison callback wired")
	_assert(_safe_output(compared.text), "U11 comparison output redacted")
	_assert(tabs.current_tab == 1, "U12 comparison tab selected")

	browser.call("_preview_none_pressed")
	_assert(preview.text.contains("no_migration_needed"),
		"U13 default preview never migrates")
	_assert(_safe_output(preview.text), "U14 default preview redacted")
	_assert(tabs.current_tab == 2, "U15 preview tab selected")

	phase.select(1)
	browser.call("_on_phase_changed", 1)
	browser.call("_preview_candidate_pressed")
	_assert(preview.text.contains("same_version_review_only"),
		"U16 hypothetical phase preview displayed")
	_assert(preview.text.contains("不能应用"),
		"U17 preview explicitly not applicable")
	_assert(_safe_output(preview.text), "U18 proposal excludes private values")

	mode.select(1)
	browser.call("_on_mode_changed", 1)
	_assert(inspected.text.contains("尚未检查"),
		"U19 mode switch clears stale report")
	browser.call("_inspect_pressed")
	_assert(inspected.text.contains("missing"),
		"U20 free cannot silently fall back to story")

	_assert(FileAccess.get_file_as_bytes(source) == before,
		"U21 UI operations preserved byte-identical source")
	_assert(not FileAccess.file_exists(source + ".tmp"),
		"U22 UI never generated a save temp file")
	_assert(browser.get("_status_label") != null,
		"U23 explicit safe status feedback exists")
	_assert(not inspected.text.contains("round_id"),
		"U24 report avoids private round identifier field names")
	_assert(not preview.text.contains('"before"')
		and not preview.text.contains('"after"'),
		"U25 preview does not show before/after values")
	_assert(not preview.text.contains("user://"),
		"U26 report does not print the local directory")

	browser.free()


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			_assert(DirAccess.remove_absolute(path) == OK,
				"cleanup isolated UI fixture file")
	for i in range(_dirs.size() - 1, -1, -1):
		if DirAccess.dir_exists_absolute(_dirs[i]):
			_assert(DirAccess.remove_absolute(_dirs[i]) == OK,
				"cleanup isolated UI fixture dir")


func _init() -> void:
	_root = "user://w_flow_state_ui_004_%s_%s" % [
		str(OS.get_process_id()), str(Time.get_ticks_usec())
	]
	if DirAccess.dir_exists_absolute(_root):
		printerr("FAIL test root collision")
		quit(1)
		return
	if DirAccess.make_dir_absolute(_root) != OK:
		printerr("FAIL test root creation")
		quit(1)
		return
	_dirs.append(_root)
	_run_ui()
	_cleanup()
	print("W-FLOW-STATE-004 UI future checks: ", _passes,
		" passed; ", _fails, " failed")
	quit(1 if _fails > 0 else 0)

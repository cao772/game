extends SceneTree
## GAME-WEB-PLAY-STATE-005 r1 — FUTURE PRESENTER TEST ONLY, NOT_RUN.
## No file I/O, no subprocess, no project saves. Pure synthetic dictionaries.
const Presenter = preload("res://snapshot_report_presenter_candidate.gd")
const PRIVATE_MARKER := "PRIVATE_SYNTHETIC_VALUE_005"

var _passed := 0
var _failed := 0


func _check(ok: bool, name_value: String) -> void:
	if ok:
		_passed += 1
		print("PASS ", name_value)
	else:
		_failed += 1
		printerr("FAIL ", name_value)


func _safe(message: String) -> bool:
	return not message.contains(PRIVATE_MARKER) 		and not message.contains("user://secret/path") 		and not message.contains("text_sha256")


func _run() -> void:
	var view = Presenter.new()

	var safe_report := {
		"status": "valid",
		"inspection": {
			"status": "valid",
			"expected_mode": "story",
			"version_label": "1",
			"error_code": "",
			"compatibility": {"classification": "compatible_v1"}
		},
		"version_delta": {
			"status": "valid",
			"numeric_relation": "same_numeric_version"
		},
		"data": {"round_id": PRIVATE_MARKER},
		"text_sha256": PRIVATE_MARKER,
		"path": "user://secret/path"
	}
	var inspection := view.inspection(safe_report)
	_check(inspection.contains("compatible_v1"),
		"P01 compatible format visible")
	_check(inspection.contains("same_numeric_version") == false,
		"P02 numeric order described, not raw untrusted data")
	_check(inspection.contains("等于 1"),
		"P03 numeric version described correctly")
	_check(_safe(inspection),
		"P04 inspection never prints private dictionary values")

	var altered := safe_report.duplicate(true)
	altered["inspection"]["status"] = "unsupported_version"
	altered["inspection"]["compatibility"]["classification"] = "unsupported"
	altered["version_delta"]["numeric_relation"] = "higher_numeric_version"
	var unsupported := view.inspection(altered)
	_check(unsupported.contains("unsupported_version")
		and unsupported.contains("higher") == false,
		"P05 version unsupported remains distinct from version order")
	_check(_safe(unsupported), "P06 unsupported private data hidden")

	var compare := {
		"status": "comparable_v1",
		"left": {"status": "valid"},
		"right": {"status": "valid"},
		"version_relation": "same_numeric_version",
		"changed_fields": [
			{"field": "phase", "kind": "change",
			 "before": PRIVATE_MARKER, "after": PRIVATE_MARKER},
			{"field": "made_up_secret_field", "kind": "change",
			 "before": PRIVATE_MARKER, "after": PRIVATE_MARKER},
			{"field": "door_open", "kind": "change"}
		],
		"path": "user://secret/path"
	}
	var comparison := view.comparison(compare)
	_check(comparison.contains("comparable_v1"),
		"P07 comparison status visible")
	_check(comparison.contains("phase : change"),
		"P08 allowed phase name and kind shown")
	_check(comparison.contains("door_open : change"),
		"P09 allowed door flag name shown")
	_check(not comparison.contains("made_up_secret_field"),
		"P10 unknown field name hidden")
	_check(_safe(comparison),
		"P11 before/after values, path and hash hidden")

	var preview := {
		"status": "mapping_required",
		"error_code": "VERSION_MAPPING_NOT_PROVIDED",
		"changes": [
			{"field": "phase", "kind": "change",
			"before": PRIVATE_MARKER}
		],
		"round_id": PRIVATE_MARKER
	}
	var preview_text := view.preview(preview)
	_check(preview_text.contains("mapping_required"),
		"P12 migration mapping missing is explicit")
	_check(preview_text.contains("不能应用"),
		"P13 preview cannot apply")
	_check(_safe(preview_text),
		"P14 preview source values never rendered")

	var changed := preview.duplicate(true)
	changed["status"] = "source_unstable"
	changed["error_code"] = "SOURCE_CHANGED_OR_UNREADABLE"
	var unstable := view.preview(changed)
	_check(unstable.contains("source_unstable"),
		"P15 stale source warning shown")
	_check(_safe(unstable), "P16 stale result remains redacted")

	var blocked := {
		"status": "invalid_request",
		"error_code": PRIVATE_MARKER,
		"text_sha256": PRIVATE_MARKER
	}
	_check(not view.inspection(blocked).contains(PRIVATE_MARKER),
		"P17 unexpected error is not echoed")
	_check(not view.preview({
		"status": PRIVATE_MARKER, "error_code": PRIVATE_MARKER
	}).contains(PRIVATE_MARKER),
		"P18 unknown status rejected, not interpolated")
	_check(not view.comparison({
		"status": PRIVATE_MARKER,
		"changed_fields": [{"field": PRIVATE_MARKER, "kind": "change"}]
	}).contains(PRIVATE_MARKER),
		"P19 malicious field/status ignored")
	_check(view.inspection({"status": "valid"}).contains("检查未完成"),
		"P20 missing nested report fails closed")
	_check(view.comparison({"status": "blocked"}).contains("blocked"),
		"P21 blocked comparison renders without raw data")
	_check(view.preview({"status": "blocked"}).contains("不能应用"),
		"P22 blocked preview never claims action")


func _init() -> void:
	_run()
	print("W-PLAY-STATE-005 presenter (future): ",
		_passed, " pass, ", _failed, " fail")
	quit(1 if _failed > 0 else 0)

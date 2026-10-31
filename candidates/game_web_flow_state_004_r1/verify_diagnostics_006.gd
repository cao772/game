extends SceneTree
## GAME-WEB-STATE-006 r1 — FUTURE TEST SOURCE ONLY / NOT_RUN.
## Pure synthetic in-memory reports, no real saves, no disk I/O.
const Diagnostics = preload("res://snapshot_diagnostics_candidate.gd")
const Presenter = preload("res://snapshot_report_presenter_candidate.gd")
const Model = preload("res://snapshot_browser_model_candidate.gd")
const SECRET := "PRIVATE_SYNTHETIC_006_DONT_ECHO"

var _passed := 0
var _failed := 0


func _check(condition: bool, case_id: String) -> void:
	if condition:
		_passed += 1
		print("PASS ", case_id)
	else:
		_failed += 1
		printerr("FAIL ", case_id)


func _does_not_leak(text_value: String) -> bool:
	return not text_value.contains(SECRET) \
		and not text_value.contains("user://secret-snapshot") \
		and not text_value.contains("text_sha256")


func _run_cases() -> void:
	var policy = Diagnostics.new()
	var presenter = Presenter.new()
	var model = Model.new()

	var valid := policy.build("inspection", {
		"inspection": {"status": "valid"}, "consistency": "best_effort_observed_same"
	})
	_check(valid["level"] == "informational", "D01 valid v1 risk")
	_check(valid["notice_codes"].has("V1_FORMAT_ONLY"), "D02 format only caveat")
	_check(valid["notice_codes"].has("NO_ATOMICITY"), "D03 non-atomic warning")
	_check(not valid["can_apply"] and not valid["writes"], "D04 no mutation")
	_check(not valid["contains_snapshot_payload"], "D05 no source payload")

	var missing := policy.build("inspection", {
		"inspection": {"status": "missing"}, "consistency": "no_payload_to_verify"
	})
	_check(missing["level"] == "review_required", "D06 missing source not valid")
	_check(missing["notice_codes"].has("FILE_UNAVAILABLE"), "D07 missing advice")
	_check(missing["notice_codes"].has("NO_PAYLOAD_VERIFICATION"),
		"D08 missing has no fingerprint proof")

	var broken := policy.build("inspection", {
		"inspection": {"status": "malformed_json"}
	})
	_check(broken["level"] == "blocked", "D09 bad JSON blocks")
	_check(broken["notice_codes"].has("CORRUPT_OR_INVALID"),
		"D10 damaged source advice")

	var wrong_mode := policy.build("inspection", {
		"inspection": {"status": "mode_mismatch"}
	})
	_check(wrong_mode["level"] == "blocked", "D11 wrong mode blocks")
	_check(wrong_mode["notice_codes"].has("MODE_MISMATCH"),
		"D12 wrong mode identified")

	var unknown_version := policy.build("inspection", {
		"inspection": {"status": "unsupported_version"}
	})
	_check(unknown_version["level"] == "review_required",
		"D13 unsupported version cannot be accepted")
	_check(unknown_version["notice_codes"].has("VERSION_MAPPING_ABSENT"),
		"D14 unknown schema mapping missing")

	var compare_empty := policy.build("comparison", {
		"status": "comparable_v1", "changed_fields": []
	}, true)
	_check(compare_empty["level"] == "informational",
		"D15 empty known-field diff is informational only")
	_check(compare_empty["notice_codes"].has("SAME_SOURCE_SELECTED"),
		"D16 same-folder comparison exposed")
	_check(compare_empty["notice_codes"].has("NO_KNOWN_DIFF"),
		"D17 no known changes not asserted identity")
	_check(compare_empty["same_source_reference"], "D18 same source flag")

	var compare_changed := policy.build("comparison", {
		"status": "comparable_v1",
		"changed_field_count": 99,
		"changed_fields": [
			{"field": "phase", "kind": "change",
				"before": SECRET, "after": SECRET},
			{"field": "phase", "kind": "change"},
			{"field": "secret_named_field", "kind": "add",
				"before": SECRET},
			{"field": "clock_seconds", "kind": "change",
				"after": SECRET}
		]
	})
	_check(compare_changed["level"] == "review_required",
		"D19 known field difference requires review")
	_check(compare_changed["notice_codes"].has("PROTECTED_DIFFERENCE"),
		"D20 clock difference is protected")
	_check(compare_changed["known_changed_fields"].size() == 2,
		"D21 unknown names and duplicate entries excluded")
	_check(not JSON.stringify(compare_changed).contains(SECRET),
		"D22 diagnostic output does not echo before/after")
	_check(not JSON.stringify(compare_changed).contains("secret_named_field"),
		"D23 unknown field name redacted")
	_check(not compare_changed["can_apply"] and not compare_changed["writes"],
		"D24 a diff is never actionable")

	var no_mapping := policy.build("comparison", {
		"status": "unmapped_versions",
		"changed_fields": [{"field": "phase", "kind": "change"}]
	})
	_check(no_mapping["level"] == "blocked", "D25 unsupported comparison blocked")
	_check(no_mapping["notice_codes"].has("VERSION_MAPPING_ABSENT"),
		"D26 known migration mapping absent")

	var stale := policy.build("comparison", {"status": "source_unstable"})
	_check(stale["level"] == "blocked", "D27 stale comparison blocked")
	_check(stale["notice_codes"].has("SOURCE_UNSTABLE"),
		"D28 stale read notice")

	var preview := policy.build("preview", {
		"status": "same_version_review_only",
		"changes": [{"field": "phase", "kind": "change"}]
	})
	_check(preview["level"] == "review_required",
		"D29 hypothetical phase only review")
	_check(preview["notice_codes"].has("PREVIEW_NEVER_APPLIES"),
		"D30 preview always non-executable")
	_check(preview["notice_codes"].has("AUTHOR_REVIEW_REQUIRED"),
		"D31 author review remains separate")

	var protected := policy.build("preview", {
		"status": "protected_field_review_blocked",
		"changes": [{"field": "round_id", "kind": "change"}]
	})
	_check(protected["level"] == "blocked", "D32 protected preview blocked")
	_check(protected["notice_codes"].has("PROTECTED_DIFFERENCE"),
		"D33 protected preview warning")

	var blocked := policy.build("preview", {"status": "mapping_required"})
	_check(blocked["level"] == "blocked", "D34 missing mapping blocks")
	_check(blocked["notice_codes"].has("VERSION_MAPPING_ABSENT"),
		"D35 missing mapping message")

	var unknown := policy.build("anything", {
		"status": SECRET, "changed_fields": [
			{"field": SECRET, "kind": "change", "before": SECRET}
		]
	})
	_check(unknown["level"] == "blocked", "D36 unknown kind fail closed")
	_check(unknown["kind"] == "unknown", "D37 unknown kind redacted")
	_check(not JSON.stringify(unknown).contains(SECRET),
		"D38 no arbitrary diagnostic fields echo")

	var compare_text := presenter.comparison({
		"status": "comparable_v1",
		"version_relation": "same_numeric_version",
		"changed_fields": [
			{"field": "phase", "kind": "change", "before": SECRET},
			{"field": SECRET, "kind": "change", "after": SECRET}
		],
		"diagnostics": compare_changed,
		"path": "user://secret-snapshot"
	})
	_check(compare_text.contains("需人工复核"),
		"D39 warning severity readable")
	_check(compare_text.contains("phase : change"),
		"D40 known field difference visible")
	_check(compare_text.contains("受保护"),
		"D41 protected field warning visible")
	_check(_does_not_leak(compare_text), "D42 comparison text privacy")

	var blocked_text := presenter.comparison({
		"status": "unmapped_versions",
		"changed_fields": [{"field": "phase", "kind": "change"}],
		"diagnostics": no_mapping
	})
	_check(not blocked_text.contains("phase : change"),
		"D43 unmapped version never displays field differences")
	_check(blocked_text.contains("缺少"),
		"D44 mapping absent notice visible")

	var blocked_preview := presenter.preview({
		"status": "mapping_required",
		"changes": [{"field": "phase", "kind": "change",
			"after": SECRET}],
		"diagnostics": blocked
	})
	_check(not blocked_preview.contains("phase : change"),
		"D45 blocked preview never displays candidate differences")
	_check(_does_not_leak(blocked_preview), "D46 blocked preview privacy")
	_check(blocked_preview.contains("不能应用"),
		"D47 no apply action in preview display")

	var bad_code := presenter.preview({
		"status": SECRET, "error_code": SECRET,
		"diagnostics": {"level": SECRET,
			"notice_codes": [SECRET, "READ_ONLY"]}
	})
	_check(_does_not_leak(bad_code), "D48 malicious status/error/notice filtered")

	var invalid_model := model.inspect_folder("res://secret", "story")
	_check(invalid_model["status"] == "invalid_request",
		"D49 invalid path blocked before file read")
	_check(invalid_model["diagnostics"]["level"] == "blocked",
		"D50 invalid path has safe anomaly")
	_check(_does_not_leak(JSON.stringify(invalid_model)),
		"D51 no real path in model's rejection report")


func _init() -> void:
	_run_cases()
	print("GAME-WEB-STATE-006 future synthetic checks: ",
		_passed, " passed; ", _failed, " failed")
	quit(1 if _failed > 0 else 0)

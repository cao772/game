extends RefCounted
## REGION-022 | synthetic-only, local boundary samples; NOT a test runner.
const RecoveryScript = preload("res://catalog_recovery.gd")

func example(kind: String) -> Dictionary:
    var synthetic: Dictionary = RecoveryScript.new().synthetic_fixture()
    match kind:
        "BAD_VERSION":
            synthetic["schema_version"] = "unsupported-synthetic-v2"
        "DUPLICATE_ID":
            synthetic["scenarios"][1]["id"] = "A"
        "MISSING_T":
            synthetic["scenarios"][0]["grid"][1] = "#S..#...#"
        "VALID_DISCONNECTED_C":
            # C is structurally valid even if T is not reachable.
            pass
        "BAD_CLAIM":
            synthetic["scenarios"][1]["claimed"]["reachable"] = "false"
        _:
            return {"kind": "INVALID_CASE"}
    return {"kind": "VARIANT", "value": synthetic}

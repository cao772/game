extends RefCounted
## GAME-WEB-REGION-020 r1. In-memory synthetic boundary candidates, not tests.
const RecoveryScript = preload("res://catalog_recovery.gd")
const CASES = [
    "VALID_ABC", "ROOT_NULL", "VERSION_MISMATCH", "SCENE_COUNT_TWO",
    "DUPLICATE_A", "CLAIM_AS_TEXT", "MISSING_T", "RAGGED_ROW",
    "OPEN_EDGE", "UNKNOWN_GLYPH", "NONSTRING_ROW", "TOO_FEW_ROWS",
    "EXTRA_FIELD_WARNING", "INVALID_JSON_SYNTAX", "VALID_DISCONNECTED_C"
]

func catalog_case(name: String) -> Dictionary:
    var source: Dictionary = RecoveryScript.new().synthetic_fixture()
    var list: Array = source["scenarios"]
    match name:
        "ROOT_NULL":
            return {"kind": "variant", "value": null}
        "VERSION_MISMATCH":
            source["schema_version"] = "synthetic-unsupported-v2"
        "SCENE_COUNT_TWO":
            list.pop_back()
        "DUPLICATE_A":
            list[1]["id"] = "A"
        "CLAIM_AS_TEXT":
            list[0]["claimed"]["reachable"] = "true"
        "MISSING_T":
            list[0]["grid"][1] = "#S..#...#"
        "RAGGED_ROW":
            list[0]["grid"][3] = "#......#"
        "OPEN_EDGE":
            list[0]["grid"][0] = ".########"
        "UNKNOWN_GLYPH":
            list[0]["grid"][2] = "#..X#...#"
        "NONSTRING_ROW":
            list[0]["grid"][2] = null
        "TOO_FEW_ROWS":
            list[0]["grid"] = ["#####", "#S.T#", "#####"]
        "EXTRA_FIELD_WARNING":
            list[0]["extra_synthetic_note"] = "placeholder"
        "INVALID_JSON_SYNTAX":
            return {"kind": "text", "value": "{broken synthetic JSON"}
        "VALID_DISCONNECTED_C":
            # The third scenario is structurally valid though T is unreachable.
            pass
        "VALID_ABC":
            pass
        _:
            return {"kind": "invalid_case", "value": name}
    return {"kind": "variant", "value": source}

extends RefCounted
## GAME-WEB-CONTINUE-REGION-003 r1 — public, static fixture loader.
## No network, scenes, personal data, gameplay discovery or save writes.
const FIXTURE_PATH := "res://placeholder_targets.example.json"

static func load_catalog() -> Dictionary:
    if not FileAccess.file_exists(FIXTURE_PATH):
        return {"ok": false, "error": "Placeholder fixture missing"}
    var source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
    var parsed: Variant = JSON.parse_string(source)
    if not parsed is Dictionary:
        return {"ok": false, "error": "Placeholder fixture is not an object"}
    if parsed.get("schema_version", "") != "placeholder-catalog-v1":
        return {"ok": false, "error": "Unknown placeholder fixture version"}
    var sets: Variant = parsed.get("sets", null)
    if not sets is Dictionary:
        return {"ok": false, "error": "Missing placeholder sets"}
    for required_name in ["initial", "reordered", "reduced", "alternate"]:
        if not sets.has(required_name) or not sets[required_name] is Array:
            return {"ok": false, "error": "Missing list: " + required_name}
    # Actual target validation remains in show_for_targets/synchronize_targets.
    return {"ok": true, "sets": sets.duplicate(true)}

static func get_set(catalog: Dictionary, key: String) -> Array:
    if not catalog.get("ok", false):
        return []
    var sets: Dictionary = catalog.get("sets", {})
    if not sets.has(key) or not sets[key] is Array:
        return []
    return (sets[key] as Array).duplicate(true)

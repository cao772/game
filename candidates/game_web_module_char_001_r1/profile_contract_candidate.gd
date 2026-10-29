extends RefCounted
## GAME-WEB-MODULE-CHAR-001 r1 / unapproved presentation-only data proposal.
## No character facts, IO, global state, save, or shared-interface registration.

const TOP_FIELDS := [
    "schema_version", "profile_id", "display_name", "subtitle",
    "summary", "status_label", "tags", "sections"
]
const SECTION_FIELDS := ["section_id", "heading", "items"]
const ITEM_FIELDS := ["label", "value"]
const MAX_TAGS := 8
const MAX_SECTIONS := 8
const MAX_ITEMS_PER_SECTION := 12


static func _failure(reason: String) -> Dictionary:
    return {"ok": false, "error": reason, "data": {}}


static func _field_shape(value: Dictionary, expected: Array, context: String) -> String:
    if value.size() != expected.size():
        return context + ": missing or extra fields"
    for field in expected:
        if not value.has(field):
            return context + ": missing " + str(field)
    return ""


static func _text_error(value: Variant, field: String, maximum: int, allow_empty: bool = false) -> String:
    if typeof(value) != TYPE_STRING:
        return field + " must be a string"
    var text_value: String = value
    if text_value.length() > maximum:
        return field + " exceeds length limit"
    if not allow_empty and text_value.strip_edges().is_empty():
        return field + " must not be blank"
    if text_value.contains("\u0000"):
        return field + " contains a null character"
    return ""


static func _id_error(value: Variant, field: String) -> String:
    var issue := _text_error(value, field, 64)
    if not issue.is_empty():
        return issue
    var expression := RegEx.new()
    if expression.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$") != OK:
        return "Internal identifier rule unavailable"
    if expression.search(value) == null:
        return field + " must be an ASCII identifier"
    return ""


static func validate(source: Variant) -> Dictionary:
    if typeof(source) != TYPE_DICTIONARY:
        return _failure("profile must be an object")
    var profile: Dictionary = source
    var issue := _field_shape(profile, TOP_FIELDS, "profile")
    if not issue.is_empty():
        return _failure(issue)

    var version: Variant = profile["schema_version"]
    if typeof(version) != TYPE_INT and typeof(version) != TYPE_FLOAT:
        return _failure("schema_version must be numeric 1")
    if not is_finite(float(version)) or float(version) != 1.0:
        return _failure("unsupported schema_version")

    issue = _id_error(profile["profile_id"], "profile_id")
    if not issue.is_empty():
        return _failure(issue)

    for descriptor in [
        ["display_name", 80, false],
        ["subtitle", 120, true],
        ["summary", 1200, true],
        ["status_label", 40, true]
    ]:
        issue = _text_error(
            profile[descriptor[0]], descriptor[0],
            descriptor[1], descriptor[2]
        )
        if not issue.is_empty():
            return _failure(issue)

    if typeof(profile["tags"]) != TYPE_ARRAY:
        return _failure("tags must be an array")
    var tags: Array = profile["tags"]
    if tags.size() > MAX_TAGS:
        return _failure("too many tags")
    var seen_tags := {}
    for i in range(tags.size()):
        issue = _text_error(tags[i], "tags[%d]" % i, 24)
        if not issue.is_empty():
            return _failure(issue)
        if seen_tags.has(tags[i]):
            return _failure("duplicate tag")
        seen_tags[tags[i]] = true

    if typeof(profile["sections"]) != TYPE_ARRAY:
        return _failure("sections must be an array")
    var sections: Array = profile["sections"]
    if sections.size() > MAX_SECTIONS:
        return _failure("too many sections")
    var seen_sections := {}
    for section_index in range(sections.size()):
        var section_value: Variant = sections[section_index]
        if typeof(section_value) != TYPE_DICTIONARY:
            return _failure("section must be an object")
        var section: Dictionary = section_value
        issue = _field_shape(section, SECTION_FIELDS, "section")
        if not issue.is_empty():
            return _failure(issue)
        issue = _id_error(section["section_id"], "section_id")
        if not issue.is_empty():
            return _failure(issue)
        if seen_sections.has(section["section_id"]):
            return _failure("duplicate section_id")
        seen_sections[section["section_id"]] = true
        issue = _text_error(section["heading"], "heading", 80)
        if not issue.is_empty():
            return _failure(issue)
        if typeof(section["items"]) != TYPE_ARRAY:
            return _failure("items must be an array")
        var items: Array = section["items"]
        if items.size() > MAX_ITEMS_PER_SECTION:
            return _failure("too many items in section")
        for item_index in range(items.size()):
            var item_value: Variant = items[item_index]
            if typeof(item_value) != TYPE_DICTIONARY:
                return _failure("item must be an object")
            var item: Dictionary = item_value
            issue = _field_shape(item, ITEM_FIELDS, "item")
            if not issue.is_empty():
                return _failure(issue)
            issue = _text_error(item["label"], "item label", 50)
            if not issue.is_empty():
                return _failure(issue)
            issue = _text_error(item["value"], "item value", 600)
            if not issue.is_empty():
                return _failure(issue)

    # Validate before copying. Callers cannot mutate the stored source via aliases.
    return {"ok": true, "error": "", "data": profile.duplicate(true)}

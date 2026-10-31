extends RefCounted
## Pure presentation text helpers. The original injected data remains unchanged.
## Avoid ellipsis/hidden data; preserve paragraphs and literal markup characters.

const UNBROKEN_WRAP_THRESHOLD: int = 40


static func visible_text(value: String) -> String:
    return value.replace("\r\n", "\n").replace("\r", "\n").replace("\t", "    ")


static func needs_character_wrap(value: String) -> bool:
    var run_length := 0
    for i in range(value.length()):
        var character := value.substr(i, 1)
        if character == " " or character == "\n" or character == "\t":
            run_length = 0
        else:
            run_length += 1
            if run_length >= UNBROKEN_WRAP_THRESHOLD:
                return true
    return false


static func wrap_mode(value: String) -> int:
    if needs_character_wrap(value):
        return TextServer.AUTOWRAP_ARBITRARY
    return TextServer.AUTOWRAP_WORD_SMART

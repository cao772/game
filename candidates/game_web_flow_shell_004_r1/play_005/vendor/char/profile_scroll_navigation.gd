extends ScrollContainer
## Focus-local keyboard reading, not a global shortcut or game input handler.
## A key at a scroll boundary is not consumed, avoiding keyboard traps.

@export_range(24, 240, 8) var line_step_px: int = 64


static func scroll_decision(
    key: InputEventKey,
    focused: bool,
    start_value: int,
    maximum: int,
    visible_height: int,
    line_step: int = 64
) -> Dictionary:
    var reject := {"handled": false, "position": start_value}
    if key == null or not focused or not key.pressed or key.echo:
        return reject
    if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
        return reject
    if maximum <= 0:
        return reject

    var page := maxi(64, int(float(visible_height) * 0.8))
    var target := start_value
    match key.keycode:
        KEY_UP:
            target -= line_step
        KEY_DOWN:
            target += line_step
        KEY_PAGEUP:
            target -= page
        KEY_PAGEDOWN:
            target += page
        KEY_HOME:
            target = 0
        KEY_END:
            target = maximum
        _:
            return reject

    target = clampi(target, 0, maximum)
    return {"handled": target != start_value, "position": target}


func _gui_input(event: InputEvent) -> void:
    if not event is InputEventKey or not has_focus():
        return
    var key := event as InputEventKey
    var bar := get_v_scroll_bar()
    var maximum := maxi(0, int(floor(bar.max_value - bar.page)))
    var decided := scroll_decision(
        key, has_focus(), scroll_vertical, maximum,
        int(size.y), line_step_px
    )
    if not decided["handled"]:
        return
    scroll_vertical = decided["position"]
    accept_event()

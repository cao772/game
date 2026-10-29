extends ScrollContainer
## Local keyboard reading only when this scroll area itself owns focus.
## No shortcuts, InputMap mutations or gameplay input dispatch.

@export_range(24, 240, 8) var line_step_px: int = 64


func _gui_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
        return
    if not has_focus():
        return
    var bar := get_v_scroll_bar()
    var maximum := maxi(0, int(ceil(bar.max_value - bar.page)))
    if maximum <= 0:
        return
    var page := maxi(64, int(size.y * 0.8))
    var next_value := scroll_vertical
    match key.keycode:
        KEY_UP:
            next_value -= line_step_px
        KEY_DOWN:
            next_value += line_step_px
        KEY_PAGEUP:
            next_value -= page
        KEY_PAGEDOWN:
            next_value += page
        KEY_HOME:
            next_value = 0
        KEY_END:
            next_value = maximum
        _:
            return
    scroll_vertical = clampi(next_value, 0, maximum)
    accept_event()

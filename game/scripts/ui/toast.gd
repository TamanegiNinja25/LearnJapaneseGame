extends PanelContainer
class_name Toast
## A short celebratory notice in the top-right corner (rank-ups, quests, stage clears).
## Scale 0.95→1 and fade in over UITheme.ANIM_CELEBRATE, hold, fade out. Never blocks input.

const HOLD := 2.2


static func show_on(host: Control, markup: String, english: String = "", accent: Color = Color(0, 0, 0, 0)) -> void:
	var t := Toast.new()
	var ink := UITheme.PRIMARY if accent.a == 0.0 else accent
	t.add_theme_stylebox_override("panel", UITheme._card(UITheme.SURFACE, ink))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UITheme.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(v)
	var line := UITheme.ja(markup, UITheme.SIZE_LABEL, ink)
	line.autowrap = false
	v.add_child(line)
	if english != "" and Progress.show_english():
		v.add_child(UITheme.en(english, UITheme.SIZE_LABEL))
	host.add_child(t)
	t.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	t.position = Vector2(host.size.x - t.get_combined_minimum_size().x - 24, 24 + 84 * _stack(host))
	t.pivot_offset = t.get_combined_minimum_size() * 0.5
	t.modulate.a = 0.0
	t.scale = Vector2(0.95, 0.95)
	var tw := t.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 1.0, UITheme.ANIM_CELEBRATE)
	tw.parallel().tween_property(t, "scale", Vector2.ONE, UITheme.ANIM_CELEBRATE)
	tw.tween_interval(HOLD)
	tw.tween_property(t, "modulate:a", 0.0, UITheme.ANIM_IN)
	tw.tween_callback(t.queue_free)


static func _stack(host: Control) -> int:
	var n := 0
	for c in host.get_children():
		if c is Toast:
			n += 1
	return n - 1

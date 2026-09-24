class_name TouchActionButton
extends Control

signal pressed
signal released
signal toggled(is_on: bool)

@export var label_text: String = "BTN"
@export var is_toggle: bool = false
@export var button_radius: float = 34.0
@export var primary_color: Color = Color(0.2, 0.5, 0.9, 0.6)
@export var active_color: Color = Color(1.0, 0.4, 0.2, 0.8)

var is_down: bool = false
var is_toggled_on: bool = false
var touch_index: int = -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed() and touch_index == -1:
			touch_index = event.index
			is_down = true
			if is_toggle:
				is_toggled_on = !is_toggled_on
				emit_signal("toggled", is_toggled_on)
			emit_signal("pressed")
			queue_redraw()
		elif not event.is_pressed() and event.index == touch_index:
			touch_index = -1
			is_down = false
			emit_signal("released")
			queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var color := active_color if (is_down or is_toggled_on) else primary_color
	
	# Background disc
	draw_circle(center, button_radius, color)
	draw_arc(center, button_radius, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.0)
	
	# Text label
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

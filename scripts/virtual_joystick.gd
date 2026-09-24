class_name VirtualJoystick
extends Control

## Multi-touch capable virtual analog joystick for Android & mobile.

signal joystick_vector(vector: Vector2)

@export var max_radius: float = 65.0
@export var deadzone: float = 0.1
@export var return_speed: float = 20.0

var touch_index: int = -1
var is_active: bool = false
var current_vector: Vector2 = Vector2.ZERO
var knob_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	knob_position = size * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed() and touch_index == -1:
			touch_index = event.index
			is_active = true
			_update_knob_from_position(event.position)
		elif not event.is_pressed() and event.index == touch_index:
			_reset_joystick()
			
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_knob_from_position(event.position)

func _update_knob_from_position(pos: Vector2) -> void:
	var center := size * 0.5
	var delta := pos - center
	var dist := delta.length()
	
	if dist > max_radius:
		delta = delta.normalized() * max_radius
	
	knob_position = center + delta
	
	var norm_dist := delta.length() / max_radius
	if norm_dist < deadzone:
		current_vector = Vector2.ZERO
	else:
		current_vector = (delta / max_radius).normalized() * ((norm_dist - deadzone) / (1.0 - deadzone))
	
	emit_signal("joystick_vector", current_vector)
	queue_redraw()

func _reset_joystick() -> void:
	touch_index = -1
	is_active = false
	current_vector = Vector2.ZERO
	emit_signal("joystick_vector", Vector2.ZERO)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_active:
		var center := size * 0.5
		if knob_position.distance_to(center) > 0.5:
			knob_position = knob_position.lerp(center, return_speed * delta)
			queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	
	# Base circle (dark translucent glass)
	draw_circle(center, max_radius, Color(0.1, 0.12, 0.15, 0.45))
	draw_arc(center, max_radius, 0, TAU, 48, Color(0.5, 0.6, 0.7, 0.5), 2.0)
	
	# Inner deadzone indicator
	draw_arc(center, max_radius * deadzone, 0, TAU, 24, Color(0.3, 0.35, 0.4, 0.3), 1.0)
	
	# Knob (accent color when active)
	var knob_color := Color(0.2, 0.7, 1.0, 0.75) if is_active else Color(0.8, 0.85, 0.9, 0.5)
	draw_circle(knob_position, 26.0, knob_color)
	draw_arc(knob_position, 26.0, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.0)

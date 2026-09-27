class_name TouchControls
extends Control

const VirtualJoystick = preload("res://scripts/virtual_joystick.gd")
const TouchActionButton = preload("res://scripts/touch_button.gd")

## Master touch controls manager for mobile devices and testing on PC.

signal camera_look(relative: Vector2)
signal move_input(vector: Vector2)
signal sprint_toggled(is_sprinting: bool)
signal jump_triggered
signal aim_toggled(is_aiming: bool)
signal fire_triggered
signal holster_triggered
signal backpack_triggered

@onready var joystick: VirtualJoystick = $LeftZone/Joystick
@onready var look_zone: Control = $RightZone/LookArea
@onready var btn_fire: TouchActionButton = $RightZone/BtnFire
@onready var btn_aim: TouchActionButton = $RightZone/BtnAim
@onready var btn_jump: TouchActionButton = $RightZone/BtnJump
@onready var btn_sprint: TouchActionButton = $RightZone/BtnSprint
@onready var btn_holster: TouchActionButton = $RightZone/BtnHolster
@onready var btn_backpack: TouchActionButton = $RightZone/BtnBackpack

var look_touch_index: int = -1
var look_sensitivity: float = 0.006

func _ready() -> void:
	if joystick:
		joystick.joystick_vector.connect(_on_joystick_vector)
	
	if btn_fire:
		btn_fire.pressed.connect(func(): emit_signal("fire_triggered"))
	if btn_aim:
		btn_aim.toggled.connect(func(on): emit_signal("aim_toggled", on))
	if btn_jump:
		btn_jump.pressed.connect(func(): emit_signal("jump_triggered"))
	if btn_sprint:
		btn_sprint.toggled.connect(func(on): emit_signal("sprint_toggled", on))
	if btn_holster:
		btn_holster.pressed.connect(func(): emit_signal("holster_triggered"))
	if btn_backpack:
		btn_backpack.pressed.connect(func(): emit_signal("backpack_triggered"))
	
	if look_zone:
		look_zone.gui_input.connect(_on_look_input)

func _on_joystick_vector(v: Vector2) -> void:
	emit_signal("move_input", v)

func _on_look_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed() and look_touch_index == -1:
			look_touch_index = event.index
		elif not event.is_pressed() and event.index == look_touch_index:
			look_touch_index = -1
	elif event is InputEventScreenDrag and event.index == look_touch_index:
		emit_signal("camera_look", event.relative * look_sensitivity)

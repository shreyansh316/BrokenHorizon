class_name AmmoBox
extends Area3D

## Tactical Ammo Box Pickup in Broken Horizon.
## Collectible crate that replenishes sidearm reserve ammunition (+24 rounds)
## with bobbing/rotating physics, audio chime, and 15s respawn timer.

const SoundEffects = preload("res://scripts/sound_effects.gd")
const DamageNumber = preload("res://scripts/damage_number.gd")

@export var ammo_amount: int = 24
@export var respawn_time: float = 15.0

@onready var visual_root: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var light: OmniLight3D = $OmniLight3D

var is_collected: bool = false
var respawn_timer: float = 0.0
var base_y: float = 0.0
var anim_time: float = 0.0

func _ready() -> void:
	base_y = visual_root.position.y if visual_root else 0.4
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_collected:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	# Idle bobbing and smooth rotation
	anim_time += delta
	if visual_root:
		visual_root.rotation.y += 1.5 * delta
		visual_root.position.y = base_y + sin(anim_time * 2.5) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	if body.has_method("add_ammo"):
		var added: int = body.add_ammo(ammo_amount)
		if added > 0:
			_collect(body, added)

func _collect(collector: Node3D, amount: int) -> void:
	is_collected = true
	respawn_timer = respawn_time
	
	if visual_root:
		visual_root.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if light:
		light.visible = false
	
	# Play pleasant pickup chime
	SoundEffects.play_pickup(collector)
	
	# Floating pickup notification in 3D
	DamageNumber.spawn(get_parent(), global_position + Vector3(0, 0.6, 0), amount, false)
	print("[Pickup] Collected +%d Ammo!" % amount)

func _respawn() -> void:
	is_collected = false
	if visual_root:
		visual_root.visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if light:
		light.visible = true
	print("[Pickup] Ammo Box Respawned!")

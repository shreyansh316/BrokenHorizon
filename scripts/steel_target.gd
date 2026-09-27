class_name SteelTarget
extends StaticBody3D

## Reactive steel shooting plate that drops back when shot and auto-resets.

const DamageNumber = preload("res://scripts/damage_number.gd")
const ChallengeManager = preload("res://scripts/challenge_manager.gd")

@onready var plate: Node3D = $Hinge/PlateMesh
@onready var hinge: Node3D = $Hinge

var is_down: bool = false
var reset_timer: float = 0.0
const RESET_DELAY: float = 2.5

func _physics_process(delta: float) -> void:
	if is_down:
		reset_timer -= delta
		# Smoothly drop flat
		hinge.rotation.x = lerp_angle(hinge.rotation.x, deg_to_rad(-85.0), 18.0 * delta)
		if reset_timer <= 0.0:
			_reset_plate()
	else:
		# Standing upright
		hinge.rotation.x = lerp_angle(hinge.rotation.x, 0.0, 15.0 * delta)

func take_damage(damage: int, hit_point: Vector3, ray_dir: Vector3) -> void:
	if is_down:
		return
	
	is_down = true
	reset_timer = RESET_DELAY
	
	# Spawn damage text
	DamageNumber.spawn(get_parent(), hit_point, damage, false)
	ChallengeManager.on_target_hit(150, false)
	
	print("[Combat] Steel Target HIT & DROPPED!")

func _reset_plate() -> void:
	is_down = false
	print("[Combat] Steel Target RESET!")

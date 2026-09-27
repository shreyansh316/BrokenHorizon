class_name TargetDummy
extends StaticBody3D

## Interactive training dummy with health, spring wobble physics, and damage numbers.

const DamageNumber = preload("res://scripts/damage_number.gd")
const ChallengeManager = preload("res://scripts/challenge_manager.gd")

@export var max_health: int = 100
var current_health: int = 100

@onready var pivot: Node3D = $Pivot
@onready var mesh_torso: MeshInstance3D = $Pivot/TorsoMesh
@onready var mesh_head: MeshInstance3D = $Pivot/HeadMesh

# Spring wobble physics
var wobble_rot: Vector3 = Vector3.ZERO
var wobble_vel: Vector3 = Vector3.ZERO
const SPRING_K: float = 120.0
const DAMPING: float = 12.0

var is_dead: bool = false
var reset_timer: float = 0.0

var original_torso_mat: StandardMaterial3D
var flash_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	if mesh_torso and mesh_torso.get_active_material(0):
		original_torso_mat = mesh_torso.get_active_material(0).duplicate()
		mesh_torso.material_override = original_torso_mat

func _physics_process(delta: float) -> void:
	# Flash effect timer
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and original_torso_mat:
			original_torso_mat.albedo_color = Color(0.8, 0.4, 0.2)
	
	if is_dead:
		reset_timer -= delta
		# Laying knocked down
		pivot.rotation.x = lerp_angle(pivot.rotation.x, deg_to_rad(-85.0), 10.0 * delta)
		if reset_timer <= 0.0:
			_respawn()
		return
	
	# Spring simulation for wobble
	var spring_force := -wobble_rot * SPRING_K
	var damping_force := -wobble_vel * DAMPING
	wobble_vel += (spring_force + damping_force) * delta
	wobble_rot += wobble_vel * delta
	
	if pivot:
		pivot.rotation = wobble_rot

func take_damage(damage: int, hit_point: Vector3, ray_dir: Vector3) -> void:
	if is_dead:
		return
	
	# Check for headshot (head is above Y = 1.45 relative to dummy base)
	var local_hit := global_transform.affine_inverse() * hit_point
	var is_headshot := local_hit.y > 1.45
	
	var final_damage := damage * 2 if is_headshot else damage
	current_health -= final_damage
	
	# Spawn 3D floating damage number
	DamageNumber.spawn(get_parent(), hit_point, final_damage, is_headshot)
	ChallengeManager.on_target_hit(120 if is_headshot else 60, is_headshot)
	
	# Apply wobble impulse in bullet direction
	var push_dir := (global_transform.basis.inverse() * ray_dir).normalized()
	# Rotate pitch and roll based on bullet direction
	wobble_vel.x += push_dir.z * 18.0
	wobble_vel.z += -push_dir.x * 18.0
	
	# Visual hit flash
	if original_torso_mat:
		original_torso_mat.albedo_color = Color(1.0, 1.0, 1.0)
		flash_timer = 0.08
	
	if current_health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	reset_timer = 2.5
	current_health = 0
	print("[Combat] Dummy KNOCKED DOWN! Resetting in 2.5s...")

func _respawn() -> void:
	is_dead = false
	current_health = max_health
	wobble_rot = Vector3.ZERO
	wobble_vel = Vector3(deg_to_rad(30), 0, 0) # Spring back up with a bounce
	print("[Combat] Dummy RESPAWNED and ready!")

class_name EnemyAI
extends CharacterBody3D

## Tactical hostile AI soldier for Broken Horizon.
## Features patrol routes, visual/hearing perception, firearm engagement,
## close-quarters melee combat, headshot vulnerability, and dynamic billboard status.

const DamageNumber = preload("res://scripts/damage_number.gd")
const CombatEffects = preload("res://scripts/combat_effects.gd")
const SoundEffects = preload("res://scripts/sound_effects.gd")
const PISTOL_SCENE: PackedScene = preload("res://assets/models/equipment/tactical_pistol.glb")
const ChallengeManager = preload("res://scripts/challenge_manager.gd")

enum State { PATROL, INVESTIGATE, CHASE, ATTACK_RANGED, ATTACK_MELEE, HIT, DEAD }

@export var max_health: int = 100
var current_health: int = 100

@export var walk_speed: float = 2.4
@export var run_speed: float = 4.8
@export var patrol_range: float = 7.0
@export var vision_range: float = 20.0
@export var vision_fov: float = 65.0 # half-angle in degrees
@export var ranged_attack_range: float = 11.0
@export var melee_attack_range: float = 1.9

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_state: State = State.PATROL

# Perception & Target
var player: Node3D = null
var last_known_player_pos: Vector3 = Vector3.ZERO
var patrol_start_pos: Vector3 = Vector3.ZERO
var patrol_target_pos: Vector3 = Vector3.ZERO
var is_patrol_reversing: bool = false
var patrol_wait_timer: float = 0.0

# Timers
var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 0.95
var melee_timer: float = 0.0
const MELEE_INTERVAL: float = 1.1
var hit_stagger_timer: float = 0.0
var investigate_timer: float = 0.0
var respawn_timer: float = 0.0
const RESPAWN_DELAY: float = 10.0

# Nodes
@onready var character_mesh: Node3D = $character
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var alert_label: Label3D = $AlertLabel3D
@onready var status_label: Label3D = $StatusLabel3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var weapon_mount: Node3D = null
var current_anim: String = ""

func _ready() -> void:
	current_health = max_health
	patrol_start_pos = global_position
	patrol_target_pos = patrol_start_pos + transform.basis.z * patrol_range
	
	_find_player()
	_setup_animations()
	_setup_enemy_visuals()
	_attach_weapon()
	_update_status_display()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		var p := get_parent()
		if p and p.has_node("Player"):
			player = p.get_node("Player")

func _setup_animations() -> void:
	if not anim_player:
		return
	anim_player.playback_default_blend_time = 0.15
	for anim_name in ["BH_Idle", "BH_Walk_F", "BH_Run", "BH_Pistol_Aim", "idle", "walk", "run", "aim"]:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	for anim_name in ["BH_Pistol_Fire", "BH_Punch_Light", "BH_Punch_Heavy", "shoot", "punch_l", "punch_r"]:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_NONE
	_play_anim("BH_Idle")

func _setup_enemy_visuals() -> void:
	if not character_mesh:
		return
	
	var dark_armor_mat := StandardMaterial3D.new()
	dark_armor_mat.albedo_color = Color(0.18, 0.19, 0.22)
	dark_armor_mat.roughness = 0.7
	dark_armor_mat.metallic = 0.2
	
	var hostile_red_mat := StandardMaterial3D.new()
	hostile_red_mat.albedo_color = Color(0.85, 0.15, 0.1)
	hostile_red_mat.emission_enabled = true
	hostile_red_mat.emission = Color(0.9, 0.15, 0.1)
	hostile_red_mat.emission_energy_multiplier = 1.2
	
	for child in character_mesh.get_children():
		if child is MeshInstance3D:
			if "Jacket" in child.name or "Shirt" in child.name:
				child.material_override = dark_armor_mat
			elif "Hair" in child.name:
				child.material_override = hostile_red_mat

func _attach_weapon() -> void:
	var skeleton = character_mesh.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return
	
	var bone_idx: int = skeleton.find_bone("RightHand")
	if bone_idx == -1:
		return
	
	var attachment := BoneAttachment3D.new()
	attachment.name = "Enemy_Hand_R"
	attachment.bone_name = "RightHand"
	skeleton.add_child(attachment)
	
	weapon_mount = Marker3D.new()
	weapon_mount.name = "WeaponMount"
	weapon_mount.transform = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(90), deg_to_rad(0), deg_to_rad(-90))),
		Vector3(0.01, -0.06, 0.04)
	)
	attachment.add_child(weapon_mount)
	
	var pistol_inst = PISTOL_SCENE.instantiate()
	weapon_mount.add_child(pistol_inst)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state == State.DEAD:
		respawn_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if respawn_timer <= 0.0:
			_respawn()
		return

	if not player:
		_find_player()

	# Check player distance and Line of Sight
	var dist_to_player: float = 999.0
	var can_see_player: bool = false
	if player and is_instance_valid(player):
		dist_to_player = global_position.distance_to(player.global_position)
		can_see_player = _check_vision(player.global_position)

	# State dispatch
	match current_state:
		State.PATROL:
			_process_patrol(delta, dist_to_player, can_see_player)
		State.INVESTIGATE:
			_process_investigate(delta, dist_to_player, can_see_player)
		State.CHASE:
			_process_chase(delta, dist_to_player, can_see_player)
		State.ATTACK_RANGED:
			_process_attack_ranged(delta, dist_to_player, can_see_player)
		State.ATTACK_MELEE:
			_process_attack_melee(delta, dist_to_player)
		State.HIT:
			hit_stagger_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			if hit_stagger_timer <= 0.0:
				current_state = State.CHASE

	move_and_slide()

# --- STATE PROCESSORS ---

func _process_patrol(delta: float, dist: float, can_see: bool) -> void:
	alert_label.text = ""
	
	if dist < 8.0 and player and player.velocity.length() > 3.0:
		_enter_investigate(player.global_position)
		return
	
	if can_see and dist <= vision_range:
		_enter_chase()
		return

	if patrol_wait_timer > 0.0:
		patrol_wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		_play_anim("BH_Idle")
		return

	var dest: Vector3 = patrol_start_pos if is_patrol_reversing else patrol_target_pos
	var diff := dest - global_position
	diff.y = 0.0
	
	if diff.length() < 0.6:
		is_patrol_reversing = not is_patrol_reversing
		patrol_wait_timer = 2.2
		_play_anim("BH_Idle")
		return

	var dir := diff.normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	_face_direction(dir, 8.0 * delta)
	_play_anim("BH_Walk_F", 0.9)

func _process_investigate(delta: float, dist: float, can_see: bool) -> void:
	alert_label.text = "?"
	alert_label.modulate = Color(1.0, 0.85, 0.1)
	
	if can_see and dist <= vision_range:
		_enter_chase()
		return
	
	investigate_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	
	var dir := (last_known_player_pos - global_position).normalized()
	dir.y = 0.0
	_face_direction(dir, 10.0 * delta)
	_play_anim("BH_Pistol_Aim")
	
	if investigate_timer <= 0.0:
		current_state = State.PATROL

func _process_chase(delta: float, dist: float, can_see: bool) -> void:
	alert_label.text = "!"
	alert_label.modulate = Color(0.95, 0.15, 0.15)
	
	if not player:
		current_state = State.PATROL
		return

	last_known_player_pos = player.global_position
	
	if dist <= melee_attack_range:
		current_state = State.ATTACK_MELEE
		melee_timer = 0.1
		return
	
	if dist <= ranged_attack_range and can_see:
		current_state = State.ATTACK_RANGED
		shoot_timer = 0.4
		return
	
	if dist > vision_range * 1.5:
		_enter_investigate(last_known_player_pos)
		return

	var diff := player.global_position - global_position
	diff.y = 0.0
	var dir := diff.normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed
	_face_direction(dir, 12.0 * delta)
	_play_anim("BH_Run", 1.1)

func _process_attack_ranged(delta: float, dist: float, can_see: bool) -> void:
	alert_label.text = "!"
	alert_label.modulate = Color(0.95, 0.15, 0.15)
	
	if not player:
		current_state = State.PATROL
		return

	if dist <= melee_attack_range:
		current_state = State.ATTACK_MELEE
		melee_timer = 0.05
		return

	if dist > ranged_attack_range + 3.0 or not can_see:
		current_state = State.CHASE
		return

	# Stop and face player
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	
	var dir := (player.global_position - global_position).normalized()
	dir.y = 0.0
	_face_direction(dir, 14.0 * delta)

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = SHOOT_INTERVAL
		_fire_at_player()
	else:
		_play_anim("BH_Pistol_Aim")

func _fire_at_player() -> void:
	_play_anim("BH_Pistol_Fire", 1.4)
	SoundEffects.play_gunshot(self)
	
	var muzzle_pos: Vector3 = weapon_mount.global_position if weapon_mount else global_position + Vector3(0, 1.2, 0)
	CombatEffects.create_muzzle_flash(get_parent(), muzzle_pos)
	
	var world := get_world_3d()
	if not world or not player:
		return
	
	var space := world.direct_space_state
	var target_pos := player.global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.8, 1.4), randf_range(-0.35, 0.35))
	var ray_dir := (target_pos - muzzle_pos).normalized()
	var query := PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + ray_dir * 50.0)
	query.exclude = [self.get_rid()]
	var result := space.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		var hit_norm: Vector3 = result.normal
		var collider = result.collider
		CombatEffects.create_hit_spark(get_parent(), hit_pos, hit_norm)
		
		if collider and collider.has_method("take_damage"):
			collider.take_damage(14, hit_pos, ray_dir)
			print("[Enemy AI] Shot hit protagonist! Damage: 14")

func _process_attack_melee(delta: float, dist: float) -> void:
	alert_label.text = "!!"
	alert_label.modulate = Color(1.0, 0.05, 0.05)
	
	if not player:
		current_state = State.PATROL
		return

	var dir := (player.global_position - global_position).normalized()
	dir.y = 0.0
	_face_direction(dir, 18.0 * delta)
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	melee_timer -= delta
	if melee_timer <= 0.0:
		melee_timer = MELEE_INTERVAL
		var anim := "BH_Punch_Light" if randf() > 0.5 else "BH_Punch_Heavy"
		_play_anim(anim, 1.3)
		SoundEffects.play_punch_whoosh(self)
		
		if dist <= melee_attack_range + 0.4:
			player.take_damage(20, player.global_position + Vector3(0, 1.1, 0), dir)
			SoundEffects.play_punch_impact(player, player.global_position + Vector3(0, 1.1, 0))
			print("[Enemy AI] Melee strike hit protagonist! Damage: 20")
	
	if dist > melee_attack_range + 1.2:
		current_state = State.CHASE

# --- SENSING & HELPERS ---

func _check_vision(target_pos: Vector3) -> bool:
	var diff := target_pos - global_position
	var dist := diff.length()
	if dist > vision_range:
		return false
	
	var forward := -character_mesh.global_transform.basis.z
	var to_target_flat := Vector3(diff.x, 0.0, diff.z).normalized()
	var forward_flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var angle := rad_to_deg(acos(clampf(forward_flat.dot(to_target_flat), -1.0, 1.0)))
	
	if angle > vision_fov:
		return false
	
	var world := get_world_3d()
	if not world:
		return false
	var space := world.direct_space_state
	var eye_pos := global_position + Vector3(0, 1.5, 0)
	var target_eye := target_pos + Vector3(0, 1.3, 0)
	var query := PhysicsRayQueryParameters3D.create(eye_pos, target_eye)
	query.exclude = [self.get_rid()]
	var res := space.intersect_ray(query)
	
	if res:
		var col = res.collider
		return col and (col.is_in_group("player") or col.name == "Player")
	
	return true

func _enter_chase() -> void:
	current_state = State.CHASE
	if player:
		last_known_player_pos = player.global_position

func _enter_investigate(pos: Vector3) -> void:
	current_state = State.INVESTIGATE
	last_known_player_pos = pos
	investigate_timer = 2.5

func _face_direction(dir: Vector3, weight: float) -> void:
	if dir.length_squared() < 0.01 or not character_mesh:
		return
	var target_rot := atan2(dir.x, dir.z)
	character_mesh.rotation.y = lerp_angle(character_mesh.rotation.y, target_rot, weight)

func _play_anim(anim_name: String, speed: float = 1.0) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	anim_player.speed_scale = speed
	if current_anim != anim_name:
		current_anim = anim_name
		anim_player.play(anim_name)

func _update_status_display() -> void:
	if not status_label:
		return
	var bar_length := 8
	var filled := int(float(current_health) / float(max_health) * float(bar_length))
	var bar := ""
	for i in range(bar_length):
		bar += "█" if i < filled else "░"
	status_label.text = "[%s] %d HP" % [bar, current_health]
	var ratio := float(current_health) / float(max_health)
	if ratio > 0.5:
		status_label.modulate = Color(0.9, 0.3, 0.3)
	elif ratio > 0.25:
		status_label.modulate = Color(1.0, 0.6, 0.2)
	else:
		status_label.modulate = Color(1.0, 0.1, 0.1)

# --- COMBAT & DAMAGE RECEIVER ---

func take_damage(damage: int, hit_point: Vector3, ray_dir: Vector3, force_headshot: bool = false) -> void:
	if current_state == State.DEAD:
		return

	var local_hit := global_transform.affine_inverse() * hit_point
	var is_headshot: bool = force_headshot or (local_hit.y > 1.45)
	var final_damage := damage * 2 if is_headshot else damage
	current_health = maxi(0, current_health - final_damage)
	
	DamageNumber.spawn(get_parent(), hit_point, final_damage, is_headshot)
	ChallengeManager.on_target_hit(150 if is_headshot else 80, is_headshot)
	_update_status_display()
	
	if player:
		last_known_player_pos = player.global_position
	current_state = State.HIT
	hit_stagger_timer = 0.25
	
	var impulse_dir := -ray_dir
	impulse_dir.y = 0.0
	velocity += impulse_dir.normalized() * (4.0 if is_headshot else 2.5)
	
	print("[Combat] Enemy took %d damage! (Headshot: %s) HP: %d/%d" % [
		final_damage, str(is_headshot), current_health, max_health
	])

	if current_health <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	respawn_timer = RESPAWN_DELAY
	alert_label.text = "ELIMINATED"
	alert_label.modulate = Color(0.7, 0.7, 0.7)
	status_label.text = "+500 PTS"
	status_label.modulate = Color(1.0, 0.85, 0.2)
	ChallengeManager.on_target_hit(500, false)
	
	if collision_shape:
		collision_shape.disabled = true
	
	_play_anim("BH_Knockdown")
	if character_mesh:
		character_mesh.rotation.x = deg_to_rad(-85.0)
	
	print("[Combat] Hostile Enemy Eliminated! Respawning in %.1fs..." % RESPAWN_DELAY)

func _respawn() -> void:
	current_health = max_health
	current_state = State.PATROL
	global_position = patrol_start_pos
	if collision_shape:
		collision_shape.disabled = false
	if character_mesh:
		character_mesh.rotation.x = 0.0
	_update_status_display()
	alert_label.text = ""
	print("[Combat] Hostile Enemy Respawned at patrol point!")

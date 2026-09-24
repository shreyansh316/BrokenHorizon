class_name PlayerController
extends CharacterBody3D

## Broken Horizon — Complete Third-Person Protagonist Controller
## Supports 8-way directional locomotion, sprinting, crouch stealth, jumping lifecycle,
## over-the-shoulder hitscan firearm combat, tactical CQC 3-hit melee combo,
## equipment management, vitals/regeneration, and tactical drill challenge tracking.

const CombatEffects = preload("res://scripts/combat_effects.gd")
const PlayerHUD = preload("res://scripts/hud.gd")
const EquipmentManager = preload("res://scripts/equipment_manager.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const SoundEffects = preload("res://scripts/sound_effects.gd")
const ChallengeManager = preload("res://scripts/challenge_manager.gd")

# Locomotion Speeds
@export var walk_speed: float = 3.6
@export var jog_speed: float = 5.2
@export var sprint_speed: float = 7.4
@export var crouch_speed: float = 2.0
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.003
@export var fire_rate: float = 0.22

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Scene References
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var character_mesh: Node3D = $character
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var hud: PlayerHUD = $CanvasLayer/HUD
@onready var touch_controls: TouchControls = $CanvasLayer/TouchControls

# Animation & Movement State
var current_anim: String = ""
var is_aiming: bool = false
var is_crouching: bool = false
var can_fire: bool = true
var fire_timer: float = 0.0
var footstep_timer: float = 0.0
var jump_state: String = "grounded" # "grounded", "rising", "falling", "landing"
var land_timer: float = 0.0

# Melee 3-Hit Combo
var melee_combo_step: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 0.55
const MELEE_RANGE: float = 2.0

# Health and Regeneration
@export var max_health: int = 100
var current_health: int = 100
var regen_timer: float = 0.0
const REGEN_DELAY: float = 5.0
const REGEN_RATE: float = 15.0
var is_dead: bool = false
var respawn_timer: float = 0.0

# Ammunition & Reload
@export var max_mag_ammo: int = 12
var current_mag_ammo: int = 12
@export var max_reserve_ammo: int = 72
var reserve_ammo: int = 36
var is_reloading: bool = false
var reload_timer: float = 0.0
const RELOAD_DURATION: float = 1.2

# Touch Controls Input
var touch_move_vector: Vector2 = Vector2.ZERO
var touch_is_sprinting: bool = false

# Over-The-Shoulder Camera Parameters
const DEFAULT_SPRING_LENGTH: float = 3.5
const AIM_SPRING_LENGTH: float = 1.8
const CROUCH_SPRING_LENGTH: float = 2.8
const DEFAULT_CAMERA_POS: Vector3 = Vector3(0.0, 0.0, 0.0)
const AIM_CAMERA_POS: Vector3 = Vector3(0.55, 0.15, 0.0)
const CROUCH_CAMERA_POS: Vector3 = Vector3(0.2, -0.35, 0.0)

func _ready() -> void:
	add_to_group("player")
	if not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	_setup_animations()
	
	current_health = max_health
	if hud:
		hud.update_health(current_health, max_health)
		hud.update_ammo(current_mag_ammo, reserve_ammo)
	
	if equipment_manager and hud:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)
	
	if touch_controls:
		_setup_touch_controls()

func _setup_touch_controls() -> void:
	touch_controls.move_input.connect(func(v: Vector2): touch_move_vector = v)
	touch_controls.camera_look.connect(_on_touch_camera_look)
	touch_controls.jump_triggered.connect(_on_touch_jump)
	touch_controls.sprint_toggled.connect(func(on: bool): touch_is_sprinting = on)
	touch_controls.aim_toggled.connect(func(on: bool): set_aiming(on))
	touch_controls.fire_triggered.connect(func():
		if is_aiming: fire_weapon()
		else: melee_attack()
	)
	touch_controls.holster_triggered.connect(func(): if equipment_manager: equipment_manager.toggle_weapon())
	touch_controls.backpack_triggered.connect(func(): if equipment_manager: equipment_manager.toggle_backpack())

func _on_touch_camera_look(rel: Vector2) -> void:
	spring_arm.rotation.y -= rel.x
	spring_arm.rotation.x = clamp(
		spring_arm.rotation.x - rel.y,
		deg_to_rad(-75.0),
		deg_to_rad(45.0)
	)

func _on_touch_jump() -> void:
	if is_on_floor() and not is_crouching:
		perform_jump()

func _setup_animations() -> void:
	if not anim_player:
		return
	anim_player.playback_default_blend_time = 0.18
	
	# Loop modes
	var looping_anims = [
		"BH_Idle", "BH_Idle_Var01", "BH_Idle_Var02", "BH_Unarmed_Idle",
		"BH_Walk_F", "BH_Walk_B", "BH_Walk_L", "BH_Walk_R",
		"BH_Walk_FL", "BH_Walk_FR", "BH_Walk_BL", "BH_Walk_BR",
		"BH_Jog", "BH_Run", "BH_Sprint",
		"BH_Run_FL", "BH_Run_FR", "BH_Run_BL", "BH_Run_BR",
		"BH_Turn_L", "BH_Turn_R",
		"BH_Jump_Fall", "BH_Crouch_Idle", "BH_Crouch_Walk",
		"BH_Combat_Idle", "BH_Pistol_Idle", "BH_Pistol_Aim", "BH_Rifle_Idle", "BH_Rifle_Aim",
		"BH_Interact_Push", "BH_Interact_Pull", "BH_Interact_Climb",
		"BH_Vehicle_Sit", "BH_Vehicle_Steer",
		"idle", "walk", "run", "aim"
	]
	for anim_name in looping_anims:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			
	_play_anim("BH_Idle")

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * (0.6 if is_aiming else 1.0)
		spring_arm.rotation.y -= event.relative.x * sens
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x - event.relative.y * sens,
			deg_to_rad(-75.0),
			deg_to_rad(45.0)
		)

	# Aiming (RMB)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		set_aiming(event.is_pressed())

	# Firing / Melee (LMB)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_aiming:
			fire_weapon()
		else:
			melee_attack()

	# Dedicated melee key (F)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_F:
		melee_attack()

	# Crouch toggle (C)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_C:
		toggle_crouch()

	# Reload weapon (R)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_R:
		reload_weapon()

	# Toggle Tactical Drill (T)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_T:
		ChallengeManager.toggle_drill()

	# Weapon Equip/Holster (1)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_1:
		if equipment_manager:
			equipment_manager.toggle_weapon()

	# Backpack toggle (2)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_2:
		if equipment_manager:
			equipment_manager.toggle_backpack()

	# Capture / Release Mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_aiming(aiming: bool) -> void:
	is_aiming = aiming
	if is_aiming and is_crouching:
		is_crouching = false
	if hud:
		hud.set_aiming(aiming)
	
	if is_aiming and equipment_manager:
		if equipment_manager.equipped_items.get("weapon_state") != "drawn":
			equipment_manager.toggle_weapon()

func toggle_crouch() -> void:
	if not is_on_floor():
		return
	is_crouching = not is_crouching
	if is_crouching:
		is_aiming = false
		_play_anim("BH_Crouch_Enter", 1.4)
	else:
		_play_anim("BH_Crouch_Exit", 1.4)

func perform_jump() -> void:
	if not is_on_floor() or is_dead:
		return
	velocity.y = jump_velocity
	jump_state = "rising"
	_play_anim("BH_Jump_Start", 1.5)

## Over-the-shoulder hitscan shooting
func fire_weapon() -> void:
	if not can_fire or is_reloading or is_dead:
		return
	
	if current_mag_ammo <= 0:
		SoundEffects.play_dry_fire(self)
		if hud:
			hud.prompt_reload()
		return
	
	current_mag_ammo -= 1
	if hud:
		hud.update_ammo(current_mag_ammo, reserve_ammo)
		hud.add_recoil_kick()
	
	can_fire = false
	fire_timer = fire_rate
	
	_play_anim("BH_Pistol_Fire", 1.6)
	SoundEffects.play_gunshot(self)
	ChallengeManager.on_shot_fired()
	
	# Recoil kick on camera
	spring_arm.rotation.x = clamp(spring_arm.rotation.x + deg_to_rad(0.85), deg_to_rad(-75.0), deg_to_rad(45.0))
	
	var hand_mount = equipment_manager.get_socket("hand_r") if equipment_manager else null
	var flash_pos = hand_mount.global_position if hand_mount else global_position + Vector3(0, 1.2, 0)
	CombatEffects.create_muzzle_flash(get_parent(), flash_pos)
	
	# Raycast from camera center
	var world := get_world_3d()
	if not world:
		return
	var space_state := world.direct_space_state
	var center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)
	var ray_end := ray_origin + ray_dir * 250.0
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self.get_rid()]
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit_point: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		var collider = result.collider
		
		if collider and collider.has_method("take_damage"):
			collider.take_damage(25, hit_point, ray_dir)
		
		CombatEffects.create_hit_spark(get_parent(), hit_point, hit_normal)
		SoundEffects.play_bullet_impact(get_parent(), hit_point)
		
		if hud:
			hud.trigger_hit_marker()

## Close-quarters tactical 3-hit melee combo
func melee_attack() -> void:
	if not can_fire or is_dead:
		return
	
	can_fire = false
	fire_timer = 0.35
	
	var damage: int = 30
	var anim_to_play: String = "BH_Punch_Light"
	
	if melee_combo_step == 1 and combo_timer > 0.0:
		melee_combo_step = 2
		combo_timer = COMBO_WINDOW + 0.1
		damage = 48
		anim_to_play = "BH_Punch_Heavy"
	elif melee_combo_step == 2 and combo_timer > 0.0:
		melee_combo_step = 3
		combo_timer = COMBO_WINDOW + 0.2
		damage = 65
		anim_to_play = "BH_Kick"
	else:
		melee_combo_step = 1
		combo_timer = COMBO_WINDOW
		damage = 30
		anim_to_play = "BH_Punch_Light"
	
	_play_anim(anim_to_play, 1.35)
	SoundEffects.play_punch_whoosh(self)
	
	# Forward strike cone check
	var world := get_world_3d()
	if not world:
		return
	var space_state := world.direct_space_state
	var strike_origin := global_position + Vector3(0, 1.1, 0)
	var forward := -character_mesh.global_transform.basis.z
	var strike_target := strike_origin + forward * MELEE_RANGE
	
	var query := PhysicsRayQueryParameters3D.create(strike_origin, strike_target)
	query.exclude = [self.get_rid()]
	var result := space_state.intersect_ray(query)
	
	if not result:
		var right := character_mesh.global_transform.basis.x
		for off_x in [-0.35, 0.35]:
			var off_target: Vector3 = strike_origin + forward * MELEE_RANGE + right * float(off_x)
			var off_query := PhysicsRayQueryParameters3D.create(strike_origin, off_target)
			off_query.exclude = [self.get_rid()]
			result = space_state.intersect_ray(off_query)
			if result:
				break
	
	if result:
		var hit_point: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		var collider = result.collider
		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage, hit_point, forward)
		CombatEffects.create_hit_spark(get_parent(), hit_point, hit_normal)
		SoundEffects.play_punch_impact(get_parent(), hit_point)
		if hud:
			hud.trigger_hit_marker()

func reload_weapon() -> void:
	if is_reloading or is_dead:
		return
	if current_mag_ammo >= max_mag_ammo or reserve_ammo <= 0:
		return
	is_reloading = true
	reload_timer = RELOAD_DURATION
	SoundEffects.play_reload(self)
	_play_anim("BH_Pistol_Reload", 1.0)
	if hud:
		hud.show_reloading()

func add_ammo(amount: int) -> int:
	var needed := max_reserve_ammo - reserve_ammo
	var added := mini(needed, amount)
	reserve_ammo += added
	if hud:
		hud.update_ammo(current_mag_ammo, reserve_ammo)
	return added

func take_damage(damage: int, hit_point: Vector3 = Vector3.ZERO, dir: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	current_health = maxi(0, current_health - damage)
	regen_timer = REGEN_DELAY
	if hud:
		hud.update_health(current_health, max_health)
		hud.trigger_hurt_flash()
	
	spring_arm.rotation.x = clampf(spring_arm.rotation.x + randf_range(-0.03, 0.03), deg_to_rad(-75.0), deg_to_rad(45.0))
	spring_arm.rotation.y += randf_range(-0.02, 0.02)
	SoundEffects.play_bullet_impact(get_parent(), global_position + Vector3(0, 1.2, 0))
	
	if current_health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	respawn_timer = 3.5
	_play_anim("BH_Knockdown", 1.0)
	print("[Combat] Protagonist downed! Respawning...")

func _respawn() -> void:
	is_dead = false
	current_health = max_health
	current_mag_ammo = max_mag_ammo
	global_position = Vector3(0.0, 0.2, 0.0)
	_play_anim("BH_Get_Up", 1.2)
	if hud:
		hud.update_health(current_health, max_health)
		hud.update_ammo(current_mag_ammo, reserve_ammo)

func _physics_process(delta: float) -> void:
	if is_dead:
		respawn_timer -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		if respawn_timer <= 0.0:
			_respawn()
		return

	# Natural health regeneration
	if regen_timer > 0.0:
		regen_timer -= delta
	elif current_health < max_health:
		var new_hp: int = mini(max_health, int(float(current_health) + REGEN_RATE * delta))
		if new_hp != current_health:
			current_health = new_hp
			if hud:
				hud.update_health(current_health, max_health)

	# Cooldowns & Timers
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true
	
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			melee_combo_step = 0

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			var needed := max_mag_ammo - current_mag_ammo
			var take := mini(needed, reserve_ammo)
			current_mag_ammo += take
			reserve_ammo -= take
			if hud:
				hud.update_ammo(current_mag_ammo, reserve_ammo)

	# Smooth camera positioning
	var target_len := AIM_SPRING_LENGTH if is_aiming else (CROUCH_SPRING_LENGTH if is_crouching else DEFAULT_SPRING_LENGTH)
	var target_cam_offset := AIM_CAMERA_POS if is_aiming else (CROUCH_CAMERA_POS if is_crouching else DEFAULT_CAMERA_POS)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_len, 10.0 * delta)
	camera.position = camera.position.lerp(target_cam_offset, 10.0 * delta)

	# Gravity & Jump
	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y > 0.5:
			jump_state = "rising"
		else:
			jump_state = "falling"
	else:
		if jump_state == "falling":
			jump_state = "landing"
			land_timer = 0.15
			_play_anim("BH_Jump_Land", 1.4)
		elif jump_state == "landing":
			land_timer -= delta
			if land_timer <= 0.0:
				jump_state = "grounded"
		else:
			jump_state = "grounded"

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_crouching:
		perform_jump()

	# Direction vector calculation from Keyboard + Touch
	var key_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_dir: Vector2 = key_input if key_input.length_squared() > 0.01 else touch_move_vector

	var camera_basis := spring_arm.global_transform.basis if spring_arm else global_transform.basis
	var forward := -camera_basis.z
	var right := camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction := (right * input_dir.x - forward * input_dir.y).normalized()
	var is_sprint := (Input.is_key_pressed(KEY_SHIFT) or touch_is_sprinting) and not is_aiming and not is_crouching

	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprint:
		target_speed = sprint_speed
	elif is_aiming:
		target_speed = walk_speed * 0.75
	else:
		target_speed = jog_speed

	if direction != Vector3.ZERO:
		var target_vel := direction * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	# Mesh Rotation: aim direction vs move direction
	if is_aiming:
		var target_rot := spring_arm.rotation.y + PI
		character_mesh.rotation.y = lerp_angle(character_mesh.rotation.y, target_rot, 20.0 * delta)
	elif direction != Vector3.ZERO:
		var target_rot := atan2(direction.x, direction.z)
		character_mesh.rotation.y = lerp_angle(character_mesh.rotation.y, target_rot, 12.0 * delta)

	move_and_slide()
	_update_locomotion_animation(input_dir, is_sprint)

	# Footsteps
	if is_on_floor() and direction != Vector3.ZERO and not is_crouching:
		var step_interval := 0.24 if is_sprint else (0.34 if target_speed == jog_speed else 0.44)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = step_interval
			SoundEffects.play_footstep(self)
	else:
		footstep_timer = 0.08

func _update_locomotion_animation(input_dir: Vector2, is_sprint: bool) -> void:
	if not anim_player:
		return
	
	# Action overrides that play exclusively
	var action_overrides = ["BH_Pistol_Fire", "BH_Punch_Light", "BH_Punch_Heavy", "BH_Kick", "BH_Pistol_Reload", "BH_Jump_Start", "BH_Jump_Land", "BH_Knockdown", "BH_Get_Up"]
	if current_anim in action_overrides and anim_player.is_playing():
		return

	# Airborne
	if not is_on_floor():
		if jump_state == "rising":
			_play_anim("BH_Jump_Rise", 1.0)
		else:
			_play_anim("BH_Jump_Fall", 1.0)
		return

	# Crouch State
	if is_crouching:
		if input_dir.length_squared() > 0.04:
			_play_anim("BH_Crouch_Walk", 1.1)
		else:
			_play_anim("BH_Crouch_Idle", 1.0)
		return

	# Aiming State
	if is_aiming:
		if input_dir.length_squared() > 0.04:
			# 4-way strafe animations
			if abs(input_dir.x) > abs(input_dir.y):
				if input_dir.x > 0: _play_anim("BH_Walk_R", 0.9)
				else: _play_anim("BH_Walk_L", 0.9)
			else:
				if input_dir.y < 0: _play_anim("BH_Walk_F", 0.9)
				else: _play_anim("BH_Walk_B", 0.9)
		else:
			_play_anim("BH_Pistol_Aim", 1.0)
		return

	# Standard Locomotion
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.3:
		if is_sprint and horiz_speed > 5.5:
			_play_anim("BH_Sprint", horiz_speed / sprint_speed)
		elif horiz_speed > 3.8:
			_play_anim("BH_Run", horiz_speed / jog_speed)
		else:
			_play_anim("BH_Walk_F", horiz_speed / walk_speed)
	else:
		_play_anim("BH_Idle", 1.0)

func _play_anim(anim_name: String, speed: float = 1.0) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	anim_player.speed_scale = speed
	if current_anim != anim_name:
		current_anim = anim_name
		anim_player.play(anim_name)

func _on_equipment_changed(slot_name: String, item: Node3D) -> void:
	if hud and equipment_manager:
		var state = equipment_manager.equipped_items.get("weapon_state", "holstered")
		hud.update_weapon_info("Tactical Pistol", state)

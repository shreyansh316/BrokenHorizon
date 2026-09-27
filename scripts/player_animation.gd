class_name PlayerAnimationController
extends Node

## Broken Horizon — Protagonist Third-Person Animation Controller
## Manages the AnimationPlayer, AnimationTree StateMachine, 2D Locomotion BlendSpace,
## Jump lifecycle, Crouch stealth, Combat attacks, and Interaction states.
## Designed for Godot 4.3.1 with Android mobile optimization and PC cross-compatibility.

# Signals for state changes
signal state_changed(old_state: String, new_state: String)
signal landing_triggered(is_hard_landing: bool)
signal attack_started(combo_step: int)

# Configurable Node References (exported with fallbacks)
@export var animation_player_path: NodePath = ^"../character/AnimationPlayer"
@export var animation_tree_path: NodePath = ^"../AnimationTree"
@export var character_mesh_path: NodePath = ^"../character"

# Smoothing & Responsiveness
@export var blend_damping: float = 12.0
@export var hard_landing_threshold: float = 11.5 # m/s downward velocity
@export var debug_mode: bool = false
@export var enable_root_motion: bool = false
@export var root_motion_track: NodePath = ^""

# Runtime Nodes
var anim_player: AnimationPlayer = null
var anim_tree: AnimationTree = null
var character_mesh: Node3D = null
var playback: AnimationNodeStateMachinePlayback = null

# Current Animation & Locomotion State
var current_state: String = "Locomotion"
var target_blend_pos: Vector2 = Vector2.ZERO
var current_blend_pos: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var is_grounded: bool = true
var is_sprinting: bool = false
var is_crouching: bool = false
var is_aiming: bool = false
var vertical_velocity: float = 0.0

# Safe Animation Aliases Map (Guarantees Section 1 exact naming without duplicates)
const ANIMATION_ALIASES: Dictionary = {
	"BH_Idle_Variant_01": "BH_Idle_Var01",
	"BH_Idle_Variant_02": "BH_Idle_Var02",
	"BH_Run_F": "BH_Run",
	"BH_Run_B": "BH_Run_BL",
	"BH_Run_L": "BH_Run_FL",
	"BH_Run_R": "BH_Run_FR",
	"BH_Sprint_F": "BH_Sprint",
	"BH_Sprint_B": "BH_Run_BL",
	"BH_Interact": "BH_Interact_Pickup",
	"BH_Use_Object": "BH_Interact_Inspect",
	"BH_Combat_Idle": "BH_Combat_Idle",
	"BH_Attack_01": "BH_Punch_Light",
	"BH_Attack_02": "BH_Punch_Heavy",
	"BH_Hit_Reaction": "BH_Hit_F",
	"BH_Death": "BH_Knockdown",
	"BH_Jump_Loop": "BH_Jump_Rise",
}

func _ready() -> void:
	_resolve_nodes()
	_setup_animation_library_aliases()
	_setup_animation_tree()

func _resolve_nodes() -> void:
	if has_node(animation_player_path):
		anim_player = get_node(animation_player_path) as AnimationPlayer
	elif get_parent() and get_parent().has_node("character/AnimationPlayer"):
		anim_player = get_parent().get_node("character/AnimationPlayer") as AnimationPlayer

	if has_node(animation_tree_path):
		anim_tree = get_node(animation_tree_path) as AnimationTree
	elif get_parent() and get_parent().has_node("AnimationTree"):
		anim_tree = get_parent().get_node("AnimationTree") as AnimationTree

	if has_node(character_mesh_path):
		character_mesh = get_node(character_mesh_path) as Node3D
	elif get_parent() and get_parent().has_node("character"):
		character_mesh = get_parent().get_node("character") as Node3D

func _setup_animation_library_aliases() -> void:
	if not anim_player:
		push_warning("[PlayerAnimation] AnimationPlayer not found during alias registration.")
		return

	var anim_lib: AnimationLibrary = anim_player.get_animation_library("")
	if not anim_lib:
		return

	for alias_name in ANIMATION_ALIASES:
		var target_name: String = ANIMATION_ALIASES[alias_name]
		if anim_lib.has_animation(target_name) and not anim_lib.has_animation(alias_name):
			var anim_ref: Animation = anim_lib.get_animation(target_name)
			anim_lib.add_animation(alias_name, anim_ref)
			if debug_mode:
				print("[PlayerAnimation] Registered alias: ", alias_name, " -> ", target_name)

func _setup_animation_tree() -> void:
	if not anim_tree:
		push_warning("[PlayerAnimation] AnimationTree not found.")
		return

	# Assign AnimationPlayer path if not already set
	if anim_player and (anim_tree.anim_player.is_empty() or not anim_tree.has_node(anim_tree.anim_player)):
		anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	# Load state machine resource if tree root is empty
	if not anim_tree.tree_root:
		var sm_res = load("res://assets/animations/player_state_machine.tres")
		if sm_res:
			anim_tree.tree_root = sm_res
		else:
			push_error("[PlayerAnimation] Could not load player_state_machine.tres!")

	# Root motion setting
	if enable_root_motion and not root_motion_track.is_empty():
		anim_tree.root_motion_track = root_motion_track

	anim_tree.active = true
	
	# Fetch playback controller
	if anim_tree.tree_root is AnimationNodeStateMachine:
		playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	elif anim_tree.tree_root is AnimationNodeBlendTree:
		playback = anim_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback

	if playback:
		playback.start("Locomotion")
		current_state = "Locomotion"

# ==============================================================================
# MAIN UPDATE INTERFACE (Called from PlayerController._physics_process)
# ==============================================================================

## Primary update function receiving raw kinematics and states from player.gd
func update_locomotion(
	velocity: Vector3,
	on_floor: bool,
	sprint: bool,
	crouch: bool,
	aim: bool,
	input_vector: Vector2,
	delta: float
) -> void:
	vertical_velocity = velocity.y
	is_grounded = on_floor
	is_sprinting = sprint
	is_crouching = crouch
	is_aiming = aim
	current_speed = Vector2(velocity.x, velocity.z).length()

	# 1. Update State Transitions
	_evaluate_state_transitions()

	# 2. Update BlendSpace Parameters
	_update_blend_parameters(input_vector, delta)

	# 3. Optional Debug Print
	if debug_mode:
		_print_debug_info()

# ==============================================================================
# STATE MACHINE LOGIC
# ==============================================================================

func _evaluate_state_transitions() -> void:
	if not playback:
		return

	var active_node: String = playback.get_current_node()

	# Air / Ground State Transitions
	if not is_grounded:
		if vertical_velocity > 1.0:
			if active_node != "Jump" and active_node != "Jump_Rise":
				_travel_to("Jump")
		elif vertical_velocity < -1.0:
			if active_node != "Fall":
				_travel_to("Fall")
		return

	# Landing Transition
	if is_grounded and (active_node == "Fall" or active_node == "Jump_Rise"):
		trigger_landing(abs(vertical_velocity))
		return

	# Crouch State Transitions
	if is_crouching:
		if active_node != "Crouch" and active_node != "Land" and active_node != "Land_Hard":
			_travel_to("Crouch")
		return
	elif active_node == "Crouch":
		_travel_to("Locomotion")
		return

	# Default Grounded Locomotion
	if active_node != "Locomotion" and active_node != "Land" and active_node != "Land_Hard" \
		and not active_node.begins_with("Attack") and active_node != "Kick" \
		and active_node != "Hit_Reaction" and active_node != "Interact" and active_node != "Death":
		_travel_to("Locomotion")

func _travel_to(target_state: String) -> void:
	if not playback or current_state == target_state:
		return
	var old_state := current_state
	current_state = target_state
	playback.travel(target_state)
	state_changed.emit(old_state, target_state)

# ==============================================================================
# BLENDSPACE PARAMETER CALCULATION
# ==============================================================================

func _update_blend_parameters(input_vec: Vector2, delta: float) -> void:
	if not anim_tree:
		return

	# Calculate normalized blend position based on input & speed
	# X: -1.0 = Left strafe, 0.0 = Forward/Back, 1.0 = Right strafe
	# Y: -1.0 = Backward, 0.0 = Idle, 0.5 = Walk, 1.0 = Run
	if current_speed < 0.2:
		target_blend_pos = Vector2.ZERO
	else:
		var dir_x: float = clampf(input_vec.x, -1.0, 1.0)
		var dir_y: float = clampf(-input_vec.y, -1.0, 1.0) # Up on stick is forward (+Y)
		
		# Magnitude scaling based on speed mode
		var speed_factor: float = 0.5 # Walk default
		if is_sprinting:
			speed_factor = 1.0 # Run/Sprint
		elif is_aiming:
			speed_factor = 0.5 # Aim walk
		elif current_speed > 3.8:
			speed_factor = 0.85 # Jog/Run
		
		var raw_pos := Vector2(dir_x, dir_y).normalized() * speed_factor
		target_blend_pos = raw_pos

	# Smoothly interpolate blend position to prevent snappy animation changes
	current_blend_pos = current_blend_pos.lerp(target_blend_pos, blend_damping * delta)

	# Pass parameters to AnimationTree
	anim_tree.set("parameters/Locomotion/blend_position", current_blend_pos)
	anim_tree.set("parameters/Crouch/blend_position", current_blend_pos)

# ==============================================================================
# ACTIONS, COMBAT, & INTERACTION TRIGGERS
# ==============================================================================

## Triggers jump anticipation and rise sequence
func trigger_jump() -> void:
	_travel_to("Jump")

## Reusable landing trigger supporting soft and hard landing impact
func trigger_landing(impact_speed: float = 0.0) -> void:
	var is_hard := impact_speed >= hard_landing_threshold
	landing_triggered.emit(is_hard)
	if is_hard:
		_travel_to("Land_Hard")
	else:
		_travel_to("Land")

## Triggers tactical melee strikes
func trigger_attack(combo_step: int = 1) -> void:
	attack_started.emit(combo_step)
	match combo_step:
		1:
			_travel_to("Attack_01")
		2:
			_travel_to("Attack_02")
		3:
			_travel_to("Kick")
		_:
			_travel_to("Attack_01")

## Triggers combat stance toggle
func set_combat_mode(in_combat: bool) -> void:
	if in_combat:
		_travel_to("Combat")
	else:
		_travel_to("Locomotion")

## Triggers hit reaction stagger
func trigger_hit_reaction() -> void:
	_travel_to("Hit_Reaction")

## Triggers death / knockdown collapse
func trigger_death() -> void:
	_travel_to("Death")

## Triggers environmental interaction (pickup / examine)
func trigger_interact() -> void:
	_travel_to("Interact")

# ==============================================================================
# DEBUG & TELEMETRY
# ==============================================================================

func get_debug_info() -> Dictionary:
	return {
		"current_state": current_state,
		"current_speed": snapped(current_speed, 0.01),
		"blend_position": current_blend_pos,
		"is_grounded": is_grounded,
		"is_sprinting": is_sprinting,
		"is_crouching": is_crouching,
		"is_aiming": is_aiming,
		"vertical_vel": snapped(vertical_velocity, 0.01)
	}

func _print_debug_info() -> void:
	var info = get_debug_info()
	print("[AnimDebug] State: %s | Spd: %.2f | Blend: (%.2f, %.2f) | Grd: %s | Crouch: %s" % [
		info["current_state"],
		info["current_speed"],
		info["blend_position"].x,
		info["blend_position"].y,
		str(info["is_grounded"]),
		str(info["is_crouching"])
	])

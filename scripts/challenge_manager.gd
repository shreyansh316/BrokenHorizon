class_name ChallengeManager
extends Node

## Manages Shooting Range tactical drills, scoring, accuracy tracking,
## dynamic combo multipliers, and performance grading.

signal score_changed(score: int, delta: int, combo: float)
signal combo_changed(combo: float, progress: float)
signal accuracy_changed(acc: float, hits: int, shots: int)
signal timer_changed(time_left: float, is_active: bool)
signal drill_finished(score: int, acc: float, hits: int, rank: String)

static var instance: ChallengeManager

@export var drill_duration: float = 60.0
var time_remaining: float = 60.0
var is_drill_active: bool = false

var score: int = 0
var shots_fired: int = 0
var shots_hit: int = 0

var combo_multiplier: float = 1.0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 2.5
const MAX_COMBO: float = 5.0
const COMBO_STEP: float = 0.25

func _init() -> void:
	instance = self

func _ready() -> void:
	time_remaining = drill_duration
	reset_drill()

func _process(delta: float) -> void:
	# Drill countdown
	if is_drill_active:
		time_remaining -= delta
		timer_changed.emit(maxf(0.0, time_remaining), true)
		if time_remaining <= 0.0:
			_complete_drill()
	
	# Combo decay countdown
	if combo_timer > 0.0:
		combo_timer -= delta
		var progress := clampf(combo_timer / COMBO_WINDOW, 0.0, 1.0)
		combo_changed.emit(combo_multiplier, progress)
		if combo_timer <= 0.0:
			combo_multiplier = 1.0
			combo_changed.emit(1.0, 0.0)

func start_drill(duration: float = 60.0) -> void:
	drill_duration = duration
	time_remaining = duration
	is_drill_active = true
	score = 0
	shots_fired = 0
	shots_hit = 0
	combo_multiplier = 1.0
	combo_timer = 0.0
	
	score_changed.emit(score, 0, combo_multiplier)
	combo_changed.emit(1.0, 0.0)
	accuracy_changed.emit(100.0, 0, 0)
	timer_changed.emit(time_remaining, true)
	print("[Challenge] Tactical Drill Started! Duration: %.1fs" % duration)

func reset_drill() -> void:
	is_drill_active = false
	time_remaining = drill_duration
	score = 0
	shots_fired = 0
	shots_hit = 0
	combo_multiplier = 1.0
	combo_timer = 0.0
	score_changed.emit(score, 0, combo_multiplier)
	combo_changed.emit(1.0, 0.0)
	accuracy_changed.emit(0.0, 0, 0)
	timer_changed.emit(time_remaining, false)

func record_shot() -> void:
	shots_fired += 1
	var acc: float = (float(shots_hit) / float(shots_fired)) * 100.0 if shots_fired > 0 else 0.0
	accuracy_changed.emit(acc, shots_hit, shots_fired)

func record_hit(base_points: int = 100, is_crit: bool = false) -> void:
	shots_hit += 1
	
	# Increment combo
	combo_multiplier = minf(MAX_COMBO, combo_multiplier + (0.5 if is_crit else COMBO_STEP))
	combo_timer = COMBO_WINDOW
	
	var earned: int = int(float(base_points) * combo_multiplier)
	score += earned
	
	var acc: float = (float(shots_hit) / float(shots_fired)) * 100.0 if shots_fired > 0 else 100.0
	
	score_changed.emit(score, earned, combo_multiplier)
	combo_changed.emit(combo_multiplier, 1.0)
	accuracy_changed.emit(acc, shots_hit, shots_fired)
	print("[Challenge] HIT! +%d pts (x%.2f combo) | Total: %d" % [earned, combo_multiplier, score])

func _complete_drill() -> void:
	is_drill_active = false
	time_remaining = 0.0
	timer_changed.emit(0.0, false)
	
	var acc: float = (float(shots_hit) / float(shots_fired)) * 100.0 if shots_fired > 0 else 0.0
	var rank: String = _calculate_rank(score, acc)
	drill_finished.emit(score, acc, shots_hit, rank)
	print("[Challenge] Drill Completed! Score: %d | Accuracy: %.1f%% | Rank: %s" % [score, acc, rank])

func _calculate_rank(final_score: int, final_acc: float) -> String:
	if final_score >= 15000 and final_acc >= 75.0:
		return "S"
	elif final_score >= 10000 and final_acc >= 60.0:
		return "A"
	elif final_score >= 6000:
		return "B"
	elif final_score >= 3000:
		return "C"
	else:
		return "D"

# Static wrappers for global access
static func on_shot_fired() -> void:
	if instance:
		instance.record_shot()

static func on_target_hit(base_points: int = 100, is_crit: bool = false) -> void:
	if instance:
		instance.record_hit(base_points, is_crit)

static func toggle_drill() -> void:
	if instance:
		if instance.is_drill_active:
			instance.reset_drill()
		else:
			instance.start_drill(60.0)

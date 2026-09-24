class_name PlayerHUD
extends Control

## Tactical HUD for Broken Horizon
## Renders dynamic crosshair, weapon status, and hit markers.

const ChallengeManager = preload("res://scripts/challenge_manager.gd")

@onready var reticle: Control = $Reticle
@onready var weapon_label: Label = $WeaponPanel/WeaponLabel
@onready var ammo_label: Label = $WeaponPanel/AmmoLabel
@onready var status_label: Label = $WeaponPanel/StatusLabel
@onready var hit_marker: Control = $HitMarker
@onready var hurt_flash: ColorRect = $HurtFlash
@onready var health_label: Label = $HealthPanel/HealthLabel
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar

# Challenge HUD nodes
@onready var timer_label: Label = $ChallengePanel/TimerLabel
@onready var score_label: Label = $ChallengePanel/ScoreLabel
@onready var combo_label: Label = $ChallengePanel/ComboHBox/ComboLabel
@onready var combo_bar: ProgressBar = $ChallengePanel/ComboHBox/ComboBar
@onready var accuracy_label: Label = $ChallengePanel/StatsHBox/AccuracyLabel
@onready var hits_label: Label = $ChallengePanel/StatsHBox/HitsLabel
@onready var summary_card: PanelContainer = $DrillSummaryCard
@onready var summary_rank: Label = $DrillSummaryCard/VBox/RankLabel
@onready var summary_score: Label = $DrillSummaryCard/VBox/FinalScoreLabel
@onready var summary_accuracy: Label = $DrillSummaryCard/VBox/FinalAccuracyLabel

var crosshair_spread: float = 0.0
var target_spread: float = 0.0
var is_aiming: bool = false

func _ready() -> void:
	if hit_marker:
		hit_marker.modulate.a = 0.0
	if hurt_flash:
		hurt_flash.modulate.a = 0.0
	if summary_card:
		summary_card.visible = false
	update_weapon_info("Tactical Pistol", "Holstered")
	set_aiming(false)
	update_health(100, 100)
	_setup_challenge_manager()

func _setup_challenge_manager() -> void:
	# Connect to challenge manager if available
	var cm = ChallengeManager.instance
	if not cm:
		# Search parent tree
		var player = get_parent().get_parent() if get_parent() else null
		if player and player.has_node("ChallengeManager"):
			cm = player.get_node("ChallengeManager")
	
	if cm:
		cm.timer_changed.connect(_on_timer_changed)
		cm.score_changed.connect(_on_score_changed)
		cm.combo_changed.connect(_on_combo_changed)
		cm.accuracy_changed.connect(_on_accuracy_changed)
		cm.drill_finished.connect(_on_drill_finished)

func _on_timer_changed(time_left: float, is_active: bool) -> void:
	if not timer_label:
		return
	if is_active:
		if summary_card:
			summary_card.visible = false
		timer_label.text = "DRILL: %.1fs" % time_left
		if time_left <= 10.0:
			timer_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			timer_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		timer_label.text = "DRILL: [T] TO START"
		timer_label.modulate = Color(0.6, 0.9, 0.6)

func _on_score_changed(new_score: int, delta: int, combo: float) -> void:
	if score_label:
		score_label.text = "SCORE: %06d" % new_score

func _on_combo_changed(combo: float, progress: float) -> void:
	if combo_label:
		combo_label.text = "x%.2f COMBO" % combo
		if combo >= 3.0:
			combo_label.modulate = Color(1.0, 0.25, 0.25)
		elif combo >= 2.0:
			combo_label.modulate = Color(1.0, 0.85, 0.1)
		else:
			combo_label.modulate = Color(0.2, 0.9, 1.0)
	if combo_bar:
		combo_bar.value = progress

func _on_accuracy_changed(acc: float, hits: int, shots: int) -> void:
	if accuracy_label:
		accuracy_label.text = "ACC: %.1f%%  |" % acc
	if hits_label:
		hits_label.text = " HITS: %d / %d" % [hits, shots]

func _on_drill_finished(final_score: int, acc: float, hits: int, rank: String) -> void:
	if not summary_card:
		return
	summary_card.visible = true
	if summary_rank:
		summary_rank.text = "%s RANK" % rank
		match rank:
			"S": summary_rank.modulate = Color(1.0, 0.85, 0.1)
			"A": summary_rank.modulate = Color(0.2, 0.9, 0.4)
			"B": summary_rank.modulate = Color(0.2, 0.8, 1.0)
			"C": summary_rank.modulate = Color(0.9, 0.6, 0.2)
			_: summary_rank.modulate = Color(0.7, 0.7, 0.7)
	if summary_score:
		summary_score.text = "FINAL SCORE: %d" % final_score
	if summary_accuracy:
		summary_accuracy.text = "ACCURACY: %.1f%% (%d HITS)" % [acc, hits]

func _process(delta: float) -> void:
	# Smoothly return spread to baseline
	crosshair_spread = lerpf(crosshair_spread, target_spread, 15.0 * delta)
	if reticle:
		reticle.queue_redraw()
	
	if hit_marker and hit_marker.modulate.a > 0.0:
		hit_marker.modulate.a = move_toward(hit_marker.modulate.a, 0.0, 4.0 * delta)

	if hurt_flash and hurt_flash.modulate.a > 0.0:
		hurt_flash.modulate.a = move_toward(hurt_flash.modulate.a, 0.0, 2.5 * delta)

func set_aiming(aiming: bool) -> void:
	is_aiming = aiming
	target_spread = 6.0 if aiming else 16.0
	if reticle:
		reticle.modulate.a = 1.0 if aiming else 0.4

func add_recoil_kick() -> void:
	crosshair_spread = 28.0

func trigger_hit_marker() -> void:
	if hit_marker:
		hit_marker.modulate.a = 1.0

func trigger_hurt_flash() -> void:
	if hurt_flash:
		hurt_flash.modulate.a = 0.8

func update_health(current: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = float(max_hp)
		health_bar.value = float(current)
	if health_label:
		health_label.text = "VITALS: %d / %d" % [current, max_hp]
		var ratio := float(current) / float(max_hp) if max_hp > 0 else 0.0
		if ratio > 0.5:
			health_label.modulate = Color(0.3, 0.9, 0.4)
		elif ratio > 0.25:
			health_label.modulate = Color(0.9, 0.7, 0.2)
		else:
			health_label.modulate = Color(0.95, 0.2, 0.2)

func update_weapon_info(weapon_name: String, state: String) -> void:
	if weapon_label:
		weapon_label.text = weapon_name.to_upper()
	if status_label:
		status_label.text = state.to_upper()
		status_label.modulate = Color(0.2, 0.9, 0.3) if state == "drawn" else Color(0.7, 0.7, 0.7)

func update_ammo(mag: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [mag, reserve]
		if mag <= 3:
			ammo_label.modulate = Color(1.0, 0.2, 0.2)
		elif mag <= 6:
			ammo_label.modulate = Color(1.0, 0.7, 0.2)
		else:
			ammo_label.modulate = Color(1.0, 0.85, 0.2)

func prompt_reload() -> void:
	if ammo_label:
		ammo_label.text = "RELOAD! [R]"
		ammo_label.modulate = Color(1.0, 0.1, 0.1)

func show_reloading() -> void:
	if ammo_label:
		ammo_label.text = "RELOADING..."
		ammo_label.modulate = Color(0.3, 0.8, 1.0)


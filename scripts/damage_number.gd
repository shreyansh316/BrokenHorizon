class_name DamageNumber
extends Label3D

## 3D floating damage text that rises, scales, and fades out.

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.8
var timer: float = 0.0

static func spawn(parent: Node, pos: Vector3, damage: int, is_crit: bool = false) -> Label3D:
	var script_res: Script = load("res://scripts/damage_number.gd")
	var label: Label3D = script_res.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.007
	label.text = ("CRIT! " if is_crit else "") + str(damage)
	
	if is_crit:
		label.modulate = Color(1.0, 0.25, 0.1, 1.0)
		label.font_size = 38
		label.outline_size = 8
		label.outline_modulate = Color(0.3, 0.05, 0.0, 1.0)
	else:
		label.modulate = Color(1.0, 0.85, 0.2, 1.0)
		label.font_size = 28
		label.outline_size = 6
		label.outline_modulate = Color(0.2, 0.15, 0.0, 1.0)
	
	label.position = pos + Vector3(randf_range(-0.1, 0.1), 0.1, randf_range(-0.1, 0.1))
	label.set("velocity", Vector3(randf_range(-0.3, 0.3), randf_range(1.2, 1.8), randf_range(-0.3, 0.3)))
	
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	timer += delta
	position += velocity * delta
	velocity.y -= 1.0 * delta # Slight downward gravity on floater
	
	# Scale punch and fade out
	var t := timer / lifetime
	if t < 0.2:
		scale = Vector3.ONE * (1.0 + (t / 0.2) * 0.3)
	else:
		scale = Vector3.ONE * (1.3 - (t - 0.2) * 0.3)
		modulate.a = clampf(1.0 - (t - 0.3) / 0.7, 0.0, 1.0)
		outline_modulate.a = modulate.a
	
	if timer >= lifetime:
		queue_free()

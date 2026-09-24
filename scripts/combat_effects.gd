class_name CombatEffects
extends Node

## Spawns visual combat effects: muzzle flash, bullet trails, and impact sparks.

static func create_muzzle_flash(parent: Node3D, pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.4)
	flash.light_energy = 5.0
	flash.omni_range = 3.0
	flash.position = pos
	parent.add_child(flash)
	
	# Muzzle star mesh
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	sphere.material = mat
	mesh_inst.mesh = sphere
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	
	# Auto remove after 0.05 seconds
	var tree := parent.get_tree()
	if tree:
		var timer := tree.create_timer(0.05)
		timer.timeout.connect(func():
			if is_instance_valid(flash): flash.queue_free()
			if is_instance_valid(mesh_inst): mesh_inst.queue_free()
		)

static func create_hit_spark(parent: Node3D, hit_point: Vector3, hit_normal: Vector3) -> void:
	var spark_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.2)
	sphere.material = mat
	spark_inst.mesh = sphere
	spark_inst.position = hit_point + hit_normal * 0.02
	parent.add_child(spark_inst)
	
	# Light burst
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 3.0
	light.omni_range = 1.5
	light.position = spark_inst.position
	parent.add_child(light)
	
	var tree := parent.get_tree()
	if tree:
		var timer := tree.create_timer(0.08)
		timer.timeout.connect(func():
			if is_instance_valid(spark_inst): spark_inst.queue_free()
			if is_instance_valid(light): light.queue_free()
		)

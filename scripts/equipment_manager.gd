class_name EquipmentManager
extends Node

## Manages modular equipment attachment sockets (weapons, holsters, backpacks)
## attached to the character skeleton via BoneAttachment3D nodes.

signal equipment_changed(slot_name: String, item: Node3D)

const PISTOL_SCENE: PackedScene = preload("res://assets/models/equipment/tactical_pistol.glb")
const HOLSTER_SCENE: PackedScene = preload("res://assets/models/equipment/holster.glb")
const BACKPACK_SCENE: PackedScene = preload("res://assets/models/equipment/tactical_backpack.glb")

@export var skeleton_path: NodePath = ^"../character/BH_Protagonist_Armature/Skeleton3D"

var skeleton: Skeleton3D
var sockets: Dictionary = {}
var equipped_items: Dictionary = {}

# Default socket offset transforms
var socket_configs: Dictionary = {
	"hand_r": {
		"bone": "RightHand",
		"offset": Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(90), deg_to_rad(0), deg_to_rad(-90))),
			Vector3(0.01, -0.06, 0.04)
		)
	},
	"hand_l": {
		"bone": "LeftHand",
		"offset": Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(90), deg_to_rad(0), deg_to_rad(90))),
			Vector3(-0.01, -0.06, 0.04)
		)
	},
	"holster_r": {
		"bone": "Hips",
		"offset": Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(5), deg_to_rad(0), deg_to_rad(-8))),
			Vector3(-0.21, -0.08, 0.02)
		)
	},
	"backpack": {
		"bone": "Spine2",
		"offset": Transform3D(
			Basis.from_euler(Vector3(0, deg_to_rad(180), 0)),
			Vector3(0, 0.04, -0.15)
		)
	},
	"back": {
		"bone": "Spine2",
		"offset": Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(15), deg_to_rad(45), deg_to_rad(135))),
			Vector3(0.12, 0.05, -0.18)
		)
	}
}

func _ready() -> void:
	skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if not skeleton:
		push_warning("EquipmentManager: Skeleton3D not found at path: %s" % str(skeleton_path))
		return
	
	_initialize_sockets()
	_equip_default_loadout()

func _initialize_sockets() -> void:
	for slot_name in socket_configs:
		var cfg = socket_configs[slot_name]
		var bone_name: String = cfg["bone"]
		var bone_idx: int = skeleton.find_bone(bone_name)
		
		if bone_idx == -1:
			push_warning("EquipmentManager: Bone '%s' not found for socket '%s'" % [bone_name, slot_name])
			continue
		
		var attachment := BoneAttachment3D.new()
		attachment.name = "Socket_" + slot_name
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		
		# Child mount point with default offset
		var mount := Marker3D.new()
		mount.name = "MountPoint"
		mount.transform = cfg["offset"]
		attachment.add_child(mount)
		
		sockets[slot_name] = mount

func _equip_default_loadout() -> void:
	# Default starter gear: Holstered pistol + Tactical Backpack
	equip_item("holster_r", HOLSTER_SCENE)
	
	# Spawn pistol inside the holster initially
	var pistol = PISTOL_SCENE.instantiate() as Node3D
	# Offset to sit nicely in holster
	pistol.transform = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(90), 0, 0)),
		Vector3(0, 0.02, 0.02)
	)
	var holster_mount = get_socket("holster_r")
	if holster_mount:
		holster_mount.add_child(pistol)
		equipped_items["pistol_instance"] = pistol
		equipped_items["weapon_state"] = "holstered"
	
	# Equip tactical backpack
	equip_item("backpack", BACKPACK_SCENE)

func equip_item(slot_name: String, item_scene: PackedScene, custom_offset: Transform3D = Transform3D.IDENTITY) -> Node3D:
	if not sockets.has(slot_name):
		push_warning("EquipmentManager: Socket '%s' does not exist." % slot_name)
		return null
	
	unequip_item(slot_name)
	
	var item_inst = item_scene.instantiate() as Node3D
	if custom_offset != Transform3D.IDENTITY:
		item_inst.transform = custom_offset
	
	var mount: Marker3D = sockets[slot_name]
	mount.add_child(item_inst)
	equipped_items[slot_name] = item_inst
	
	emit_signal("equipment_changed", slot_name, item_inst)
	return item_inst

func unequip_item(slot_name: String) -> void:
	if equipped_items.has(slot_name):
		var old_item = equipped_items[slot_name]
		if is_instance_valid(old_item):
			old_item.queue_free()
		equipped_items.erase(slot_name)
		emit_signal("equipment_changed", slot_name, null)

func get_socket(slot_name: String) -> Marker3D:
	return sockets.get(slot_name, null)

func has_item(slot_name: String) -> bool:
	return equipped_items.has(slot_name) and is_instance_valid(equipped_items[slot_name])

func get_item(slot_name: String) -> Node3D:
	return equipped_items.get(slot_name, null)

## Toggle draw / holster weapon
func toggle_weapon() -> void:
	var pistol: Node3D = equipped_items.get("pistol_instance", null)
	if not is_instance_valid(pistol):
		return
	
	var current_state: String = equipped_items.get("weapon_state", "holstered")
	
	if current_state == "holstered":
		# Draw weapon: move from holster mount to hand_r mount
		var hand_mount = get_socket("hand_r")
		if hand_mount:
			pistol.get_parent().remove_child(pistol)
			hand_mount.add_child(pistol)
			# Align pistol grip with palm
			pistol.transform = Transform3D(
				Basis.from_euler(Vector3(0, 0, deg_to_rad(90))),
				Vector3(0, 0, 0)
			)
			equipped_items["weapon_state"] = "drawn"
			print("[Equipment] Sidearm DRAWN to Right Hand")
	else:
		# Holster weapon: move from hand_r mount back to holster mount
		var holster_mount = get_socket("holster_r")
		if holster_mount:
			pistol.get_parent().remove_child(pistol)
			holster_mount.add_child(pistol)
			pistol.transform = Transform3D(
				Basis.from_euler(Vector3(deg_to_rad(90), 0, 0)),
				Vector3(0, 0.02, 0.02)
			)
			equipped_items["weapon_state"] = "holstered"
			print("[Equipment] Sidearm HOLSTERED")

## Toggle tactical backpack
func toggle_backpack() -> void:
	if has_item("backpack"):
		unequip_item("backpack")
		print("[Equipment] Backpack UNEQUIPPED")
	else:
		equip_item("backpack", BACKPACK_SCENE)
		print("[Equipment] Backpack EQUIPPED")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	
	if event.keycode == KEY_1:
		toggle_weapon()
	elif event.keycode == KEY_2:
		toggle_backpack()

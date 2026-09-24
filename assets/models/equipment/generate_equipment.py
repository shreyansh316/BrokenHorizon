"""
Generate tactical equipment models (Pistol, Holster, Backpack) for Broken Horizon.
Exports game-ready .glb files for modular attachment sockets.
"""

import bpy
import bmesh
import math
from mathutils import Vector, Euler

EQUIP_DIR = r"e:\GameDev\BrokenHorizon\assets\models\equipment"

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_pbr_material(name, base_color, metallic, roughness):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = base_color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
    return mat

def generate_tactical_pistol():
    reset_scene()
    
    # 1. Slide
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.04, 0.05))
    slide = bpy.context.active_object
    slide.name = "Pistol_Slide"
    slide.scale = (0.026, 0.18, 0.035)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # 2. Barrel / muzzle port
    bpy.ops.mesh.primitive_cylinder_add(radius=0.007, depth=0.18, location=(0, 0.04, 0.055))
    barrel = bpy.context.active_object
    barrel.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(rotation=True, location=False)
    
    # 3. Grip (angled back ~15 degrees)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.015, -0.02))
    grip = bpy.context.active_object
    grip.name = "Pistol_Grip"
    grip.scale = (0.024, 0.045, 0.11)
    grip.rotation_euler = (math.radians(-16), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True, location=False)
    
    # 4. Trigger guard
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.025, 0.01))
    guard = bpy.context.active_object
    guard.name = "Pistol_TriggerGuard"
    guard.scale = (0.015, 0.04, 0.03)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # 5. Sights (Front & Rear)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.12, 0.072))
    f_sight = bpy.context.active_object
    f_sight.scale = (0.006, 0.01, 0.008)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.045, 0.072))
    r_sight = bpy.context.active_object
    r_sight.scale = (0.014, 0.01, 0.008)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # Join parts into single mesh
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    pistol = bpy.context.active_object
    pistol.name = "TacticalPistol"
    
    # Position origin at center of the grip hand-hold
    pistol.location = (0, 0, 0)
    
    mat = create_pbr_material("Mat_Pistol", (0.12, 0.13, 0.15, 1.0), metallic=0.85, roughness=0.35)
    pistol.data.materials.append(mat)
    
    # Export
    out_path = f"{EQUIP_DIR}\\tactical_pistol.glb"
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported pistol to:", out_path)

def generate_tactical_holster():
    reset_scene()
    
    # Kydex holster sleeve
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.01, -0.01))
    holster = bpy.context.active_object
    holster.name = "TacticalHolster"
    holster.scale = (0.04, 0.08, 0.14)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # Belt attachment loop/paddle
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.025, 0.0, 0.04))
    paddle = bpy.context.active_object
    paddle.scale = (0.008, 0.06, 0.08)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    holster_obj = bpy.context.active_object
    holster_obj.name = "Holster"
    
    mat = create_pbr_material("Mat_Holster", (0.08, 0.08, 0.09, 1.0), metallic=0.1, roughness=0.6)
    holster_obj.data.materials.append(mat)
    
    out_path = f"{EQUIP_DIR}\\holster.glb"
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported holster to:", out_path)

def generate_tactical_backpack():
    reset_scene()
    
    # 1. Main compartment (origin at back contact surface Y = 0)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.13, 0.0))
    main_pack = bpy.context.active_object
    main_pack.name = "Backpack_Main"
    main_pack.scale = (0.28, 0.18, 0.40)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # 2. Outer utility pocket
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.24, -0.04))
    outer_pocket = bpy.context.active_object
    outer_pocket.scale = (0.22, 0.09, 0.24)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # 3. Side utility pouch Left
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.16, 0.13, -0.03))
    side_l = bpy.context.active_object
    side_l.scale = (0.07, 0.12, 0.20)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # 4. Side utility pouch Right
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.16, 0.13, -0.03))
    side_r = bpy.context.active_object
    side_r.scale = (0.07, 0.12, 0.20)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # 5. Bottom bedroll / roll mat
    bpy.ops.mesh.primitive_cylinder_add(radius=0.065, depth=0.34, location=(0, 0.14, -0.23))
    bedroll = bpy.context.active_object
    bedroll.rotation_euler = (0, math.radians(90), 0)
    bpy.ops.object.transform_apply(rotation=True, location=False)
    
    # 6. Top grab handle
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.08, 0.22))
    handle = bpy.context.active_object
    handle.scale = (0.12, 0.02, 0.04)
    bpy.ops.object.transform_apply(scale=True, location=False)
    
    # Join into one model
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.join()
    backpack = bpy.context.active_object
    backpack.name = "TacticalBackpack"
    
    mat = create_pbr_material("Mat_Backpack", (0.18, 0.20, 0.15, 1.0), metallic=0.05, roughness=0.75)
    backpack.data.materials.append(mat)
    
    out_path = f"{EQUIP_DIR}\\tactical_backpack.glb"
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported backpack to:", out_path)

if __name__ == "__main__":
    generate_tactical_pistol()
    generate_tactical_holster()
    generate_tactical_backpack()
    print("ALL EQUIPMENT GENERATION COMPLETE!")

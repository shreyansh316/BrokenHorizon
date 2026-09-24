import bpy

# Test multi-action creation and glTF export in Blender 5.2
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"E:\GameDev\BrokenHorizon\assets\models\characters\character.glb")

arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
bpy.context.view_layer.objects.active = arm

if not arm.animation_data:
    arm.animation_data_create()

# Clear existing tracks
for track in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(track)

test_names = ["BH_Test_Idle", "BH_Test_Walk"]
for name in test_names:
    act = bpy.data.actions.new(name=name)
    act.use_fake_user = True
    arm.animation_data.action = act
    
    pbone = arm.pose.bones["Spine"]
    pbone.rotation_mode = 'XYZ'
    pbone.rotation_euler = (0, 0, 0)
    pbone.keyframe_insert(data_path="rotation_euler", frame=1)
    pbone.rotation_euler = (0.1, 0, 0)
    pbone.keyframe_insert(data_path="rotation_euler", frame=30)
    
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)

out_test = r"E:\GameDev\BrokenHorizon\character_source\test_out.glb"
bpy.ops.export_scene.gltf(
    filepath=out_test,
    export_format='GLB',
    export_animations=True,
    export_nla_strips=True
)

print("Export completed successfully!")

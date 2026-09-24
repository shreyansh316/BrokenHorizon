"""
Broken Horizon — Complete Third-Person Character Animation System Generator
Generates the complete 70+ professional game-ready animation library for the original protagonist.
Targets: Godot 4.3.1 (glTF 2.0 / GLB), Android-first optimized.
"""

import bpy
import math
from math import radians, sin, cos, exp
import mathutils
from mathutils import Euler, Quaternion, Vector

# Path constants
SOURCE_GLB = r"E:\GameDev\BrokenHorizon\assets\models\characters\character.glb"
OUTPUT_GLB = r"E:\GameDev\BrokenHorizon\assets\models\characters\character.glb"
BACKUP_GLB = r"E:\GameDev\BrokenHorizon\character_source\character_backup_locomotion.glb"
BLEND_FILE = r"E:\GameDev\BrokenHorizon\character_source\BH_Protagonist_FullAnimations.blend"

def init_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SOURCE_GLB)
    
    armature = None
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            armature = obj
            break
            
    if not armature:
        raise RuntimeError("Armature not found in character.glb!")
        
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    
    if not armature.animation_data:
        armature.animation_data_create()
        
    # Clear existing NLA tracks
    for track in list(armature.animation_data.nla_tracks):
        armature.animation_data.nla_tracks.remove(track)
        
    # Set all pose bones to Quaternion rotation mode
    for pbone in armature.pose.bones:
        pbone.rotation_mode = 'QUATERNION'
        pbone.rotation_quaternion = (1, 0, 0, 0)
        pbone.location = (0, 0, 0)
        pbone.scale = (1, 1, 1)
        
    return armature

class AnimBuilder:
    def __init__(self, armature):
        self.armature = armature
        self.actions = []

    def reset_pose(self):
        for pbone in self.armature.pose.bones:
            pbone.rotation_quaternion = (1, 0, 0, 0)
            pbone.location = (0, 0, 0)
            pbone.scale = (1, 1, 1)

    def new_action(self, name, length_frames):
        self.reset_pose()
        action = bpy.data.actions.new(name=name)
        action.use_fake_user = True
        self.armature.animation_data.action = action
        return action

    def key_rot(self, bone_name, frame, rx=0.0, ry=0.0, rz=0.0):
        if bone_name not in self.armature.pose.bones:
            return
        pbone = self.armature.pose.bones[bone_name]
        q = Euler((radians(rx), radians(ry), radians(rz)), 'XYZ').to_quaternion()
        pbone.rotation_quaternion = q
        pbone.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    def key_loc(self, bone_name, frame, lx=0.0, ly=0.0, lz=0.0):
        if bone_name not in self.armature.pose.bones:
            return
        pbone = self.armature.pose.bones[bone_name]
        pbone.location = Vector((lx, ly, lz))
        pbone.keyframe_insert(data_path="location", frame=frame)

    def push_to_nla(self, action):
        track = self.armature.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)
        self.actions.append(action.name)
        print("  [Action Created] %s (Frames: %d)" % (action.name, int(action.frame_range[1])))

    # ==========================================
    # 1. IDLE & VARIATIONS
    # ==========================================
    def build_idle(self):
        # BH_Idle (60f loop, breathing, subtle weight shift)
        act = self.new_action("BH_Idle", 60)
        for f in range(1, 61):
            t = (f - 1) / 59.0
            breath = sin(t * math.tau)
            self.key_rot("Spine", f, rx=breath * 1.5)
            self.key_rot("Spine1", f, rx=breath * 1.8)
            self.key_rot("Spine2", f, rx=breath * 1.2)
            self.key_rot("LeftUpperArm", f, rx=10.0 + breath * 1.0, rz=-8.0)
            self.key_rot("RightUpperArm", f, rx=10.0 + breath * 1.0, rz=8.0)
            self.key_rot("LeftLowerArm", f, rx=-20.0)
            self.key_rot("RightLowerArm", f, rx=-20.0)
            self.key_loc("Hips", f, ly=breath * 0.008)
        self.push_to_nla(act)

        # BH_Idle_Var01 (90f: shift weight to right hip, look left, roll shoulder, return)
        act = self.new_action("BH_Idle_Var01", 90)
        for f in range(1, 91):
            t = (f - 1) / 89.0
            # Weight shift envelope
            shift = sin(t * math.pi)
            look_l = sin(t * math.pi) * 22.0
            self.key_rot("Hips", f, rz=-shift * 4.0, ry=shift * 3.0)
            self.key_loc("Hips", f, lx=shift * 0.04, ly=-shift * 0.015)
            self.key_rot("Spine", f, rz=shift * 3.0)
            self.key_rot("Neck", f, ry=look_l * 0.6)
            self.key_rot("Head", f, ry=look_l * 0.8, rx=shift * 3.0)
            self.key_rot("LeftUpperArm", f, rx=10.0 + shift * 6.0, rz=-8.0 - shift * 4.0)
            self.key_rot("RightUpperArm", f, rx=10.0 - shift * 4.0, rz=8.0)
            self.key_rot("LeftLowerArm", f, rx=-20.0)
            self.key_rot("RightLowerArm", f, rx=-20.0)
            self.key_rot("LeftUpperLeg", f, rz=shift * 3.0)
            self.key_rot("RightUpperLeg", f, rz=-shift * 2.0)
        self.push_to_nla(act)

        # BH_Idle_Var02 (90f: tactical watch scan, horizon scan, reset)
        act = self.new_action("BH_Idle_Var02", 90)
        for f in range(1, 91):
            t = (f - 1) / 89.0
            env = sin(t * math.pi)
            # Left arm raises to check watch between frames 20 and 70
            arm_raise = sin(min(1.0, max(0.0, (f - 20) / 50.0)) * math.pi)
            head_scan = sin(t * math.tau) * 18.0
            self.key_rot("LeftUpperArm", f, rx=10.0 + arm_raise * 45.0, ry=arm_raise * 20.0, rz=-8.0 + arm_raise * 30.0)
            self.key_rot("LeftLowerArm", f, rx=-20.0 - arm_raise * 55.0, ry=arm_raise * 40.0)
            self.key_rot("LeftHand", f, rx=arm_raise * 20.0, ry=-arm_raise * 25.0)
            self.key_rot("Head", f, ry=head_scan, rx=arm_raise * 8.0)
            self.key_rot("Spine2", f, ry=head_scan * 0.3)
            self.key_rot("RightUpperArm", f, rx=10.0, rz=8.0)
            self.key_rot("RightLowerArm", f, rx=-20.0)
        self.push_to_nla(act)

        # BH_Unarmed_Idle (60f: alert neutral ready stance)
        act = self.new_action("BH_Unarmed_Idle", 60)
        for f in range(1, 61):
            t = (f - 1) / 59.0
            sway = sin(t * math.tau)
            self.key_rot("Hips", f, rz=sway * 1.0)
            self.key_rot("Spine", f, rx=2.0 + sway * 1.2)
            self.key_rot("Spine1", f, rx=2.0 + sway * 1.5)
            self.key_rot("LeftUpperArm", f, rx=14.0 + sway * 1.5, rz=-12.0)
            self.key_rot("RightUpperArm", f, rx=14.0 + sway * 1.5, rz=12.0)
            self.key_rot("LeftLowerArm", f, rx=-28.0)
            self.key_rot("RightLowerArm", f, rx=-28.0)
        self.push_to_nla(act)

    # ==========================================
    # 2. LOCOMOTION (WALK, JOG, RUN, SPRINT, TURNS)
    # ==========================================
    def build_locomotion(self):
        # Helper for cyclic bipedal gait
        def apply_gait(act, f, t, stride_deg, knee_flex, arm_swing, forward_lean=0.0, bounce=0.04, hip_twist=6.0, hip_tilt=3.0, dir_angle=0.0):
            phase = t * math.tau
            cos_p = cos(phase)
            sin_p = sin(phase)

            # Pelvic oscillation
            self.key_rot("Hips", f, rx=forward_lean, ry=sin_p * hip_twist + dir_angle, rz=cos_p * hip_tilt)
            self.key_loc("Hips", f, ly=-abs(sin_p) * bounce, lx=cos_p * 0.015)

            # Spine counter-rotation
            self.key_rot("Spine", f, rx=-forward_lean * 0.4, ry=-sin_p * (hip_twist * 0.6))
            self.key_rot("Spine1", f, ry=-sin_p * (hip_twist * 0.4))
            self.key_rot("Spine2", f, ry=-sin_p * (hip_twist * 0.3))

            # Legs (in antiphase)
            # Left leg
            l_thigh = sin_p * stride_deg
            l_knee = max(0.0, -sin_p * knee_flex)
            l_foot = sin_p * 12.0
            self.key_rot("LeftUpperLeg", f, rx=l_thigh, rz=-cos_p * 2.0)
            self.key_rot("LeftLowerLeg", f, rx=-l_knee)
            self.key_rot("LeftFoot", f, rx=l_foot)

            # Right leg
            r_thigh = -sin_p * stride_deg
            r_knee = max(0.0, sin_p * knee_flex)
            r_foot = -sin_p * 12.0
            self.key_rot("RightUpperLeg", f, rx=r_thigh, rz=cos_p * 2.0)
            self.key_rot("RightLowerLeg", f, rx=-r_knee)
            self.key_rot("RightFoot", f, rx=r_foot)

            # Reciprocal Arm Swing (left arm swings with right leg)
            self.key_rot("LeftUpperArm", f, rx=-sin_p * arm_swing + 10.0, rz=-10.0)
            self.key_rot("LeftLowerArm", f, rx=-25.0 - max(0.0, -sin_p * (arm_swing * 0.6)))
            self.key_rot("RightUpperArm", f, rx=sin_p * arm_swing + 10.0, rz=10.0)
            self.key_rot("RightLowerArm", f, rx=-25.0 - max(0.0, sin_p * (arm_swing * 0.6)))

        # BH_Walk_F (30f)
        act = self.new_action("BH_Walk_F", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            apply_gait(act, f, t, stride_deg=26.0, knee_flex=42.0, arm_swing=22.0, forward_lean=3.0, bounce=0.035)
        self.push_to_nla(act)

        # BH_Walk_B (30f)
        act = self.new_action("BH_Walk_B", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            apply_gait(act, f, t, stride_deg=-20.0, knee_flex=32.0, arm_swing=-14.0, forward_lean=-2.0, bounce=0.025)
        self.push_to_nla(act)

        # BH_Walk_L (30f)
        act = self.new_action("BH_Walk_L", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            p = t * math.tau
            s = sin(p)
            c = cos(p)
            self.key_rot("Hips", f, rz=s * 6.0, ry=-c * 4.0)
            self.key_loc("Hips", f, lx=-s * 0.04, ly=-abs(s) * 0.02)
            self.key_rot("LeftUpperLeg", f, rz=s * 18.0, rx=c * 8.0)
            self.key_rot("RightUpperLeg", f, rz=s * 18.0, rx=-c * 8.0)
            self.key_rot("LeftLowerLeg", f, rx=-max(0.0, s * 25.0))
            self.key_rot("RightLowerLeg", f, rx=-max(0.0, -s * 25.0))
            self.key_rot("LeftUpperArm", f, rz=-15.0 - s * 8.0)
            self.key_rot("RightUpperArm", f, rz=15.0 - s * 8.0)
        self.push_to_nla(act)

        # BH_Walk_R (30f)
        act = self.new_action("BH_Walk_R", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            p = t * math.tau
            s = -sin(p)
            c = cos(p)
            self.key_rot("Hips", f, rz=s * 6.0, ry=-c * 4.0)
            self.key_loc("Hips", f, lx=-s * 0.04, ly=-abs(s) * 0.02)
            self.key_rot("LeftUpperLeg", f, rz=s * 18.0, rx=c * 8.0)
            self.key_rot("RightUpperLeg", f, rz=s * 18.0, rx=-c * 8.0)
            self.key_rot("LeftLowerLeg", f, rx=-max(0.0, s * 25.0))
            self.key_rot("RightLowerLeg", f, rx=-max(0.0, -s * 25.0))
            self.key_rot("LeftUpperArm", f, rz=-15.0 - s * 8.0)
            self.key_rot("RightUpperArm", f, rz=15.0 - s * 8.0)
        self.push_to_nla(act)

        # Diagonals for 8-Way BlendSpace2D
        diagonals = [
            ("BH_Walk_FL", 24.0, -25.0),
            ("BH_Walk_FR", 24.0, 25.0),
            ("BH_Walk_BL", -18.0, -25.0),
            ("BH_Walk_BR", -18.0, 25.0),
        ]
        for name, stride, angle in diagonals:
            act = self.new_action(name, 30)
            for f in range(1, 31):
                t = (f - 1) / 29.0
                apply_gait(act, f, t, stride_deg=stride, knee_flex=38.0, arm_swing=18.0, forward_lean=2.0, dir_angle=angle)
            self.push_to_nla(act)

        # BH_Jog (24f)
        act = self.new_action("BH_Jog", 24)
        for f in range(1, 25):
            t = (f - 1) / 23.0
            apply_gait(act, f, t, stride_deg=34.0, knee_flex=58.0, arm_swing=32.0, forward_lean=6.0, bounce=0.055)
        self.push_to_nla(act)

        # BH_Run (20f)
        act = self.new_action("BH_Run", 20)
        for f in range(1, 21):
            t = (f - 1) / 19.0
            apply_gait(act, f, t, stride_deg=44.0, knee_flex=74.0, arm_swing=44.0, forward_lean=12.0, bounce=0.075)
        self.push_to_nla(act)

        # BH_Sprint (16f)
        act = self.new_action("BH_Sprint", 16)
        for f in range(1, 17):
            t = (f - 1) / 15.0
            apply_gait(act, f, t, stride_deg=54.0, knee_flex=90.0, arm_swing=58.0, forward_lean=18.0, bounce=0.095)
        self.push_to_nla(act)

        # Diagonal Runs for BlendSpace2D
        diag_runs = [
            ("BH_Run_FL", 40.0, -25.0),
            ("BH_Run_FR", 40.0, 25.0),
            ("BH_Run_BL", -30.0, -25.0),
            ("BH_Run_BR", -30.0, 25.0),
        ]
        for name, stride, angle in diag_runs:
            act = self.new_action(name, 20)
            for f in range(1, 21):
                t = (f - 1) / 19.0
                apply_gait(act, f, t, stride_deg=stride, knee_flex=65.0, arm_swing=38.0, forward_lean=10.0, dir_angle=angle)
            self.push_to_nla(act)

        # Starts and Stops
        act = self.new_action("BH_Walk_Start", 15)
        for f in range(1, 16):
            t = (f - 1) / 14.0
            self.key_rot("Hips", f, rx=t * 4.0, rz=sin(t * math.pi) * 3.0)
            self.key_rot("LeftUpperLeg", f, rx=t * 24.0)
            self.key_rot("LeftLowerLeg", f, rx=-max(0.0, sin(t * math.pi) * 35.0))
            self.key_rot("RightUpperArm", f, rx=t * 20.0)
            self.key_rot("LeftUpperArm", f, rx=-t * 15.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Run_Start", 15)
        for f in range(1, 16):
            t = (f - 1) / 14.0
            self.key_rot("Hips", f, rx=t * 14.0, rz=sin(t * math.pi) * 5.0)
            self.key_rot("RightUpperLeg", f, rx=-t * 35.0)
            self.key_rot("LeftUpperLeg", f, rx=t * 45.0)
            self.key_rot("LeftLowerLeg", f, rx=-sin(t * math.pi) * 60.0)
            self.key_rot("RightUpperArm", f, rx=t * 45.0)
            self.key_rot("LeftUpperArm", f, rx=-t * 40.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Walk_Stop", 15)
        for f in range(1, 16):
            t = (f - 1) / 14.0
            decay = 1.0 - t
            self.key_rot("Hips", f, rx=decay * 3.0)
            self.key_rot("LeftUpperLeg", f, rx=decay * 16.0)
            self.key_rot("RightUpperArm", f, rx=decay * 14.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Run_Stop", 20)
        for f in range(1, 21):
            t = (f - 1) / 19.0
            # Skid braking motion
            skid = sin(t * math.pi)
            self.key_rot("Hips", f, rx=-skid * 8.0, rz=skid * 4.0)
            self.key_loc("Hips", f, ly=-skid * 0.08)
            self.key_rot("LeftUpperLeg", f, rx=skid * 32.0)
            self.key_rot("RightUpperLeg", f, rx=-skid * 18.0)
            self.key_rot("LeftUpperArm", f, rz=-12.0 - skid * 18.0)
            self.key_rot("RightUpperArm", f, rz=12.0 + skid * 18.0)
        self.push_to_nla(act)

        # Turns in place
        act = self.new_action("BH_Turn_L90", 15)
        for f in range(1, 16):
            t = (f - 1) / 14.0
            turn = sin(t * math.pi)
            self.key_rot("Hips", f, ry=-turn * 45.0)
            self.key_rot("LeftUpperLeg", f, ry=-turn * 30.0, rx=turn * 12.0)
            self.key_rot("RightUpperLeg", f, rx=-turn * 8.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Turn_R90", 15)
        for f in range(1, 16):
            t = (f - 1) / 14.0
            turn = sin(t * math.pi)
            self.key_rot("Hips", f, ry=turn * 45.0)
            self.key_rot("RightUpperLeg", f, ry=turn * 30.0, rx=turn * 12.0)
            self.key_rot("LeftUpperLeg", f, rx=-turn * 8.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Turn_180", 22)
        for f in range(1, 23):
            t = (f - 1) / 21.0
            turn = sin(t * math.pi)
            self.key_rot("Hips", f, ry=-turn * 90.0, rx=turn * 4.0)
            self.key_rot("LeftUpperLeg", f, ry=-turn * 60.0, rx=turn * 18.0)
            self.key_rot("RightUpperLeg", f, ry=-turn * 40.0)
        self.push_to_nla(act)

        # Running lean turns
        act = self.new_action("BH_Turn_L", 20)
        for f in range(1, 21):
            t = (f - 1) / 19.0
            apply_gait(act, f, t, stride_deg=38.0, knee_flex=65.0, arm_swing=38.0, forward_lean=10.0, hip_tilt=-8.0, dir_angle=-15.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Turn_R", 20)
        for f in range(1, 21):
            t = (f - 1) / 19.0
            apply_gait(act, f, t, stride_deg=38.0, knee_flex=65.0, arm_swing=38.0, forward_lean=10.0, hip_tilt=8.0, dir_angle=15.0)
        self.push_to_nla(act)

    # ==========================================
    # 3. MOVEMENT TRANSITIONS
    # ==========================================
    def build_transitions(self):
        transitions = [
            ("BH_Transition_Idle_To_Walk", 12, 0.0, 26.0, 0.0, 3.0),
            ("BH_Transition_Idle_To_Run", 14, 0.0, 44.0, 0.0, 12.0),
            ("BH_Transition_Walk_To_Run", 15, 26.0, 44.0, 3.0, 12.0),
            ("BH_Transition_Run_To_Sprint", 12, 44.0, 54.0, 12.0, 18.0),
            ("BH_Transition_Sprint_To_Run", 14, 54.0, 44.0, 18.0, 12.0),
            ("BH_Transition_Run_To_Walk", 16, 44.0, 26.0, 12.0, 3.0),
            ("BH_Transition_Walk_To_Idle", 14, 26.0, 0.0, 3.0, 0.0),
            ("BH_Transition_Run_To_Idle", 18, 44.0, 0.0, 12.0, 0.0),
            ("BH_Transition_Sprint_To_Idle", 20, 54.0, 0.0, 18.0, 0.0),
        ]
        for name, frames, start_stride, end_stride, start_lean, end_lean in transitions:
            act = self.new_action(name, frames)
            for f in range(1, frames + 1):
                t = (f - 1) / float(frames - 1)
                stride = start_stride + (end_stride - start_stride) * t
                lean = start_lean + (end_lean - start_lean) * t
                arm_s = stride * 0.95
                knee = stride * 1.5
                p = t * math.tau
                self.key_rot("Hips", f, rx=lean, rz=sin(p) * 3.0)
                self.key_rot("LeftUpperLeg", f, rx=sin(p) * stride)
                self.key_rot("RightUpperLeg", f, rx=-sin(p) * stride)
                self.key_rot("LeftLowerLeg", f, rx=-max(0.0, -sin(p) * knee))
                self.key_rot("RightLowerLeg", f, rx=-max(0.0, sin(p) * knee))
                self.key_rot("LeftUpperArm", f, rx=-sin(p) * arm_s + 10.0)
                self.key_rot("RightUpperArm", f, rx=sin(p) * arm_s + 10.0)
            self.push_to_nla(act)

    # ==========================================
    # 4. JUMP SYSTEM
    # ==========================================
    def build_jump(self):
        # BH_Jump_Start (8f: anticipation dip)
        act = self.new_action("BH_Jump_Start", 8)
        for f in range(1, 9):
            t = (f - 1) / 7.0
            dip = sin(t * (math.pi / 2.0))
            self.key_loc("Hips", f, ly=-dip * 0.12)
            self.key_rot("Hips", f, rx=dip * 10.0)
            self.key_rot("LeftUpperLeg", f, rx=dip * 35.0)
            self.key_rot("RightUpperLeg", f, rx=dip * 35.0)
            self.key_rot("LeftLowerLeg", f, rx=-dip * 55.0)
            self.key_rot("RightLowerLeg", f, rx=-dip * 55.0)
            self.key_rot("LeftFoot", f, rx=-dip * 20.0)
            self.key_rot("RightFoot", f, rx=-dip * 20.0)
            self.key_rot("LeftUpperArm", f, rx=-dip * 25.0)
            self.key_rot("RightUpperArm", f, rx=-dip * 25.0)
        self.push_to_nla(act)

        # BH_Jump_Rise (12f: upward thrust, arms rising)
        act = self.new_action("BH_Jump_Rise", 12)
        for f in range(1, 13):
            t = (f - 1) / 11.0
            self.key_loc("Hips", f, ly=t * 0.08)
            self.key_rot("Hips", f, rx=5.0 - t * 8.0)
            self.key_rot("LeftUpperLeg", f, rx=-t * 12.0)
            self.key_rot("RightUpperLeg", f, rx=-t * 8.0)
            self.key_rot("LeftLowerLeg", f, rx=-t * 15.0)
            self.key_rot("RightLowerLeg", f, rx=-t * 18.0)
            self.key_rot("LeftUpperArm", f, rx=t * 35.0, rz=-15.0)
            self.key_rot("RightUpperArm", f, rx=t * 35.0, rz=15.0)
        self.push_to_nla(act)

        # BH_Jump_Apex (10f: weightless float)
        act = self.new_action("BH_Jump_Apex", 10)
        for f in range(1, 11):
            t = (f - 1) / 9.0
            float_sway = sin(t * math.pi)
            self.key_rot("Hips", f, rx=-3.0 + float_sway * 2.0)
            self.key_rot("LeftUpperLeg", f, rx=12.0 + float_sway * 5.0)
            self.key_rot("RightUpperLeg", f, rx=8.0 + float_sway * 5.0)
            self.key_rot("LeftLowerLeg", f, rx=-28.0)
            self.key_rot("RightLowerLeg", f, rx=-25.0)
            self.key_rot("LeftUpperArm", f, rx=25.0, rz=-20.0)
            self.key_rot("RightUpperArm", f, rx=25.0, rz=20.0)
        self.push_to_nla(act)

        # BH_Jump_Fall (15f loop: descending, arms balancing)
        act = self.new_action("BH_Jump_Fall", 15)
        for f in range(1, 16):
            t = (f - 1) / 14.0
            sway = sin(t * math.tau)
            self.key_rot("Hips", f, rx=4.0)
            self.key_rot("LeftUpperLeg", f, rx=6.0 + sway * 2.0)
            self.key_rot("RightUpperLeg", f, rx=6.0 - sway * 2.0)
            self.key_rot("LeftLowerLeg", f, rx=-15.0)
            self.key_rot("RightLowerLeg", f, rx=-15.0)
            self.key_rot("LeftFoot", f, rx=15.0)
            self.key_rot("RightFoot", f, rx=15.0)
            self.key_rot("LeftUpperArm", f, rx=15.0 + sway * 4.0, rz=-25.0)
            self.key_rot("RightUpperArm", f, rx=15.0 - sway * 4.0, rz=25.0)
        self.push_to_nla(act)

        # BH_Jump_Land (12f: knee shock absorption)
        act = self.new_action("BH_Jump_Land", 12)
        for f in range(1, 13):
            t = (f - 1) / 11.0
            imp = sin(t * math.pi)
            self.key_loc("Hips", f, ly=-imp * 0.10)
            self.key_rot("Hips", f, rx=imp * 12.0)
            self.key_rot("LeftUpperLeg", f, rx=imp * 32.0)
            self.key_rot("RightUpperLeg", f, rx=imp * 32.0)
            self.key_rot("LeftLowerLeg", f, rx=-imp * 48.0)
            self.key_rot("RightLowerLeg", f, rx=-imp * 48.0)
            self.key_rot("LeftUpperArm", f, rx=imp * 20.0, rz=-12.0)
            self.key_rot("RightUpperArm", f, rx=imp * 20.0, rz=12.0)
        self.push_to_nla(act)

        # BH_Jump_Land_Hard (20f: deep impact, ground touch)
        act = self.new_action("BH_Jump_Land_Hard", 20)
        for f in range(1, 21):
            t = (f - 1) / 19.0
            imp = sin(t * math.pi)
            self.key_loc("Hips", f, ly=-imp * 0.22)
            self.key_rot("Hips", f, rx=imp * 25.0)
            self.key_rot("Spine", f, rx=imp * 15.0)
            self.key_rot("LeftUpperLeg", f, rx=imp * 55.0)
            self.key_rot("RightUpperLeg", f, rx=imp * 65.0)
            self.key_rot("LeftLowerLeg", f, rx=-imp * 80.0)
            self.key_rot("RightLowerLeg", f, rx=-imp * 90.0)
            self.key_rot("RightUpperArm", f, rx=imp * 50.0, rz=imp * 15.0)
            self.key_rot("RightLowerArm", f, rx=-imp * 40.0)
        self.push_to_nla(act)

        # BH_Jump_Running (24f: high-speed hurdle leap)
        act = self.new_action("BH_Jump_Running", 24)
        for f in range(1, 25):
            t = (f - 1) / 23.0
            leap = sin(t * math.pi)
            self.key_rot("Hips", f, rx=12.0)
            self.key_rot("LeftUpperLeg", f, rx=leap * 48.0)
            self.key_rot("LeftLowerLeg", f, rx=-leap * 20.0)
            self.key_rot("RightUpperLeg", f, rx=-leap * 35.0)
            self.key_rot("RightLowerLeg", f, rx=-leap * 55.0)
            self.key_rot("RightUpperArm", f, rx=leap * 50.0)
            self.key_rot("LeftUpperArm", f, rx=-leap * 40.0)
        self.push_to_nla(act)

        # BH_Jump_Recovery (14f: rolling spring back to run)
        act = self.new_action("BH_Jump_Recovery", 14)
        for f in range(1, 15):
            t = (f - 1) / 13.0
            rec = sin(t * math.pi)
            self.key_rot("Hips", f, rx=10.0 + rec * 6.0)
            self.key_rot("LeftUpperLeg", f, rx=rec * 25.0)
            self.key_rot("RightUpperLeg", f, rx=-rec * 15.0)
            self.key_rot("RightUpperArm", f, rx=rec * 30.0)
            self.key_rot("LeftUpperArm", f, rx=-rec * 20.0)
        self.push_to_nla(act)

    # ==========================================
    # 5. CROUCH SYSTEM
    # ==========================================
    def build_crouch(self):
        # BH_Crouch_Enter (12f)
        act = self.new_action("BH_Crouch_Enter", 12)
        for f in range(1, 13):
            t = (f - 1) / 11.0
            self.key_loc("Hips", f, ly=-t * 0.35)
            self.key_rot("Hips", f, rx=t * 15.0)
            self.key_rot("LeftUpperLeg", f, rx=t * 50.0)
            self.key_rot("RightUpperLeg", f, rx=t * 50.0)
            self.key_rot("LeftLowerLeg", f, rx=-t * 70.0)
            self.key_rot("RightLowerLeg", f, rx=-t * 70.0)
            self.key_rot("LeftUpperArm", f, rx=t * 22.0)
            self.key_rot("RightUpperArm", f, rx=t * 22.0)
        self.push_to_nla(act)

        # BH_Crouch_Idle (60f loop)
        act = self.new_action("BH_Crouch_Idle", 60)
        for f in range(1, 61):
            t = (f - 1) / 59.0
            breath = sin(t * math.tau)
            self.key_loc("Hips", f, ly=-0.35 + breath * 0.006)
            self.key_rot("Hips", f, rx=15.0 + breath * 1.0)
            self.key_rot("Spine", f, rx=4.0 + breath * 1.2)
            self.key_rot("LeftUpperLeg", f, rx=50.0, rz=-6.0)
            self.key_rot("RightUpperLeg", f, rx=50.0, rz=6.0)
            self.key_rot("LeftLowerLeg", f, rx=-70.0)
            self.key_rot("RightLowerLeg", f, rx=-70.0)
            self.key_rot("LeftUpperArm", f, rx=22.0, rz=-14.0)
            self.key_rot("RightUpperArm", f, rx=22.0, rz=14.0)
            self.key_rot("LeftLowerArm", f, rx=-45.0)
            self.key_rot("RightLowerArm", f, rx=-45.0)
        self.push_to_nla(act)

        # BH_Crouch_Walk (30f loop: stealth creep)
        act = self.new_action("BH_Crouch_Walk", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            p = t * math.tau
            s = sin(p)
            c = cos(p)
            self.key_loc("Hips", f, ly=-0.35 - abs(s) * 0.02)
            self.key_rot("Hips", f, rx=16.0, rz=c * 3.0)
            self.key_rot("LeftUpperLeg", f, rx=50.0 + s * 18.0)
            self.key_rot("RightUpperLeg", f, rx=50.0 - s * 18.0)
            self.key_rot("LeftLowerLeg", f, rx=-70.0 - max(0.0, -s * 25.0))
            self.key_rot("RightLowerLeg", f, rx=-70.0 - max(0.0, s * 25.0))
            self.key_rot("LeftUpperArm", f, rx=22.0 - s * 12.0)
            self.key_rot("RightUpperArm", f, rx=22.0 + s * 12.0)
        self.push_to_nla(act)

        # BH_Crouch_Turn (16f)
        act = self.new_action("BH_Crouch_Turn", 16)
        for f in range(1, 17):
            t = (f - 1) / 15.0
            turn = sin(t * math.pi)
            self.key_loc("Hips", f, ly=-0.35)
            self.key_rot("Hips", f, rx=15.0, ry=-turn * 40.0)
            self.key_rot("LeftUpperLeg", f, rx=50.0, ry=-turn * 25.0)
            self.key_rot("RightUpperLeg", f, rx=50.0)
            self.key_rot("LeftLowerLeg", f, rx=-70.0)
            self.key_rot("RightLowerLeg", f, rx=-70.0)
        self.push_to_nla(act)

        # BH_Crouch_Exit (12f)
        act = self.new_action("BH_Crouch_Exit", 12)
        for f in range(1, 13):
            t = 1.0 - ((f - 1) / 11.0)
            self.key_loc("Hips", f, ly=-t * 0.35)
            self.key_rot("Hips", f, rx=t * 15.0)
            self.key_rot("LeftUpperLeg", f, rx=t * 50.0)
            self.key_rot("RightUpperLeg", f, rx=t * 50.0)
            self.key_rot("LeftLowerLeg", f, rx=-t * 70.0)
            self.key_rot("RightLowerLeg", f, rx=-t * 70.0)
        self.push_to_nla(act)

    # ==========================================
    # 6. COMBAT FOUNDATION
    # ==========================================
    def build_combat(self):
        # BH_Combat_Idle (45f loop: guard up boxer stance)
        act = self.new_action("BH_Combat_Idle", 45)
        for f in range(1, 46):
            t = (f - 1) / 44.0
            sway = sin(t * math.tau)
            self.key_rot("Hips", f, rx=5.0, ry=25.0, rz=sway * 2.0)
            self.key_loc("Hips", f, ly=-0.03 + sway * 0.008)
            self.key_rot("LeftUpperLeg", f, rx=14.0, ry=-10.0)
            self.key_rot("RightUpperLeg", f, rx=-10.0, ry=-15.0)
            self.key_rot("LeftLowerLeg", f, rx=-20.0)
            self.key_rot("RightLowerLeg", f, rx=-15.0)
            # Fists guarding chin
            self.key_rot("LeftUpperArm", f, rx=48.0 + sway * 2.0, ry=15.0, rz=-22.0)
            self.key_rot("LeftLowerArm", f, rx=-95.0, ry=-20.0)
            self.key_rot("RightUpperArm", f, rx=52.0 + sway * 2.0, ry=-10.0, rz=18.0)
            self.key_rot("RightLowerArm", f, rx=-105.0, ry=15.0)
            self.key_rot("Head", f, ry=-15.0, rx=3.0)
        self.push_to_nla(act)

        # BH_Punch_Light (12f: snappy left lead jab)
        act = self.new_action("BH_Punch_Light", 12)
        for f in range(1, 13):
            t = (f - 1) / 11.0
            strike = sin(t * math.pi)
            self.key_rot("Hips", f, ry=25.0 - strike * 15.0)
            self.key_rot("Spine", f, ry=-strike * 12.0)
            self.key_rot("Spine1", f, ry=-strike * 10.0)
            # Left arm snaps forward
            self.key_rot("LeftUpperArm", f, rx=48.0 + strike * 35.0, ry=15.0 - strike * 10.0, rz=-22.0 + strike * 15.0)
            self.key_rot("LeftLowerArm", f, rx=-95.0 + strike * 85.0)
            self.key_rot("LeftHand", f, rx=strike * 15.0)
            # Right arm stays at guard
            self.key_rot("RightUpperArm", f, rx=52.0, rz=18.0)
            self.key_rot("RightLowerArm", f, rx=-105.0)
        self.push_to_nla(act)

        # BH_Punch_Heavy (16f: devastating right cross)
        act = self.new_action("BH_Punch_Heavy", 16)
        for f in range(1, 17):
            t = (f - 1) / 15.0
            strike = sin(t * math.pi)
            self.key_rot("Hips", f, rx=strike * 5.0, ry=25.0 - strike * 40.0)
            self.key_rot("Spine", f, ry=-strike * 25.0)
            self.key_rot("Spine1", f, ry=-strike * 18.0)
            # Right foot pivots
            self.key_rot("RightUpperLeg", f, ry=-strike * 30.0, rx=-10.0 + strike * 15.0)
            # Right arm drives forward
            self.key_rot("RightUpperArm", f, rx=52.0 + strike * 38.0, ry=-10.0 + strike * 20.0, rz=18.0 - strike * 10.0)
            self.key_rot("RightLowerArm", f, rx=-105.0 + strike * 95.0)
            self.key_rot("RightHand", f, rx=strike * 20.0)
        self.push_to_nla(act)

        # BH_Kick (22f: right push kick)
        act = self.new_action("BH_Kick", 22)
        for f in range(1, 23):
            t = (f - 1) / 21.0
            kick = sin(t * math.pi)
            self.key_rot("Hips", f, rx=-kick * 12.0, ry=-kick * 10.0)
            self.key_rot("LeftUpperLeg", f, rx=kick * 10.0)
            # Right leg chambers then thrusts
            chamber = sin(min(1.0, t * 2.0) * math.pi)
            thrust = sin(max(0.0, (t - 0.25) * 1.5) * math.pi)
            self.key_rot("RightUpperLeg", f, rx=kick * 75.0)
            self.key_rot("RightLowerLeg", f, rx=-max(0.0, (chamber - thrust * 0.8) * 75.0))
            self.key_rot("RightFoot", f, rx=kick * 25.0)
            self.key_rot("LeftUpperArm", f, rx=30.0, rz=-25.0)
            self.key_rot("RightUpperArm", f, rx=-kick * 25.0, rz=20.0)
        self.push_to_nla(act)

        # Dodges
        act = self.new_action("BH_Dodge_L", 14)
        for f in range(1, 15):
            t = (f - 1) / 13.0
            d = sin(t * math.pi)
            self.key_rot("Hips", f, rz=d * 18.0)
            self.key_loc("Hips", f, lx=-d * 0.15, ly=-d * 0.08)
            self.key_rot("Spine", f, rz=-d * 10.0)
            self.key_rot("LeftUpperLeg", f, rz=d * 22.0)
            self.key_rot("RightUpperLeg", f, rz=d * 15.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Dodge_R", 14)
        for f in range(1, 15):
            t = (f - 1) / 13.0
            d = sin(t * math.pi)
            self.key_rot("Hips", f, rz=-d * 18.0)
            self.key_loc("Hips", f, lx=d * 0.15, ly=-d * 0.08)
            self.key_rot("Spine", f, rz=d * 10.0)
            self.key_rot("LeftUpperLeg", f, rz=-d * 15.0)
            self.key_rot("RightUpperLeg", f, rz=-d * 22.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Dodge_B", 16)
        for f in range(1, 17):
            t = (f - 1) / 15.0
            d = sin(t * math.pi)
            self.key_rot("Hips", f, rx=-d * 14.0)
            self.key_loc("Hips", f, lz=d * 0.18, ly=-d * 0.06)
            self.key_rot("Spine", f, rx=-d * 12.0)
            self.key_rot("LeftUpperLeg", f, rx=-d * 25.0)
            self.key_rot("RightUpperLeg", f, rx=d * 18.0)
        self.push_to_nla(act)

        # Hit reactions
        hits = [
            ("BH_Hit_F", -15.0, 0.0, 0.0),
            ("BH_Hit_B", 15.0, 0.0, 0.0),
            ("BH_Hit_L", 0.0, 0.0, 14.0),
            ("BH_Hit_R", 0.0, 0.0, -14.0),
        ]
        for name, rx, ry, rz in hits:
            act = self.new_action(name, 12)
            for f in range(1, 13):
                t = (f - 1) / 11.0
                impact = sin(t * math.pi) * exp(-t * 2.5)
                self.key_rot("Hips", f, rx=rx * impact, ry=ry * impact, rz=rz * impact)
                self.key_rot("Spine", f, rx=rx * impact * 0.8, rz=rz * impact * 0.8)
                self.key_rot("Head", f, rx=rx * impact * 1.2, rz=rz * impact * 1.2)
            self.push_to_nla(act)

        # Knockdown & Get Up
        act = self.new_action("BH_Knockdown", 24)
        for f in range(1, 25):
            t = (f - 1) / 23.0
            fall = sin(t * (math.pi / 2.0))
            self.key_loc("Hips", f, ly=-fall * 0.82, lz=-fall * 0.4)
            self.key_rot("Hips", f, rx=-fall * 85.0)
            self.key_rot("LeftUpperLeg", f, rx=fall * 30.0)
            self.key_rot("RightUpperLeg", f, rx=fall * 25.0)
            self.key_rot("LeftUpperArm", f, rz=-fall * 40.0)
            self.key_rot("RightUpperArm", f, rz=fall * 40.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Get_Up", 28)
        for f in range(1, 29):
            t = (f - 1) / 27.0
            rise = 1.0 - t
            self.key_loc("Hips", f, ly=-rise * 0.82, lz=-rise * 0.4)
            self.key_rot("Hips", f, rx=-rise * 85.0, ry=sin(t * math.pi) * 35.0)
            self.key_rot("RightUpperLeg", f, rx=rise * 45.0)
            self.key_rot("RightLowerLeg", f, rx=-rise * 65.0)
        self.push_to_nla(act)

    # ==========================================
    # 7. WEAPON FOUNDATION
    # ==========================================
    def build_weapons(self):
        # Pistol Idle (45f)
        act = self.new_action("BH_Pistol_Idle", 45)
        for f in range(1, 46):
            t = (f - 1) / 44.0
            b = sin(t * math.tau)
            self.key_rot("Spine", f, rx=1.0 + b * 1.0)
            self.key_rot("LeftUpperArm", f, rx=35.0 + b * 1.0, ry=25.0, rz=-20.0)
            self.key_rot("LeftLowerArm", f, rx=-65.0)
            self.key_rot("RightUpperArm", f, rx=35.0 + b * 1.0, ry=-20.0, rz=15.0)
            self.key_rot("RightLowerArm", f, rx=-65.0)
        self.push_to_nla(act)

        # Pistol Aim (30f)
        act = self.new_action("BH_Pistol_Aim", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            b = sin(t * math.tau)
            self.key_rot("Spine", f, ry=18.0)
            self.key_rot("RightUpperArm", f, rx=82.0 + b * 0.6, ry=-8.0, rz=5.0)
            self.key_rot("RightLowerArm", f, rx=-8.0)
            self.key_rot("LeftUpperArm", f, rx=78.0 + b * 0.6, ry=28.0, rz=-12.0)
            self.key_rot("LeftLowerArm", f, rx=-25.0)
            self.key_rot("Head", f, ry=-16.0)
        self.push_to_nla(act)

        # Pistol Fire (10f)
        act = self.new_action("BH_Pistol_Fire", 10)
        for f in range(1, 11):
            t = (f - 1) / 9.0
            kick = sin(t * math.pi) * exp(-t * 2.8)
            self.key_rot("Spine", f, rx=-kick * 4.0, ry=18.0)
            self.key_rot("RightUpperArm", f, rx=82.0 + kick * 14.0, ry=-8.0)
            self.key_rot("RightHand", f, rx=kick * 16.0)
            self.key_rot("LeftUpperArm", f, rx=78.0 + kick * 12.0, ry=28.0)
            self.key_rot("Head", f, ry=-16.0)
        self.push_to_nla(act)

        # Pistol Reload (36f)
        act = self.new_action("BH_Pistol_Reload", 36)
        for f in range(1, 37):
            t = (f - 1) / 35.0
            self.key_rot("RightUpperArm", f, rx=60.0, ry=-15.0)
            self.key_rot("RightLowerArm", f, rx=-35.0)
            # Left hand grabs mag at hip, inserts, racks slide
            mag_grab = sin(min(1.0, t * 2.0) * math.pi)
            rack = sin(max(0.0, (t - 0.7) * 3.33) * math.pi)
            self.key_rot("LeftUpperArm", f, rx=20.0 + mag_grab * 45.0 + rack * 50.0, rz=-15.0 + mag_grab * 25.0)
            self.key_rot("LeftLowerArm", f, rx=-40.0 - mag_grab * 30.0 - rack * 20.0)
        self.push_to_nla(act)

        # Rifle Idle (45f)
        act = self.new_action("BH_Rifle_Idle", 45)
        for f in range(1, 46):
            t = (f - 1) / 44.0
            b = sin(t * math.tau)
            self.key_rot("Spine", f, rx=2.0, ry=15.0)
            self.key_rot("RightUpperArm", f, rx=35.0 + b * 1.0, ry=-15.0, rz=12.0)
            self.key_rot("RightLowerArm", f, rx=-55.0)
            self.key_rot("LeftUpperArm", f, rx=45.0 + b * 1.0, ry=35.0, rz=-18.0)
            self.key_rot("LeftLowerArm", f, rx=-70.0)
        self.push_to_nla(act)

        # Rifle Aim (30f)
        act = self.new_action("BH_Rifle_Aim", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            b = sin(t * math.tau)
            self.key_rot("Spine", f, rx=4.0, ry=25.0)
            self.key_rot("RightShoulder", f, rx=-4.0)
            self.key_rot("RightUpperArm", f, rx=75.0 + b * 0.5, ry=-22.0, rz=12.0)
            self.key_rot("RightLowerArm", f, rx=-65.0)
            self.key_rot("LeftUpperArm", f, rx=65.0 + b * 0.5, ry=35.0, rz=-12.0)
            self.key_rot("LeftLowerArm", f, rx=-40.0)
            self.key_rot("Head", f, ry=-22.0, rx=4.0, rz=6.0)
        self.push_to_nla(act)

        # Rifle Fire (8f)
        act = self.new_action("BH_Rifle_Fire", 8)
        for f in range(1, 9):
            t = (f - 1) / 7.0
            recoil = sin(t * math.pi) * exp(-t * 2.5)
            self.key_rot("Spine", f, rx=4.0 - recoil * 5.0, ry=25.0)
            self.key_rot("RightUpperArm", f, rx=75.0 + recoil * 8.0, ry=-22.0)
            self.key_rot("LeftUpperArm", f, rx=65.0 + recoil * 6.0, ry=35.0)
            self.key_rot("Head", f, ry=-22.0, rx=4.0 - recoil * 2.0)
        self.push_to_nla(act)

        # Rifle Reload (42f)
        act = self.new_action("BH_Rifle_Reload", 42)
        for f in range(1, 43):
            t = (f - 1) / 41.0
            self.key_rot("RightUpperArm", f, rx=50.0, ry=-20.0)
            self.key_rot("RightLowerArm", f, rx=-55.0)
            mag_swap = sin(t * math.pi)
            self.key_rot("LeftUpperArm", f, rx=25.0 + mag_swap * 40.0, rz=-10.0 + mag_swap * 20.0)
            self.key_rot("LeftLowerArm", f, rx=-50.0 - mag_swap * 30.0)
        self.push_to_nla(act)

        # Weapon Equip & Unequip
        act = self.new_action("BH_Weapon_Equip", 18)
        for f in range(1, 19):
            t = (f - 1) / 17.0
            reach = sin(t * math.pi)
            self.key_rot("RightUpperArm", f, rx=t * 80.0 + reach * 15.0, ry=-reach * 30.0)
            self.key_rot("RightLowerArm", f, rx=-reach * 70.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Weapon_Unequip", 18)
        for f in range(1, 19):
            t = 1.0 - ((f - 1) / 17.0)
            reach = sin(t * math.pi)
            self.key_rot("RightUpperArm", f, rx=t * 80.0 + reach * 15.0, ry=-reach * 30.0)
            self.key_rot("RightLowerArm", f, rx=-reach * 70.0)
        self.push_to_nla(act)

    # ==========================================
    # 8. INTERACTION ANIMATIONS
    # ==========================================
    def build_interactions(self):
        # BH_Interact_Pickup (25f)
        act = self.new_action("BH_Interact_Pickup", 25)
        for f in range(1, 26):
            t = (f - 1) / 24.0
            crouch = sin(t * math.pi)
            self.key_loc("Hips", f, ly=-crouch * 0.38)
            self.key_rot("Hips", f, rx=crouch * 25.0)
            self.key_rot("Spine", f, rx=crouch * 20.0)
            self.key_rot("LeftUpperLeg", f, rx=crouch * 50.0)
            self.key_rot("RightUpperLeg", f, rx=crouch * 60.0)
            self.key_rot("LeftLowerLeg", f, rx=-crouch * 75.0)
            self.key_rot("RightLowerLeg", f, rx=-crouch * 85.0)
            self.key_rot("RightUpperArm", f, rx=crouch * 70.0)
            self.key_rot("RightLowerArm", f, rx=-crouch * 20.0)
        self.push_to_nla(act)

        # BH_Interact_Inspect (40f)
        act = self.new_action("BH_Interact_Inspect", 40)
        for f in range(1, 41):
            t = (f - 1) / 39.0
            insp = sin(t * math.pi)
            turn_hands = sin(t * math.tau) * 20.0
            self.key_rot("LeftUpperArm", f, rx=insp * 55.0, rz=-insp * 15.0)
            self.key_rot("LeftLowerArm", f, rx=-insp * 75.0)
            self.key_rot("RightUpperArm", f, rx=insp * 55.0, rz=insp * 15.0)
            self.key_rot("RightLowerArm", f, rx=-insp * 75.0)
            self.key_rot("LeftHand", f, ry=turn_hands)
            self.key_rot("RightHand", f, ry=turn_hands)
            self.key_rot("Head", f, rx=insp * 15.0)
        self.push_to_nla(act)

        # Door Open & Close
        act = self.new_action("BH_Interact_Door_Open", 24)
        for f in range(1, 25):
            t = (f - 1) / 23.0
            reach = sin(t * math.pi)
            self.key_rot("RightUpperArm", f, rx=reach * 70.0, ry=-reach * 15.0)
            self.key_rot("RightLowerArm", f, rx=-reach * 35.0)
            self.key_rot("Spine", f, ry=-reach * 12.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Interact_Door_Close", 20)
        for f in range(1, 21):
            t = (f - 1) / 19.0
            reach = sin(t * math.pi)
            self.key_rot("LeftUpperArm", f, rx=reach * 65.0, ry=reach * 15.0)
            self.key_rot("LeftLowerArm", f, rx=-reach * 40.0)
            self.key_rot("Spine", f, ry=reach * 10.0)
        self.push_to_nla(act)

        # Push & Pull
        act = self.new_action("BH_Interact_Push", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            p = sin(t * math.tau)
            self.key_rot("Hips", f, rx=22.0)
            self.key_rot("Spine", f, rx=8.0)
            self.key_rot("LeftUpperArm", f, rx=75.0, rz=-12.0)
            self.key_rot("RightUpperArm", f, rx=75.0, rz=12.0)
            self.key_rot("LeftLowerArm", f, rx=-25.0)
            self.key_rot("RightLowerArm", f, rx=-25.0)
            self.key_rot("LeftUpperLeg", f, rx=25.0 + p * 12.0)
            self.key_rot("RightUpperLeg", f, rx=-15.0 - p * 12.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Interact_Pull", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            p = sin(t * math.tau)
            self.key_rot("Hips", f, rx=-18.0)
            self.key_rot("Spine", f, rx=-6.0)
            self.key_rot("LeftUpperArm", f, rx=60.0, rz=-12.0)
            self.key_rot("RightUpperArm", f, rx=60.0, rz=12.0)
            self.key_rot("LeftLowerArm", f, rx=-65.0)
            self.key_rot("RightLowerArm", f, rx=-65.0)
            self.key_rot("LeftUpperLeg", f, rx=-20.0 + p * 10.0)
            self.key_rot("RightUpperLeg", f, rx=20.0 - p * 10.0)
        self.push_to_nla(act)

        # Climb & Vault
        act = self.new_action("BH_Interact_Climb", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            p = t * math.tau
            s = sin(p)
            self.key_rot("Hips", f, rx=4.0)
            # Alternating arms reach high
            self.key_rot("LeftUpperArm", f, rx=130.0 + s * 30.0, rz=-15.0)
            self.key_rot("RightUpperArm", f, rx=130.0 - s * 30.0, rz=15.0)
            self.key_rot("LeftLowerArm", f, rx=-40.0)
            self.key_rot("RightLowerArm", f, rx=-40.0)
            self.key_rot("LeftUpperLeg", f, rx=35.0 - s * 25.0)
            self.key_rot("RightUpperLeg", f, rx=35.0 + s * 25.0)
            self.key_rot("LeftLowerLeg", f, rx=-60.0)
            self.key_rot("RightLowerLeg", f, rx=-60.0)
        self.push_to_nla(act)

        act = self.new_action("BH_Interact_Vault", 22)
        for f in range(1, 23):
            t = (f - 1) / 21.0
            v = sin(t * math.pi)
            self.key_loc("Hips", f, ly=v * 0.45, lx=v * 0.1)
            self.key_rot("Hips", f, rx=v * 30.0, rz=v * 25.0)
            self.key_rot("LeftUpperArm", f, rx=v * 75.0, rz=-v * 25.0)
            self.key_rot("LeftLowerArm", f, rx=-v * 40.0)
            self.key_rot("LeftUpperLeg", f, rx=v * 65.0, rz=v * 30.0)
            self.key_rot("RightUpperLeg", f, rx=v * 55.0, rz=v * 20.0)
        self.push_to_nla(act)

    # ==========================================
    # 9. VEHICLE / DRIVING
    # ==========================================
    def build_vehicle(self):
        # BH_Vehicle_Enter (30f)
        act = self.new_action("BH_Vehicle_Enter", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            step = sin(t * math.pi)
            self.key_loc("Hips", f, ly=-t * 0.45)
            self.key_rot("Hips", f, ry=-t * 40.0)
            self.key_rot("LeftUpperLeg", f, rx=t * 70.0 + step * 20.0)
            self.key_rot("RightUpperLeg", f, rx=t * 70.0)
            self.key_rot("LeftLowerLeg", f, rx=-t * 85.0)
            self.key_rot("RightLowerLeg", f, rx=-t * 85.0)
            self.key_rot("RightUpperArm", f, rx=step * 60.0)
        self.push_to_nla(act)

        # BH_Vehicle_Sit (45f loop)
        act = self.new_action("BH_Vehicle_Sit", 45)
        for f in range(1, 46):
            t = (f - 1) / 44.0
            b = sin(t * math.tau)
            self.key_loc("Hips", f, ly=-0.45 + b * 0.005)
            self.key_rot("Hips", f, rx=-8.0)
            self.key_rot("Spine", f, rx=5.0 + b * 1.0)
            self.key_rot("LeftUpperLeg", f, rx=75.0, rz=-12.0)
            self.key_rot("RightUpperLeg", f, rx=75.0, rz=12.0)
            self.key_rot("LeftLowerLeg", f, rx=-85.0)
            self.key_rot("RightLowerLeg", f, rx=-85.0)
            # Hands on steering wheel (10 and 2)
            self.key_rot("LeftUpperArm", f, rx=55.0, ry=20.0, rz=-22.0)
            self.key_rot("LeftLowerArm", f, rx=-55.0)
            self.key_rot("RightUpperArm", f, rx=55.0, ry=-20.0, rz=22.0)
            self.key_rot("RightLowerArm", f, rx=-55.0)
        self.push_to_nla(act)

        # BH_Vehicle_Steer (30f loop: turn wheel left and right)
        act = self.new_action("BH_Vehicle_Steer", 30)
        for f in range(1, 31):
            t = (f - 1) / 29.0
            steer = sin(t * math.tau) * 28.0
            self.key_loc("Hips", f, ly=-0.45)
            self.key_rot("LeftUpperLeg", f, rx=75.0)
            self.key_rot("RightUpperLeg", f, rx=75.0)
            self.key_rot("LeftLowerLeg", f, rx=-85.0)
            self.key_rot("RightLowerLeg", f, rx=-85.0)
            self.key_rot("LeftUpperArm", f, rx=55.0 - steer * 0.4, ry=20.0, rz=-22.0 + steer * 0.5)
            self.key_rot("RightUpperArm", f, rx=55.0 + steer * 0.4, ry=-20.0, rz=22.0 + steer * 0.5)
            self.key_rot("LeftLowerArm", f, rx=-55.0 - steer * 0.3)
            self.key_rot("RightLowerArm", f, rx=-55.0 + steer * 0.3)
        self.push_to_nla(act)

        # BH_Vehicle_Look_L (25f)
        act = self.new_action("BH_Vehicle_Look_L", 25)
        for f in range(1, 26):
            t = (f - 1) / 24.0
            look = sin(t * math.pi) * 55.0
            self.key_loc("Hips", f, ly=-0.45)
            self.key_rot("LeftUpperLeg", f, rx=75.0)
            self.key_rot("RightUpperLeg", f, rx=75.0)
            self.key_rot("LeftLowerLeg", f, rx=-85.0)
            self.key_rot("RightLowerLeg", f, rx=-85.0)
            self.key_rot("Spine", f, ry=look * 0.3)
            self.key_rot("Head", f, ry=look * 0.8)
            self.key_rot("LeftUpperArm", f, rx=55.0, rz=-22.0)
            self.key_rot("RightUpperArm", f, rx=55.0, rz=22.0)
        self.push_to_nla(act)

        # BH_Vehicle_Look_R (25f)
        act = self.new_action("BH_Vehicle_Look_R", 25)
        for f in range(1, 26):
            t = (f - 1) / 24.0
            look = -sin(t * math.pi) * 50.0
            self.key_loc("Hips", f, ly=-0.45)
            self.key_rot("LeftUpperLeg", f, rx=75.0)
            self.key_rot("RightUpperLeg", f, rx=75.0)
            self.key_rot("LeftLowerLeg", f, rx=-85.0)
            self.key_rot("RightLowerLeg", f, rx=-85.0)
            self.key_rot("Spine", f, ry=look * 0.3)
            self.key_rot("Head", f, ry=look * 0.8)
            self.key_rot("LeftUpperArm", f, rx=55.0, rz=-22.0)
            self.key_rot("RightUpperArm", f, rx=55.0, rz=22.0)
        self.push_to_nla(act)

        # BH_Vehicle_Exit (28f)
        act = self.new_action("BH_Vehicle_Exit", 28)
        for f in range(1, 29):
            t = 1.0 - ((f - 1) / 27.0)
            step = sin(t * math.pi)
            self.key_loc("Hips", f, ly=-t * 0.45)
            self.key_rot("Hips", f, ry=-t * 40.0)
            self.key_rot("LeftUpperLeg", f, rx=t * 70.0 + step * 20.0)
            self.key_rot("RightUpperLeg", f, rx=t * 70.0)
            self.key_rot("LeftLowerLeg", f, rx=-t * 85.0)
            self.key_rot("RightLowerLeg", f, rx=-t * 85.0)
        self.push_to_nla(act)

    # ==========================================
    # 10. BACKWARD-COMPATIBLE ALIASES
    # ==========================================
    def build_aliases(self):
        # Maps legacy actions directly to the new animations for zero regression
        alias_map = {
            "idle": "BH_Idle",
            "walk": "BH_Walk_F",
            "run": "BH_Run",
            "jump": "BH_Jump_Rise",
            "aim": "BH_Pistol_Aim",
            "shoot": "BH_Pistol_Fire",
            "punch_l": "BH_Punch_Light",
            "punch_r": "BH_Punch_Heavy"
        }
        for alias_name, target_name in alias_map.items():
            if target_name in bpy.data.actions:
                orig_act = bpy.data.actions[target_name]
                act_copy = orig_act.copy()
                act_copy.name = alias_name
                act_copy.use_fake_user = True
                track = self.armature.animation_data.nla_tracks.new()
                track.name = alias_name
                track.strips.new(alias_name, 1, act_copy)
                self.actions.append(alias_name)
                print("  [Alias Created] %s -> %s" % (alias_name, target_name))

def main():
    print("=== STARTING FULL ANIMATION LIBRARY GENERATION ===")
    armature = init_scene()
    builder = AnimBuilder(armature)

    print("\n--- Generating Idle Set ---")
    builder.build_idle()

    print("\n--- Generating Locomotion Set ---")
    builder.build_locomotion()

    print("\n--- Generating Transitions Set ---")
    builder.build_transitions()

    print("\n--- Generating Jump Set ---")
    builder.build_jump()

    print("\n--- Generating Crouch Set ---")
    builder.build_crouch()

    print("\n--- Generating Combat Set ---")
    builder.build_combat()

    print("\n--- Generating Weapon Set ---")
    builder.build_weapons()

    print("\n--- Generating Interactions Set ---")
    builder.build_interactions()

    print("\n--- Generating Vehicle / Driving Set ---")
    builder.build_vehicle()

    print("\n--- Generating Backward-Compatible Aliases ---")
    builder.build_aliases()

    print("\nTotal animations generated: %d" % len(builder.actions))

    # Save master Blender file with all NLA tracks
    print("\nSaving Master Blender file to %s..." % BLEND_FILE)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE)

    # Export game-ready glTF 2.0 (GLB)
    print("Exporting Game-Ready glTF 2.0 to %s..." % OUTPUT_GLB)
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_GLB,
        export_format='GLB',
        export_animations=True,
        export_nla_strips=True,
        export_optimize_animation_size=True,
        export_anim_single_armature=True
    )
    print("=== ANIMATION SYSTEM EXPORT COMPLETED SUCCESSFULLY! ===")

if __name__ == "__main__":
    main()

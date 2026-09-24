# Broken Horizon — Complete Protagonist Character Animation System
## Technical Architecture & Integration Guide (Godot 4.3.1 / Android-First)

---

## 1. Executive Summary

This document specifies the complete 3D character animation system created for the original protagonist of **Broken Horizon**, tailored for a third-person open-world action-adventure targeting **Android first** with scalable PC/console support.

All animations are authored on the original 61/62-bone humanoid rig, preserving the original mesh topology, A-pose rest reference, and bone transforms. The library comprises **113 baked actions** (including directional variations, transitions, and backward-compatible legacy aliases) packaged into a lightweight, mobile-optimized glTF 2.0 asset ([character.glb](file:///e:/GameDev/BrokenHorizon/assets/models/characters/character.glb), 2.19 MB) and Blender master project ([BH_Protagonist_FullAnimations.blend](file:///e:/GameDev/BrokenHorizon/character_source/BH_Protagonist_FullAnimations.blend)).

---

## 2. Animation Catalog & Structure

Every animation is authored at a consistent **30 FPS**, with uniform bone naming and non-destructive quaternion rotations (`rotation_quaternion`). Scale tracks are pruned to minimize runtime memory and eliminate mobile scale drift.

### 2.1 Locomotion (In-Place for CharacterBody3D)
All locomotion animations are authored **in-place** (the `Root` bone remains stationary at the origin `(0, 0, 0)` with hips oscillating naturally) to give the Godot character controller deterministic velocity, collision handling, and slope alignment.

| Animation Name | Frames | Duration | Looping | Description / BlendSpace Placement |
|---|---|---|---|---|
| `BH_Idle` | 60 | 2.00s | Yes | Relaxed breathing, subtle shoulder & spine sway, center origin `(0, 0)` |
| `BH_Idle_Var01` | 90 | 3.00s | No | Weight shift to left hip, head scan right, settle back |
| `BH_Idle_Var02` | 90 | 3.00s | No | Weapon holster check / gear adjustment, shoulder roll |
| `BH_Unarmed_Idle` | 60 | 2.00s | Yes | Neutral hands-open passive stance |
| `BH_Walk_F` | 30 | 1.00s | Yes | Forward walk stride (1.4 m/s), position `(0, 1)` |
| `BH_Walk_B` | 30 | 1.00s | Yes | Backward walk stride (1.2 m/s), position `(0, -1)` |
| `BH_Walk_L` | 30 | 1.00s | Yes | Left strafe stride (1.2 m/s), position `(-1, 0)` |
| `BH_Walk_R` | 30 | 1.00s | Yes | Right strafe stride (1.2 m/s), position `(1, 0)` |
| `BH_Walk_FL` | 30 | 1.00s | Yes | Diagonal 45° forward-left walk, position `(-0.707, 0.707)` |
| `BH_Walk_FR` | 30 | 1.00s | Yes | Diagonal 45° forward-right walk, position `(0.707, 0.707)` |
| `BH_Walk_BL` | 30 | 1.00s | Yes | Diagonal 45° backward-left walk, position `(-0.707, -0.707)` |
| `BH_Walk_BR` | 30 | 1.00s | Yes | Diagonal 45° backward-right walk, position `(0.707, -0.707)` |
| `BH_Jog` | 24 | 0.80s | Yes | Moderate pace jog (3.2 m/s) with medium arm sweep |
| `BH_Run` | 20 | 0.67s | Yes | Athletic forward run (5.5 m/s), position `(0, 2)` |
| `BH_Sprint` | 16 | 0.53s | Yes | Full forward sprint (8.0 m/s), torso lean forward 12°, position `(0, 3)` |
| `BH_Run_FL` | 20 | 0.67s | Yes | Diagonal forward-left run, position `(-1.41, 1.41)` |
| `BH_Run_FR` | 20 | 0.67s | Yes | Diagonal forward-right run, position `(1.41, 1.41)` |
| `BH_Run_BL` | 20 | 0.67s | Yes | Diagonal backward-left run, position `(-1.41, -1.41)` |
| `BH_Run_BR` | 20 | 0.67s | Yes | Diagonal backward-right run, position `(1.41, -1.41)` |
| `BH_Walk_Start` | 15 | 0.50s | No | Push-off anticipation from standing idle into walk |
| `BH_Run_Start` | 15 | 0.50s | No | Explosive forward drive off rear foot into run |
| `BH_Walk_Stop` | 15 | 0.50s | No | Deceleration step & foot planting into idle |
| `BH_Run_Stop` | 20 | 0.67s | No | High-speed braking slide & stabilization into idle |
| `BH_Turn_L90` | 18 | 0.60s | No | 90° stationary turn left with foot pivot |
| `BH_Turn_R90` | 18 | 0.60s | No | 90° stationary turn right with foot pivot |
| `BH_Turn_180` | 24 | 0.80s | No | 180° quick pivot turnabout with opposite foot plant |
| `BH_Turn_L` | 15 | 0.50s | Yes | Continuous banking turn left while moving |
| `BH_Turn_R` | 15 | 0.50s | Yes | Continuous banking turn right while moving |

### 2.2 Locomotion Transitions
Smooth blending bridges connecting movement states to prevent pose popping:

| Transition Name | Frames | Blend Time | Description |
|---|---|---|---|
| `BH_Transition_Idle_To_Walk` | 12 | 0.15s | Weight transfer to lead foot into walk stride |
| `BH_Transition_Idle_To_Run` | 12 | 0.15s | Torso dip into forward propulsion |
| `BH_Transition_Walk_To_Run` | 10 | 0.12s | Arm swing widening and stride lengthening |
| `BH_Transition_Run_To_Sprint`| 10 | 0.10s | Aerodynamic forward spine pitch and knee drive |
| `BH_Transition_Sprint_To_Run`| 10 | 0.12s | Stride recovery and spine elevation |
| `BH_Transition_Run_To_Walk` | 12 | 0.15s | Deceleration damping |
| `BH_Transition_Walk_To_Idle`| 12 | 0.15s | Final step settling into resting stance |
| `BH_Transition_Run_To_Idle` | 15 | 0.20s | Rapid deceleration brace into resting stance |
| `BH_Transition_Sprint_To_Idle`| 18 | 0.25s | Skidding brace & recovery into resting stance |

### 2.3 Jump & Airborne System
A modular 8-part jump sequence with natural foot placement and physical weight:

| Animation Name | Frames | Looping | Purpose / Engine Integration |
|---|---|---|---|
| `BH_Jump_Start` | 12 | No | Crouch anticipation, arm wind-back, ground push-off (triggered on jump button down) |
| `BH_Jump_Rise` | 15 | Yes | Upward ascent pose with knees tucked, arms stabilizing (played while `velocity.y > 1.0`) |
| `BH_Jump_Apex` | 8 | No | Zero-gravity transition at jump crest (played while `abs(velocity.y) <= 1.0`) |
| `BH_Jump_Fall` | 15 | Yes | Aerodynamic downward descent with legs extending toward ground (`velocity.y < -1.0`) |
| `BH_Jump_Land` | 15 | No | Knee compression absorbing impact, returning to idle (triggered on `is_on_floor()`) |
| `BH_Jump_Land_Hard` | 24 | No | Deep squat impact recovery with hand touching ground (fall velocity > 12 m/s) |
| `BH_Jump_Running` | 20 | No | Hurdle-style forward momentum jump preserving horizontal velocity |
| `BH_Jump_Recovery` | 10 | No | Rapid return from landing compression to full run stride |

### 2.4 Crouch & Stealth System
| Animation Name | Frames | Looping | Purpose |
|---|---|---|---|
| `BH_Crouch_Enter` | 12 | No | Smooth drop from standing idle into low crouch |
| `BH_Crouch_Idle` | 60 | Yes | Low profile resting stance, lowered center of gravity, head alert |
| `BH_Crouch_Walk` | 30 | Yes | Low-noise crouch walk stride (1.8 m/s) |
| `BH_Crouch_Turn` | 18 | No | Compact pivoting turn while remaining crouched |
| `BH_Crouch_Exit` | 12 | No | Smooth rise from crouch back into standing idle |

### 2.5 Combat Foundation (Melee & Hit Reactions)
| Animation Name | Frames | Hit Window (Frames) | Description |
|---|---|---|---|
| `BH_Combat_Idle` | 60 | — | Guard raised, fists protecting jaw, weight centered on balls of feet |
| `BH_Punch_Light` | 14 | 4 – 8 | Rapid lead left jab with torso twist and instant recovery |
| `BH_Punch_Heavy` | 20 | 7 – 12 | Powerful right cross stepping into the punch with full hip drive |
| `BH_Kick` | 24 | 9 – 15 | Powerful forward front thrust kick driving through target |
| `BH_Dodge_L` | 16 | 2 – 10 | Quick evasive side-step dodge to the left with torso slip |
| `BH_Dodge_R` | 16 | 2 – 10 | Quick evasive side-step dodge to the right with torso slip |
| `BH_Dodge_B` | 16 | 2 – 10 | Backward hop / slip dodge out of strike range |
| `BH_Hit_F` | 12 | — | Head and chest snap backward from frontal impact |
| `BH_Hit_B` | 12 | — | Spine arch and forward stumble from hit to the back |
| `BH_Hit_L` | 12 | — | Lateral stagger right from left-flank strike |
| `BH_Hit_R` | 12 | — | Lateral stagger left from right-flank strike |
| `BH_Knockdown` | 28 | — | Collapse backward onto ground from heavy blow / explosion |
| `BH_Get_Up` | 32 | — | Push-up roll and rise back to combat-ready standing pose |

### 2.6 Weapon Foundation (Sidearm & Long Gun)
| Animation Name | Frames | Looping | Notes |
|---|---|---|---|
| `BH_Pistol_Idle` | 60 | Yes | Two-handed low-ready hold at center chest |
| `BH_Pistol_Aim` | 30 | Yes | Tactical two-handed eye-level sight alignment over shoulder |
| `BH_Pistol_Fire` | 10 | No | Snappy vertical recoil kick with wrist snap and arm reset |
| `BH_Pistol_Reload` | 45 | No | Mag drop (frame 12), fresh mag insert (frame 28), slide release (frame 38) |
| `BH_Rifle_Idle` | 60 | Yes | Long gun held low-ready with stock tucked against shoulder |
| `BH_Rifle_Aim` | 30 | Yes | Cheekweld on stock, forward arm supporting barrel |
| `BH_Rifle_Fire` | 8 | No | Shoulder-absorbing rifle impulse kick with minor muzzle rise |
| `BH_Rifle_Reload` | 55 | No | Rock-and-lock magazine swap with charging handle rack |
| `BH_Weapon_Equip` | 15 | No | Reach to holster/back, grasp weapon, present to ready |
| `BH_Weapon_Unequip` | 15 | No | Return weapon to holster/magnetic sling |

### 2.7 Interactions & Traversals
| Animation Name | Frames | Root Motion Required? | Notes |
|---|---|---|---|
| `BH_Interact_Pickup` | 24 | No | Reach down with right hand to collect ground object |
| `BH_Interact_Inspect`| 60 | No | Bring held item to eye level, rotate and examine |
| `BH_Interact_Door_Open` | 24 | No | Reach out, turn handle/push bar, push outward |
| `BH_Interact_Door_Close`| 24 | No | Grasp inner latch, pull inward toward player |
| `BH_Interact_Push` | 30 | Yes (Optional) | Braced two-hand forward shove against obstacle |
| `BH_Interact_Pull` | 30 | Yes (Optional) | Two-hand backward heave on heavy object |
| `BH_Interact_Climb` | 32 | Yes (Target) | Ledge grab, pull body upward, hoist knee onto surface |
| `BH_Interact_Vault` | 22 | Yes (Target) | Hand-plant on waist-high barricade and kick legs over |

### 2.8 Vehicle / Driving Operations
| Animation Name | Frames | Looping | Notes |
|---|---|---|---|
| `BH_Vehicle_Enter` | 36 | No (Root Motion) | Step into cabin, duck head under doorframe, settle into seat |
| `BH_Vehicle_Sit` | 60 | Yes | Relaxed sitting posture, back against seat rest |
| `BH_Vehicle_Steer` | 60 | Yes | Hands at 9 & 3 on steering wheel with responsive subtle steer movements |
| `BH_Vehicle_Look_L`| 30 | Yes | Turn head and upper torso 65° left toward driver side mirror |
| `BH_Vehicle_Look_R`| 30 | Yes | Turn head and upper torso 55° right toward passenger side mirror |
| `BH_Vehicle_Exit` | 36 | No (Root Motion) | Swing legs out of door, push off frame, stand upright |

---

## 3. Root Motion vs. In-Place Locomotion Architecture

### 3.1 Design Choice: In-Place Locomotion (Default)
For responsive third-person action games (especially on mobile touch controls):
- **Predictable Kinematics**: Player movement is driven by `CharacterBody3D.velocity` and `move_and_slide()`.
- **Zero Drift**: In-place loops have zero accumulated positional error over time.
- **Immediate Response**: Zero-latency turnaround without waiting for an animation turn cycle to finish.
- **Slope & Step Clamping**: Godot's floor snapping and wall sliding operate without fighting root bone offsets.

### 3.2 Animations Requiring Root Motion (Optional / Cinematic)
Only high-commitment physical interactions where the world position must match hand/foot contacts exactly require root motion:
1. `BH_Interact_Climb`: Vertical translation onto ledge.
2. `BH_Interact_Vault`: Forward arc over obstacle.
3. `BH_Vehicle_Enter` / `BH_Vehicle_Exit`: Precise cabin ingress/egress.

To enable root motion in Godot 4.3 for these specific animations:
```gdscript
# On AnimationTree:
@export var anim_tree: AnimationTree
anim_tree.root_motion_track = "Root:position"

func _physics_process(delta: float) -> void:
    if is_vaulting or is_climbing:
        var root_motion_delta = anim_tree.get_root_motion_position()
        var oriented_delta = global_transform.basis * root_motion_delta
        velocity = oriented_delta / delta
        move_and_slide()
```

---

## 4. Godot 4.3 AnimationTree & BlendSpace2D Setup

The optimal Godot setup uses an `AnimationTree` with an `AnimationNodeStateMachine` containing nested `AnimationNodeBlendSpace2D` and `AnimationNodeOneShot` blend layers.

### 4.1 Locomotion BlendSpace2D Structure
Create an `AnimationNodeBlendSpace2D` named `LocomotionBS2D`:
- **X Axis**: Strafe Direction `[-1.0 (Left), 1.0 (Right)]`
- **Y Axis**: Forward/Backward Speed `[-1.0 (Back), 0.0 (Idle), 1.0 (Walk), 2.0 (Run), 3.0 (Sprint)]`

```
                        (0, 3) BH_Sprint
                              |
                        (0, 2) BH_Run
                       /      |      \
(-1.41, 1.41) BH_Run_FL       |       (1.41, 1.41) BH_Run_FR
                              |
                        (0, 1) BH_Walk_F
                       /      |      \
(-0.707, 0.707) BH_Walk_FL    |       (0.707, 0.707) BH_Walk_FR
          |                   |                   |
(-1, 0) BH_Walk_L -------- (0, 0) BH_Idle -------- (1, 0) BH_Walk_R
          |                   |                   |
(-0.707, -0.707) BH_Walk_BL   |       (0.707, -0.707) BH_Walk_BR
                       \      |      /
                        (0, -1) BH_Walk_B
```

### 4.2 State Machine Transitions
Connect states in the root `AnimationNodeStateMachine`:
1. `Locomotion` ↔ `Jump` (Condition: `not is_on_floor()`, Switch Mode: Immediate, XFade: 0.1s)
2. `Jump_Start` → `Jump_Rise` → `Jump_Apex` → `Jump_Fall` → `Jump_Land` → `Locomotion`
3. `Locomotion` ↔ `Crouch` (Trigger: `crouch_toggled`, XFade: 0.15s)
4. Upper-Body OneShot Layer: `BH_Punch_Light`, `BH_Punch_Heavy`, `BH_Kick`, `BH_Pistol_Fire` can play on an upper-body avatar filter while preserving legs locomotion!

---

## 5. Godot 4.3 Import Settings Checklist

When reimporting `character.glb` in the Godot 4.3 FileSystem dock:
1. **Scene Tab**:
   - `Root Type`: `CharacterBody3D`
   - `Skeleton`: `Use Unique ID`
2. **Animation Tab**:
   - `FPS`: `30`
   - `Trim Keyframes`: `Enabled`
   - `Remove Immutable Tracks`: `Enabled`
   - `Optimizer`: `Enabled` (Linear tolerance `0.001`, Angle tolerance `0.002`)
3. **Materials Tab**:
   - Material locations set to `Export as Separate Objects` or internal PBR materials with mobile GLES3/Vulkan Mobile compatibility.
4. **Bone Names Compatibility**:
   - Rig bones strictly use standard names: `Hips`, `Spine`, `Spine1`, `Spine2`, `Neck`, `Head`, `LeftShoulder`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `RightShoulder`, `RightUpperArm`, `RightLowerArm`, `RightHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `RightUpperLeg`, `RightLowerLeg`, `RightFoot`.

---

## 6. Android-First Optimization Guidelines

Mobile devices have constrained memory bandwidth, fill rate, and thermals. Follow these rules:

1. **Track Pruning**:
   - No scale tracks: Humanoid bones never scale during gameplay. Pruning scale tracks saved 33% of animation memory.
   - No facial tracks on body clips: High-frequency morph targets or facial bone tracks should be kept in dedicated facial dialogue clips.
2. **Keyframe Reduction**:
   - Godot's animation optimizer drops intermediate linear keyframes automatically, reducing buffer size by ~60% with zero visible distortion.
3. **Animation LOD & Tick Rate**:
   - Player character: Evaluated every frame (`process_mode = PROCESS_MODE_INHERIT`).
   - Distant enemies / NPCs: Set `AnimationPlayer.callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` and tick at 15 FPS when beyond 15 meters to conserve mobile CPU cycles.
4. **Memory Footprint**:
   - Entire 113-action library compiles to just **2.19 MB** on disk and under **6.5 MB** in uncompressed VRAM.

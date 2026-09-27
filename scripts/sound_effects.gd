class_name SoundEffects
extends Node

## Procedural audio synthesizer and sound effects player for Broken Horizon.
## Generates 16-bit PCM audio streams at startup without external assets,
## including firearms, impacts, footsteps, reloads, pickups, and atmospheric ambient drone.

static var instance: SoundEffects

var sfx_gunshot: AudioStreamWAV
var sfx_bullet_impact: AudioStreamWAV
var sfx_punch_whoosh: AudioStreamWAV
var sfx_punch_impact: AudioStreamWAV
var sfx_footstep: AudioStreamWAV
var sfx_dry_fire: AudioStreamWAV
var sfx_reload: AudioStreamWAV
var sfx_pickup: AudioStreamWAV
var sfx_ambient_drone: AudioStreamWAV

# Global audio players
var player_2d: AudioStreamPlayer
var music_player: AudioStreamPlayer

func _init() -> void:
	instance = self
	_generate_all_sounds()

func _ready() -> void:
	player_2d = AudioStreamPlayer.new()
	player_2d.bus = "Master"
	add_child(player_2d)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -20.0
	add_child(music_player)
	
	if sfx_ambient_drone:
		music_player.stream = sfx_ambient_drone
		music_player.play()

func _generate_all_sounds() -> void:
	sfx_gunshot = _synth_gunshot()
	sfx_bullet_impact = _synth_bullet_impact()
	sfx_punch_whoosh = _synth_punch_whoosh()
	sfx_punch_impact = _synth_punch_impact()
	sfx_footstep = _synth_footstep()
	sfx_dry_fire = _synth_dry_fire()
	sfx_reload = _synth_reload()
	sfx_pickup = _synth_pickup()
	sfx_ambient_drone = _synth_ambient_drone()

static func play_gunshot(parent: Node = null) -> void:
	if instance and instance.sfx_gunshot:
		instance._play_2d(instance.sfx_gunshot, -4.0, randf_range(0.95, 1.05))

static func play_bullet_impact(parent: Node, pos: Vector3) -> void:
	if instance and instance.sfx_bullet_impact and parent:
		instance._play_3d(parent, instance.sfx_bullet_impact, pos, -2.0, randf_range(0.9, 1.1))

static func play_punch_whoosh(parent: Node = null) -> void:
	if instance and instance.sfx_punch_whoosh:
		instance._play_2d(instance.sfx_punch_whoosh, -6.0, randf_range(0.9, 1.15))

static func play_punch_impact(parent: Node, pos: Vector3) -> void:
	if instance and instance.sfx_punch_impact and parent:
		instance._play_3d(parent, instance.sfx_punch_impact, pos, 0.0, randf_range(0.9, 1.1))

static func play_footstep(parent: Node = null) -> void:
	if instance and instance.sfx_footstep:
		instance._play_2d(instance.sfx_footstep, -16.0, randf_range(0.85, 1.15))

static func play_dry_fire(parent: Node = null) -> void:
	if instance and instance.sfx_dry_fire:
		instance._play_2d(instance.sfx_dry_fire, -7.0, randf_range(0.95, 1.05))

static func play_reload(parent: Node = null) -> void:
	if instance and instance.sfx_reload:
		instance._play_2d(instance.sfx_reload, -5.0, 1.0)

static func play_pickup(parent: Node = null) -> void:
	if instance and instance.sfx_pickup:
		instance._play_2d(instance.sfx_pickup, -8.0, 1.0)

func _play_2d(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	if not player_2d:
		return
	player_2d.stream = stream
	player_2d.volume_db = volume_db
	player_2d.pitch_scale = pitch
	player_2d.play()

func _play_3d(parent: Node, stream: AudioStreamWAV, pos: Vector3, volume_db: float, pitch: float) -> void:
	var p3d := AudioStreamPlayer3D.new()
	p3d.stream = stream
	p3d.volume_db = volume_db
	p3d.pitch_scale = pitch
	p3d.position = pos
	p3d.max_distance = 35.0
	parent.add_child(p3d)
	p3d.play()
	
	var tree := parent.get_tree()
	if tree:
		var timer := tree.create_timer(stream.get_length() + 0.1)
		timer.timeout.connect(func(): if is_instance_valid(p3d): p3d.queue_free())

# --- AUDIO SYNTHESIS ALGORITHMS ---

func _create_stream(samples: PackedByteArray, rate: int = 22050, looping: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = samples
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size() / 2
	return stream

func _synth_gunshot() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.32
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var noise := randf_range(-1.0, 1.0) * exp(-t * 35.0)
		var freq: float = maxf(30.0, 95.0 - t * 240.0)
		var thump := sin(t * freq * TAU) * exp(-t * 18.0) * 0.9
		var echo := randf_range(-0.3, 0.3) * exp(-t * 8.0)
		
		var sample := clampf((noise * 0.8 + thump + echo), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_bullet_impact() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.14
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var ring := sin(t * 1900.0 * TAU) * exp(-t * 50.0) * 0.6
		var crack := randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.6
		
		var sample := clampf(ring + crack, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_punch_whoosh() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.16
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var env := sin((t / dur) * PI)
		var freq := 260.0 - (t / dur) * 160.0
		var tone := sin(t * freq * TAU) * 0.4
		var wind := randf_range(-0.5, 0.5) * 0.6
		
		var sample := clampf((tone + wind) * env * 0.8, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_punch_impact() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.20
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var freq: float = maxf(35.0, 140.0 - t * 500.0)
		var thud := sin(t * freq * TAU) * exp(-t * 22.0)
		var slap := randf_range(-0.9, 0.9) * exp(-t * 60.0)
		
		var sample := clampf(thud * 0.7 + slap * 0.6, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_footstep() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.08
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var thud := sin(t * 70.0 * TAU) * exp(-t * 40.0) * 0.5
		var scuff := randf_range(-0.6, 0.6) * exp(-t * 30.0) * 0.5
		
		var sample := clampf(thud + scuff, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_dry_fire() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.06
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var click := sin(t * 2200.0 * TAU) * exp(-t * 80.0) * 0.7
		var noise := randf_range(-0.4, 0.4) * exp(-t * 60.0)
		var sample := clampf(click + noise, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_reload() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.10
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		var sample: float = 0.0
		# Part 1: Mag Eject Click at t = 0.10s
		if t >= 0.10 and t < 0.22:
			var dt := t - 0.10
			sample += sin(dt * 800.0 * TAU) * exp(-dt * 45.0) * 0.6
		# Part 2: Mag Insert Snap at t = 0.60s
		if t >= 0.60 and t < 0.75:
			var dt := t - 0.60
			sample += sin(dt * 1200.0 * TAU) * exp(-dt * 55.0) * 0.7
			sample += randf_range(-0.3, 0.3) * exp(-dt * 30.0)
		# Part 3: Slide Rack Clack at t = 0.88s
		if t >= 0.88 and t < 1.05:
			var dt := t - 0.88
			sample += sin(dt * 1650.0 * TAU) * exp(-dt * 40.0) * 0.8
			sample += sin(dt * 600.0 * TAU) * exp(-dt * 30.0) * 0.5
		
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_pickup() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.32
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		# Two-tone ascending chime (587Hz D5 -> 880Hz A5)
		var freq := 587.3 if t < 0.12 else 880.0
		var tone := sin(t * freq * TAU) * exp(-t * 6.0) * 0.6
		var overtone := sin(t * freq * 2.0 * TAU) * exp(-t * 9.0) * 0.25
		var sample := clampf(tone + overtone, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate)

func _synth_ambient_drone() -> AudioStreamWAV:
	# 4.0-second seamless looping cinematic combat tension drone
	var rate := 22050
	var dur := 4.0
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in range(count):
		var t := float(i) / float(rate)
		# Fundamental deep drone (55Hz A1) + slightly detuned choir (55.4Hz)
		var sub := sin(t * 55.0 * TAU) * 0.45
		var sub_detune := sin(t * 55.5 * TAU) * 0.35
		# Mid harmonic warmth (110Hz A2) + pulsating slow LFO (0.25Hz)
		var lfo := 0.75 + 0.25 * sin(t * 0.25 * TAU)
		var mid := sin(t * 110.0 * TAU) * 0.25 * lfo
		# High ethereal air shimmer (220Hz + 330Hz)
		var high := (sin(t * 220.0 * TAU) * 0.1 + sin(t * 330.0 * TAU) * 0.08) * (1.0 - lfo * 0.3)
		
		# Smooth loop crossfade envelope at boundaries to guarantee zero clicks
		var edge_fade := 1.0
		var fade_len := 0.08
		if t < fade_len:
			edge_fade = t / fade_len
		elif t > dur - fade_len:
			edge_fade = (dur - t) / fade_len
		
		var sample := clampf((sub + sub_detune + mid + high) * edge_fade * 0.65, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return _create_stream(bytes, rate, true)

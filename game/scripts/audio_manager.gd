extends Node

class_name AudioManager

# Sound collections per theme:
# Theme 0 (Bubbles), Theme 1 (Ghosts), Theme 2 (Turkeys), Theme 3 (Snowmen)
var themed_streams: Dictionary = {}
var themed_mega_streams: Dictionary = {}

# Extra game sound streams
var zap_stream: AudioStreamWAV
var jump_pass_stream: AudioStreamWAV
var ding_stream: AudioStreamWAV
var tick_stream: AudioStreamWAV
var buzzer_stream: AudioStreamWAV
var fanfare_stream: AudioStreamWAV
var bounce_stream: AudioStreamWAV

var audio_players: Array[AudioStreamPlayer] = []
var max_polyphony: int = 12
var current_player_idx: int = 0

func _ready() -> void:
	_generate_procedural_sounds()
	
	# Pool audio players for rapid-fire sounds
	for i in range(max_polyphony):
		var p = AudioStreamPlayer.new()
		add_child(p)
		audio_players.append(p)

func _generate_procedural_sounds() -> void:
	# ==========================================================================
	# THEME 0: BUBBLE POPS (Classic downward cavitation sweep)
	# ==========================================================================
	var bubble_list: Array[AudioStreamWAV] = []
	for f in [650.0, 750.0, 880.0, 980.0, 1100.0]:
		bubble_list.append(_synthesize_sweep(f, f * 0.22, 0.08, 0.85, 2.5))
	themed_streams[0] = bubble_list
	themed_mega_streams[0] = _synthesize_sweep(380.0, 100.0, 0.16, 1.0, 2.2)

	# ==========================================================================
	# THEME 1: GHOST SOUNDS (Cute spooky pitch slide with vibrato "wooo!")
	# ==========================================================================
	var ghost_list: Array[AudioStreamWAV] = []
	for base_f in [380.0, 440.0, 520.0, 580.0]:
		ghost_list.append(_synthesize_ghost_sound(base_f, 0.12, 0.85))
	themed_streams[1] = ghost_list
	themed_mega_streams[1] = _synthesize_ghost_sound(260.0, 0.24, 1.0, true)

	# ==========================================================================
	# THEME 2: TURKEY GOBBLES (Comical cartoon bounce / gobble chirp)
	# ==========================================================================
	var turkey_list: Array[AudioStreamWAV] = []
	for base_f in [320.0, 360.0, 420.0, 480.0]:
		turkey_list.append(_synthesize_turkey_sound(base_f, 0.11, 0.9))
	themed_streams[2] = turkey_list
	themed_mega_streams[2] = _synthesize_turkey_sound(220.0, 0.22, 1.0, true)

	# ==========================================================================
	# THEME 3: SNOWMAN CHIMES (Crisp crystalline holiday bell chime)
	# ==========================================================================
	var snowman_list: Array[AudioStreamWAV] = []
	for base_f in [880.0, 1046.0, 1174.0, 1318.0]:
		snowman_list.append(_synthesize_bell_chime(base_f, 0.16, 0.8))
	themed_streams[3] = snowman_list
	themed_mega_streams[3] = _synthesize_bell_chime(523.0, 0.32, 1.0, true)

	# ==========================================================================
	# GAMEPLAY SFX FOR LINE JUMPER, CIRCLE SCRAMBLE & SPEED RUSH
	# ==========================================================================
	zap_stream = _synthesize_zap()
	jump_pass_stream = _synthesize_jump_pass()
	ding_stream = _synthesize_ding()
	tick_stream = _synthesize_tick()
	buzzer_stream = _synthesize_buzzer()
	fanfare_stream = _synthesize_fanfare()
	bounce_stream = _synthesize_bounce()

# Simple frequency sweep (Bubbles)
func _synthesize_sweep(start_freq: float, end_freq: float, duration: float, volume: float, decay_power: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var current_freq = lerpf(start_freq, end_freq, pow(t, 0.6))
		var envelope = pow(1.0 - t, decay_power) * volume
		phase += (TAU * current_freq) / sample_rate
		var sample = sin(phase) * envelope
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Spooky playful ghost sound
func _synthesize_ghost_sound(start_freq: float, duration: float, volume: float, is_mega: bool = false) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var vibrato = sin(TAU * 14.0 * t) * (start_freq * 0.15)
		var current_freq = lerpf(start_freq, start_freq * 1.5, t) + vibrato
		var envelope = sin(t * PI) * volume
		phase += (TAU * current_freq) / sample_rate
		var sample = (sin(phase) * 0.75 + sin(phase * 2.0) * 0.25) * envelope
		if is_mega:
			sample = (sin(phase) * 0.6 + sin(phase * 0.5) * 0.4) * envelope
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Comical bouncy turkey gobble
func _synthesize_turkey_sound(base_freq: float, duration: float, volume: float, is_mega: bool = false) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var gobble = sin(TAU * 28.0 * t) * (base_freq * 0.35)
		var current_freq = base_freq + gobble - (t * 80.0)
		var envelope = pow(1.0 - t, 1.8) * volume
		phase += (TAU * current_freq) / sample_rate
		var sample = (sin(phase) + 0.3 * sin(phase * 3.0)) * 0.7 * envelope
		if is_mega:
			sample = sin(phase) * envelope
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Festive winter crystal chime
func _synthesize_bell_chime(base_freq: float, duration: float, volume: float, is_mega: bool = false) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase1 = 0.0
	var phase2 = 0.0
	var phase3 = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var envelope = pow(1.0 - t, 2.8) * volume
		
		phase1 += (TAU * base_freq) / sample_rate
		phase2 += (TAU * (base_freq * 1.2599)) / sample_rate # Major 3rd
		phase3 += (TAU * (base_freq * 1.4983)) / sample_rate # Perfect 5th
		
		var sample = (sin(phase1) * 0.5 + sin(phase2) * 0.3 + sin(phase3) * 0.2) * envelope
		if is_mega:
			sample = (sin(phase1 * 0.5) * 0.4 + sin(phase1) * 0.4 + sin(phase2) * 0.2) * envelope
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Electric zap / shock sound for Line Jumper contact
func _synthesize_zap() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.22
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		# Rapid descending frequency with buzzing square-wave distortion and noise
		var freq = lerpf(340.0, 75.0, pow(t, 0.4))
		var envelope = pow(1.0 - t, 1.5) * 0.95
		phase += (TAU * freq) / sample_rate
		# Mix harsh square wave + white noise crackle
		var square = 1.0 if sin(phase) > 0.0 else -1.0
		var noise = randf_range(-0.35, 0.35)
		var sample = (square * 0.65 + noise) * envelope
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Upward whoosh / chirp for successful jump pass
func _synthesize_jump_pass() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.18
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerpf(260.0, 720.0, t)
		var envelope = sin(t * PI) * 0.85
		phase += (TAU * freq) / sample_rate
		var sample = sin(phase) * envelope
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Bright crystal ding for circle claim
func _synthesize_ding() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.25
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var p1 = 0.0
	var p2 = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var env = pow(1.0 - t, 2.5) * 0.85
		p1 += (TAU * 1250.0) / sample_rate
		p2 += (TAU * 2500.0) / sample_rate
		var sample = (sin(p1) * 0.7 + sin(p2) * 0.3) * env
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Clock tick for countdown
func _synthesize_tick() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.04
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var env = pow(1.0 - t, 4.0) * 0.7
		phase += (TAU * 950.0) / sample_rate
		var sample = sin(phase) * env
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Low buzzer for timeout / game over
func _synthesize_buzzer() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.35
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		# Pulse 2 bursts
		var gate = 1.0 if (t < 0.45 or t > 0.55) else 0.0
		var env = (1.0 - t * 0.4) * gate * 0.85
		phase += (TAU * 130.0) / sample_rate
		var square = 1.0 if sin(phase) > 0.0 else -1.0
		var sample = square * env
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Celebration fanfare chord
func _synthesize_fanfare() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.45
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var p1 = 0.0
	var p2 = 0.0
	var p3 = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		# Arpeggio frequencies: C5 (523Hz), E5 (659Hz), G5 (784Hz), C6 (1046Hz)
		var f1 = 523.25
		if t > 0.12: f1 = 659.25
		if t > 0.24: f1 = 784.0
		if t > 0.34: f1 = 1046.5
		
		p1 += (TAU * f1) / sample_rate
		p2 += (TAU * (f1 * 1.5)) / sample_rate
		p3 += (TAU * (f1 * 2.0)) / sample_rate
		
		var env = pow(1.0 - t, 1.2) * 0.85
		var sample = (sin(p1) * 0.6 + sin(p2) * 0.25 + sin(p3) * 0.15) * env
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

# Bouncy spring sound for wall ricochets
func _synthesize_bounce() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.09
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerpf(180.0, 480.0, pow(t, 0.4))
		var env = pow(1.0 - t, 2.0) * 0.65
		phase += (TAU * freq) / sample_rate
		var sample = sin(phase) * env
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

func play_pop(is_mega: bool = false, theme_id: int = 0) -> void:
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	var theme_key = clamp(theme_id, 0, 3)
	
	if is_mega and themed_mega_streams.has(theme_key):
		player.stream = themed_mega_streams[theme_key]
		player.volume_db = 2.0
	elif themed_streams.has(theme_key):
		var list = themed_streams[theme_key] as Array[AudioStreamWAV]
		player.stream = list.pick_random()
		player.volume_db = randf_range(-1.5, 1.0)
	else:
		player.stream = themed_streams[0].pick_random()
		player.volume_db = 0.0
	player.play()

func play_zap() -> void:
	if not zap_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = zap_stream
	player.volume_db = 1.5
	player.play()

func play_jump_pass() -> void:
	if not jump_pass_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = jump_pass_stream
	player.volume_db = 0.0
	player.play()

func play_ding() -> void:
	if not ding_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = ding_stream
	player.volume_db = 1.0
	player.play()

func play_tick() -> void:
	if not tick_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = tick_stream
	player.volume_db = -2.0
	player.play()

func play_buzzer() -> void:
	if not buzzer_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = buzzer_stream
	player.volume_db = 2.0
	player.play()

func play_fanfare() -> void:
	if not fanfare_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = fanfare_stream
	player.volume_db = 1.5
	player.play()

func play_bounce() -> void:
	if not bounce_stream: return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	player.stream = bounce_stream
	player.volume_db = -1.0
	player.play()

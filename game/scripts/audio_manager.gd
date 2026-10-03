extends Node

class_name AudioManager

var pop_streams: Array[AudioStreamWAV] = []
var mega_pop_stream: AudioStreamWAV

var audio_players: Array[AudioStreamPlayer] = []
var max_polyphony: int = 8
var current_player_idx: int = 0

func _ready() -> void:
	_generate_procedural_sounds()
	
	# Pool audio players for snappy rapid-fire pops
	for i in range(max_polyphony):
		var p = AudioStreamPlayer.new()
		add_child(p)
		audio_players.append(p)

func _generate_procedural_sounds() -> void:
	# Generate 5 pitched variations of the classic bubble pop
	var base_freqs = [650.0, 750.0, 880.0, 980.0, 1100.0]
	for f in base_freqs:
		pop_streams.append(_synthesize_pop(f, 0.08, 0.8))
	
	# Giant bubble pop (lower, resonant)
	mega_pop_stream = _synthesize_pop(380.0, 0.16, 1.0)

func _synthesize_pop(start_freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var byte_array = PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		
		# Downward frequency sweep (simulates bubble cavitation)
		var current_freq = lerpf(start_freq, start_freq * 0.22, pow(t, 0.6))
		
		# Fast exponential decay envelope
		var envelope = pow(1.0 - t, 2.5) * volume
		
		# Sine wave
		phase += (TAU * current_freq) / sample_rate
		var sample = sin(phase) * envelope
		
		# Convert to 16-bit signed integer (-32768 to 32767)
		var int_sample = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		byte_array.encode_s16(i * 2, int_sample)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_array
	return stream

func play_pop(is_mega: bool = false) -> void:
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_polyphony
	
	if is_mega:
		player.stream = mega_pop_stream
		player.volume_db = 2.0
	else:
		player.stream = pop_streams.pick_random()
		player.volume_db = randf_range(-1.5, 1.0)
		
	player.play()

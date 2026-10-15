extends AudioStreamPlayer
## One local original WAV. Microphone never connects to this output.
var settings: Dictionary
var fade: Tween
var transitions := 0

func configure(options: Dictionary) -> void:
	settings = options
	var wav: AudioStreamWAV = load(settings.path)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	stream = wav
	volume_db = settings.volume_db

func set_opponent_turn(active: bool) -> void:
	if active == playing:
		return
	transitions += 1
	if fade and fade.is_valid():
		fade.kill()
	if not active:
		# Immediate stop, including results/errors/Reset. No tail enters player input.
		stop()
		return
	volume_db = -60
	play()
	var duration: float = App.config.data.stands_gameplay.timing.speaker_fade_ms / 1000.0
	if duration <= 0:
		volume_db = settings.volume_db
	else:
		fade = create_tween()
		fade.tween_property(self, "volume_db", settings.volume_db, duration)

func _exit_tree() -> void:
	if fade and fade.is_valid():
		fade.kill()
	stop()

extends SceneTree

const Detector = preload("res://scripts/voice/voice_detector.gd")
const Factory = preload("res://scripts/voice/voice_input_factory.gd")
var checks := 0
var failures := 0
var clock_ms := 0
var config: Dictionary

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func advance(detector: RefCounted, rms: float, count: int = 1, allowed: bool = true) -> RefCounted:
	var frame: RefCounted
	for i in count:
		clock_ms += 20
		frame = detector.sample(rms, rms, clock_ms, 0.02, allowed)
	return frame

func _run() -> void:
	config = root.get_node("App").config.data.gameplay
	var detector = Detector.new(config.microphone, config.kick)
	var frame = advance(detector, 0.005, 50)
	check(frame.rolling_intensity == 0 and frame.kick_impulse_strength == 0, "Background noise does not control the ball")
	check(detector.noise_floor > config.microphone.noiseFloorMinRms, "Automatic background estimate adapts without UI")
	frame = advance(detector, 0.04, 30)
	check(frame.normalized_loudness > 0.14 and frame.normalized_loudness < 0.52, "Quiet voice normalizes into configured band")
	check(frame.rolling_intensity > 0, "Sustained quiet voice produces rolling intensity")
	var before: float = detector.noise_floor
	frame = advance(detector, 0.04, 300)
	check(frame.rolling_intensity > 0 and is_equal_approx(before, detector.noise_floor), "Background tracking never absorbs held quiet speech")
	frame = advance(detector, 0, 20)
	check(frame.rolling_intensity == 0 and frame.normalized_loudness < 0.02, "Silence returns control and meter to zero")
	frame = advance(detector, 0.12)
	check(frame.kick_impulse_strength > 0, "A sharp loud attack produces one kick")
	var repeats := 0
	for i in 100:
		if advance(detector, 0.12).kick_impulse_strength > 0:
			repeats += 1
	check(repeats == 0, "Holding a loud sound cannot repeat kicks")
	advance(detector, 0, 10)
	frame = advance(detector, 0.12)
	check(frame.kick_impulse_strength > 0, "A released, fresh attack works after cooldown")
	advance(detector, 0)
	frame = advance(detector, 0.12)
	check(frame.kick_impulse_strength == 0, "Cooldown rejects closely repeated attacks")
	advance(detector, 0, 30)
	frame = advance(detector, 0.12)
	check(frame.kick_impulse_strength > 0, "Control rearms after release and cooldown")
	frame = advance(detector, 0.12, 50, false)
	check(frame.kick_impulse_strength == 0 and frame.rolling_intensity == 0, "Overlays gate all control fields")
	frame = advance(detector, 0.12, 10)
	check(frame.kick_impulse_strength == 0, "Closing overlay does not convert stale sound into a kick")
	advance(detector, 0, 20)
	frame = advance(detector, 0.12)
	check(frame.kick_impulse_strength > 0, "A new attack works after the overlay")
	frame = advance(detector, NAN)
	check(is_finite(frame.normalized_loudness), "Invalid input cannot poison the detector")
	frame = advance(detector, 1, 5)
	check(frame.normalized_loudness <= 1 and frame.normalized_loudness >= 0, "Loudness is clamped to 0..1")
	check(frame.timestamp_ms == clock_ms, "Frame retains monotonic source timestamp")
	var fresh = Detector.new(config.microphone, config.kick)
	frame = advance(fresh, 0.04)
	check(frame.rolling_intensity == 0, "A single short quiet sample is not sustained rolling")
	var opt_in := "--voice-debug" in OS.get_cmdline_user_args()
	check(Factory.debug_enabled(config) == opt_in, "Native debug requires the explicit command-line opt-in")
	var input = Factory.create(config)
	check(input.get_script().resource_path.ends_with("debug_voice_input.gd" if opt_in else "browser_voice_input.gd"), "No automatic keyboard fallback")
	input.dispose()
	var disabled := config.duplicate(true)
	disabled.options.keyboardDebugModeAllowed = false
	check(not Factory.debug_enabled(disabled), "Configuration can disable debug input even with opt-in")
	print("Voice detector checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)

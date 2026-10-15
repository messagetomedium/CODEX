extends RefCounted
## Authoritative depth and flight state. No rendering, microphone or randomness.

var progress := 0.0
var flight_fraction := 0.0
var flight_arc := 0.0
var flying := false
var has_moved := false
var roll_speed := 0.0
var flight_start := 0.0
var flight_distance := 0.0
var flight_seconds := 0.0
var settings: Dictionary

func _init(config: Dictionary) -> void:
	settings = config
	progress = float(settings.ball.progressAtStart)

func kick(strength: float) -> void:
	if flying or strength <= 0:
		return
	strength = clampf(strength, 0, 1)
	flying = true
	flight_fraction = 0
	flight_start = progress
	flight_distance = lerpf(settings.kick.minTravelProgress, settings.kick.maxTravelProgress, strength)
	flight_seconds = lerpf(settings.kick.minFlightMs, settings.kick.maxFlightMs, strength) / 1000.0
	flight_arc = lerpf(settings.kick.arcVisualPixelsMin, settings.kick.arcVisualPixelsMax, strength)
	roll_speed = 0

func advance(delta: float, rolling: float) -> void:
	var previous := progress
	if flying:
		flight_fraction = minf(1, flight_fraction + delta / flight_seconds)
		progress = flight_start + flight_distance * flight_fraction
		if flight_fraction >= 1:
			flying = false
			flight_arc = 0
	else:
		var old_speed := roll_speed
		if rolling > 0:
			var fast_speed := minf(settings.ball.rollingMaxProgressPerSecond, (settings.ball.progressAtGoalLine - settings.ball.progressAtStart) / settings.ball.rollingTargetTravelSecondsAtFastQuietVoice)
			roll_speed = lerpf(settings.ball.rollingMinProgressPerSecond, fast_speed, clampf(rolling, 0, 1))
			progress += roll_speed * delta
		else:
			var stopping_seconds: float = settings.ball.stopInertiaMs / 1000.0
			var deceleration: float = settings.ball.rollingMaxProgressPerSecond / maxf(stopping_seconds, 0.000001)
			var moving_seconds := minf(delta, old_speed / deceleration)
			roll_speed = maxf(0, old_speed - deceleration * delta) if stopping_seconds > 0 else 0.0
			if stopping_seconds > 0:
				progress += old_speed * moving_seconds - deceleration * moving_seconds * moving_seconds / 2
	has_moved = has_moved or progress > previous

func height() -> float:
	return flight_arc * sin(PI * flight_fraction) if flying else 0.0

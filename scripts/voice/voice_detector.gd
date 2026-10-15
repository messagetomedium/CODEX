extends RefCounted
## Automatic noise floor, quiet sustain and attack/release detection; no game state.

const VoiceFrame = preload("res://scripts/voice/voice_frame.gd")
var settings: Dictionary
var cooldown_ms: float
var noise_floor: float
var loudness := 0.0
var elapsed_ms := 0.0
var quiet_ms := 0.0
var previous_level := 0.0
var armed := false
var last_kick_ms := -1000000000

func _init(options: Dictionary, kick_settings: Dictionary) -> void:
	settings = options
	cooldown_ms = float(kick_settings.cooldownMs)
	noise_floor = float(settings.noiseFloorMinRms)

func reset_controls() -> void:
	armed = false
	quiet_ms = 0.0
	previous_level = 1.0

func sample(rms: float, _peak: float, timestamp_ms: int, delta: float, allow_controls: bool) -> RefCounted:
	var frame := VoiceFrame.new()
	frame.timestamp_ms = timestamp_ms
	if not is_finite(rms):
		rms = 0.0
	rms = clampf(rms, 0.0, 1.0)
	elapsed_ms += maxf(0, delta) * 1000.0
	var gate := noise_floor * float(settings.noiseGateMultiplier)
	var level := clampf((rms - gate) / maxf(0.0001, float(settings.referenceRms) - gate), 0, 1)
	if settings.backgroundTracking:
		var calibrating := elapsed_ms <= float(settings.calibrationBackgroundMs)
		# Track only likely noise, so a held voice is not gradually swallowed.
		if level < float(settings.quietVoiceMinNormalized) or (calibrating and rms <= float(settings.calibrationMaxRms)):
			var target := clampf(rms, settings.noiseFloorMinRms, settings.maxNoiseFloorRms)
			var tracking_ms := float(settings.noiseRiseMs if target > noise_floor else settings.noiseFallMs)
			if calibrating:
				tracking_ms = float(settings.calibrationBackgroundMs)
			noise_floor = lerpf(noise_floor, target, _blend(delta, tracking_ms))
	loudness = lerpf(loudness, level, _blend(delta, float(settings.smoothingMs)))
	frame.normalized_loudness = loudness
	if not allow_controls:
		reset_controls()
		previous_level = level
		return frame
	if level <= float(settings.impulseReleaseThresholdNormalized):
		armed = true
	if armed and level >= float(settings.kickLevelMinNormalized) and level - previous_level >= float(settings.kickAttackDeltaNormalized) and timestamp_ms - last_kick_ms >= cooldown_ms:
		frame.kick_impulse_strength = maxf(0.01, (level - float(settings.kickLevelMinNormalized)) / (1.0 - float(settings.kickLevelMinNormalized)))
		last_kick_ms = timestamp_ms
		armed = false
	previous_level = level
	if loudness >= float(settings.quietVoiceMinNormalized) and loudness <= float(settings.quietVoiceMaxNormalized):
		quiet_ms += maxf(0, delta) * 1000.0
		if quiet_ms >= float(settings.rollingHoldMs):
			frame.rolling_intensity = clampf((loudness - float(settings.quietVoiceMinNormalized)) / (float(settings.quietVoiceMaxNormalized) - float(settings.quietVoiceMinNormalized)), 0, 1)
	else:
		quiet_ms = 0.0
	return frame

func _blend(delta: float, duration_ms: float) -> float:
	return 1.0 if duration_ms <= 0 else 1.0 - exp(-maxf(0, delta) * 1000.0 / duration_ms)

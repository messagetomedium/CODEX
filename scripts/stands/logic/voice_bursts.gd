extends RefCounted
## Separate rising bursts with release hysteresis; held shouting is one peak.
var threshold: float
var release: float
var gap: float
var armed := false
var last_at := -1000.0

func _init(microphone: Dictionary, input: Dictionary) -> void:
	threshold = input.get("peak_threshold_normalized",microphone.kickLevelMinNormalized)
	release = microphone.impulseReleaseThresholdNormalized
	gap = input.distinct_peak_min_gap_ms / 1000.0

func reset() -> void:
	armed = false

func sample(level: float, seconds: float) -> bool:
	if level <= release:
		armed = true
	if armed and level >= threshold:
		armed = false
		if seconds - last_at + 0.000000001 >= gap:
			last_at = seconds
			return true
	return false

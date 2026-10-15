extends RefCounted
## Random scheduling is outside deterministic simulation, and advances only in play.

var settings: Dictionary
var rng := RandomNumberGenerator.new()
var wait_seconds := 0.0
var waiting_for_exit := false

func _init(config: Dictionary) -> void:
	settings = config.defender
	rng.randomize()

func step(delta: float, simulation: RefCounted) -> void:
	if not simulation.outcome.is_empty():
		return
	if simulation.defender_active:
		waiting_for_exit = true
		return
	if waiting_for_exit:
		wait_seconds = rng.randf_range(settings.respawnGapMsMin, settings.respawnGapMsMax) / 1000.0
		waiting_for_exit = false
		return
	wait_seconds -= delta
	if wait_seconds <= 0:
		var direction := -1 if settings.allowEitherDirection and rng.randi_range(0, 1) == 0 else 1
		simulation.spawn_defender(direction, rng.randf_range(settings.laneYNormalizedMin, settings.laneYNormalizedMax))
		waiting_for_exit = true

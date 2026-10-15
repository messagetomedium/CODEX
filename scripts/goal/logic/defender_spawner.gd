extends RefCounted
## Independent slot timers allow simultaneous, opposing crossings on distinct lanes.
var settings: Dictionary
var rng := RandomNumberGenerator.new()
var wait_seconds := 0.0
var wait_timers: Array[float] = []
var waiting_for_exit: Array[bool] = []
var first_direction := 1

func _init(config: Dictionary) -> void:
	settings = config.defender
	rng.randomize()
	first_direction = -1 if settings.allowEitherDirection and rng.randi_range(0, 1) == 0 else 1
	for i in int(settings.maxSimultaneous):
		wait_timers.append(0)
		waiting_for_exit.append(false)

func step(delta: float, simulation: RefCounted) -> void:
	if not simulation.outcome.is_empty():
		return
	if wait_seconds > 0:
		wait_seconds = maxf(0, wait_seconds - delta)
		return
	for i in simulation.defenders.size():
		if simulation.defenders[i].active:
			waiting_for_exit[i] = true
			continue
		if waiting_for_exit[i]:
			wait_timers[i] = rng.randf_range(settings.respawnGapMsMin, settings.respawnGapMsMax) / 1000.0
			waiting_for_exit[i] = false
			continue
		wait_timers[i] -= maxf(0, delta)
		if wait_timers[i] > 0:
			continue
		var available: Array[float] = []
		for lane in settings.lanes:
			var free := true
			for body in simulation.defenders:
				if body.active and absf(float(body.y) - float(lane)) < settings.minimumLaneSeparation:
					free = false
			if free:
				available.append(float(lane))
		if available.is_empty():
			continue
		var direction := first_direction * (1 if i % 2 == 0 else -1)
		if simulation.spawn_defender(direction, available[rng.randi_range(0, available.size() - 1)], i):
			waiting_for_exit[i] = true

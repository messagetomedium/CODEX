extends RefCounted
## Monotonic session time, excluding error/result overlays; no accumulating dt.
var origin_ms := 0
var paused_ms := 0
var paused_at := 0
var running := false
var started := false

func start(now_ms: int) -> void:
	origin_ms = now_ms
	paused_ms = 0
	paused_at = now_ms
	running = true
	started = true

func seconds(now_ms: int) -> float:
	if not started:
		return 0.0
	return maxf(0, ((now_ms if running else paused_at) - origin_ms - paused_ms) / 1000.0)

func pause(now_ms: int) -> void:
	if running:
		paused_at = now_ms
		running = false

func resume(now_ms: int) -> void:
	if started and not running:
		paused_ms += now_ms - paused_at
		running = true

extends RefCounted
## Raw source contract; BrowserVoiceInput and DebugVoiceInput share it.

var status := "idle"
var error_code := ""

func start() -> void:
	status = "error"
	error_code = "unsupported"

func poll() -> Dictionary:
	return {"status": status, "errorCode": error_code, "rms": 0.0, "peak": 0.0, "timestamp": Time.get_ticks_msec()}

func stop() -> void:
	status = "idle"
	error_code = ""

func dispose() -> void:
	stop()

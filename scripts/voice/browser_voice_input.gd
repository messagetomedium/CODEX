extends "res://scripts/voice/voice_input.gd"

var options: Dictionary
var bridge: JavaScriptObject

func _init(settings: Dictionary) -> void:
	options = settings

func start() -> void:
	if not OS.has_feature("web"):
		status = "error"
		error_code = "native"
		return
	if bridge == null:
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/microphone_bridge.js"), true)
		bridge = JavaScriptBridge.get_interface("MatryoshkaMic")
	if bridge == null:
		status = "error"
		error_code = "unsupported"
		return
	bridge.start(float(options.rmsWindowMs))
	status = str(bridge.status)

func poll() -> Dictionary:
	if bridge == null:
		return super.poll()
	var raw: JavaScriptObject = bridge.sample()
	status = str(raw.status)
	error_code = str(raw.errorCode)
	return {"status": status, "errorCode": error_code, "rms": float(raw.rms), "peak": float(raw.peak), "timestamp": int(raw.timestamp)}

func stop() -> void:
	if bridge != null:
		bridge.stop()
	super.stop()

func dispose() -> void:
	if bridge != null:
		bridge.dispose()
		bridge = null
	super.stop()

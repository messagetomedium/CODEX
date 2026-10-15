extends "res://scripts/voice/voice_input.gd"
## Only constructed after an explicit ?debug=1 or local --voice-debug opt-in.

var settings: Dictionary
var strength_index := 1

func _init(options: Dictionary) -> void:
	settings = options

func start() -> void:
	status = "active"
	error_code = ""

func poll() -> Dictionary:
	var raw := super.poll()
	if status != "active":
		return raw
	for i in settings.keyboardStrengthKeys.size():
		if Input.is_physical_key_pressed(OS.find_keycode_from_string(settings.keyboardStrengthKeys[i])):
			strength_index = i
	var rms := 0.0
	if Input.is_physical_key_pressed(OS.find_keycode_from_string(settings.keyboardKickKey)):
		rms = float(settings.kickRms[strength_index])
	elif Input.is_physical_key_pressed(OS.find_keycode_from_string(settings.keyboardRollKey)):
		rms = float(settings.quietRms)
	raw.rms = rms
	raw.peak = rms
	return raw

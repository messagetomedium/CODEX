extends RefCounted
## Loads local/PCK data only. No HTTP paths or dependency on final art.

var data: Dictionary = {}
var errors: Array[String] = []

func load_all() -> bool:
	for key in ["ui.ru", "ui_layout", "ui_animations", "gameplay", "asset_manifest"]:
		var path := "res://data/config/%s.json" % key
		var json := JSON.new()
		if not FileAccess.file_exists(path):
			errors.append("Missing configuration: " + path)
			continue
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
			errors.append("Invalid configuration: " + path + " " + json.get_error_message())
			continue
		data[key] = json.data
	if not errors.is_empty():
		return false
	for entry in [["ui.ru", "menu"], ["ui.ru", "common"], ["ui.ru", "goal"],
		["ui_layout", "positions"], ["ui_layout", "components"],
		["ui_animations", "profiles"], ["gameplay", "round"]]:
		if not data[entry[0]].get(entry[1]) is Dictionary:
			errors.append("Missing configuration object: %s.%s" % entry)
	if not errors.is_empty():
		return false
	var rules: Dictionary = data.gameplay.round
	if rules.get("goalTarget") != 3 or rules.get("maxAttempts") != 6 or rules.get("number") != 1:
		errors.append("Expected 3 goals / 6 attempts / round 1")
	return errors.is_empty()

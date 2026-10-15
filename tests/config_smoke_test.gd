extends SceneTree
## Minimal build-time smoke test. Exit code is nonzero when the config is invalid.

func _init() -> void:
	var files: Array[String] = [
		"res://data/config/ui.ru.json",
		"res://data/config/ui_animations.json",
		"res://data/config/ui_layout.json",
		"res://data/config/gameplay.json",
		"res://data/config/asset_manifest.json",
		"res://data/config/stands_gameplay.json",
		"res://data/config/stands_teams.json",
		"res://data/config/stands_assets.json",
		"res://data/config/stands_layout.json",
		"res://data/config/commentator_gameplay.json",
		"res://data/config/commentator_levels.json",
		"res://data/config/commentator_layout.json",
	]
	var loaded: Dictionary = {}
	for file_path in files:
		if not FileAccess.file_exists(file_path):
			push_error("Missing config: " + file_path)
			quit(1)
			return
		var json := JSON.new()
		var parse_status := json.parse(FileAccess.get_file_as_string(file_path))
		if parse_status != OK or not (json.data is Dictionary):
			push_error("Invalid JSON: " + file_path + " -> " + json.get_error_message())
			quit(1)
			return
		loaded[file_path] = json.data
	var gameplay: Dictionary = loaded["res://data/config/gameplay.json"]
	var round_cfg: Dictionary = gameplay.get("round", {})
	if round_cfg.get("goalTarget", -1) != 3 or round_cfg.get("maxAttempts", -1) != 6 or round_cfg.get("number", -1) != 1:
		push_error("Expected goalTarget=3, maxAttempts=6, round=1")
		quit(1)
		return
	print("Godot config smoke test OK: ", files.size(), " JSON files, 3 goals / 6 attempts / round 1")
	quit(0)

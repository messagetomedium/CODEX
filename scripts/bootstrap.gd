extends Control
## Temporary start scene to verify the Web build pipeline before the first Codex task.
## Replace this scene with the actual main menu when Task 1 is implemented.

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#142a3b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var text := Label.new()
	text.text = "Стартовый проект Godot готов.\nСледующий шаг — Codex: главное меню и blockout поля."
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 34)
	center.add_child(text)

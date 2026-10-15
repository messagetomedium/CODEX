extends Control
## Marker positions come from the same thresholds as VoiceDetector.
const UI = preload("res://scripts/ui/ui_factory.gd")
var thresholds: Array[float] = []
var track_height := 0.0
var layout: Dictionary

func configure(microphone: Dictionary, guide_layout: Dictionary, bar_height: float) -> void:
	layout = guide_layout
	track_height = bar_height
	thresholds = [float(microphone.quietVoiceMinNormalized), float(microphone.quietVoiceMaxNormalized), float(microphone.kickLevelMinNormalized)]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var legend_y: float = App.design_size.y * layout.legendY
	var legend_height: float = App.design_size.y * layout.legendHeight
	UI.label(self, App.texts.text("goal.hud.quietRange"), Rect2(size.x * thresholds[0], legend_y, size.x * (thresholds[1] - thresholds[0]), legend_height), layout.fontSize, UI.PAPER)
	UI.label(self, App.texts.text("goal.hud.kickRange"), Rect2(size.x * thresholds[2], legend_y, size.x * (1 - thresholds[2]), legend_height), layout.fontSize, UI.PAPER)
	App.animations.play(self, "hud.voiceGuide")
	queue_redraw()

func _draw() -> void:
	if thresholds.is_empty():
		return
	for value in thresholds:
		var x := size.x * value
		draw_line(Vector2(x, 0), Vector2(x, track_height + layout.tickPixels), UI.PAPER, layout.lineWidthPixels, true)
	var y: float = track_height + layout.bracketOffsetPixels
	draw_line(Vector2(size.x * thresholds[0], y), Vector2(size.x * thresholds[1], y), Color("#a8e3c5"), layout.lineWidthPixels, true)
	draw_line(Vector2(size.x * thresholds[2], y), Vector2(size.x, y), UI.ACCENT, layout.lineWidthPixels, true)

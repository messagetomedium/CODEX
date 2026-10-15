extends Node2D

const World = preload("res://scripts/goal/goal_world.gd")
const OverlayManager = preload("res://scripts/ui/overlay_manager.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
enum State { INTRO, TRANSITION, WAITING_FOR_TASK_2 }
var state := State.INTRO
var world: Node2D
var overlays: Control
var hud: Control

func _ready() -> void:
	if not App.valid:
		return
	world = World.new()
	world.name = "World"
	add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "LevelUI"
	add_child(ui_layer)
	hud = Control.new()
	hud.name = "HUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud)
	_create_hud()
	overlays = OverlayManager.new()
	overlays.name = "OverlayManager"
	overlays.size = App.design_size
	ui_layer.add_child(overlays)
	overlays.action_requested.connect(_on_action)
	var intro: Dictionary = App.config.data["ui.ru"].goal.intro
	overlays.show_info({
		"title": intro.title,
		"description": intro.objective,
		"instructionItems": intro.instructions,
		"actions": [{"id": "start", "label": App.texts.text("common.actions.start")}],
	})

func _create_hud() -> void:
	var positions: Dictionary = App.config.data.ui_layout.positions
	var layout: Dictionary = App.config.data.ui_layout.components.hud
	var rules: Dictionary = App.config.data.gameplay.round
	var values := {"round": rules.number, "goalTarget": rules.goalTarget, "maxAttempts": rules.maxAttempts, "goals": 0, "attemptsUsed": 0}
	for id in ["round", "goals", "attempts", "voice"]:
		var placement: Dictionary = positions["hud.voiceMeter" if id == "voice" else "hud." + id]
		var label := UI.label(hud, App.texts.text("goal.hud." + id, values), Rect2(App.design_size * Vector2(placement.x, placement.y), App.design_size * Vector2(layout.voiceWidthFraction if id == "voice" else layout.labelWidthFraction, layout.labelHeightFraction)), 26)
		label.name = id.capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var voice_position: Dictionary = positions["hud.voiceMeter"]
	var meter := ProgressBar.new()
	meter.name = "VoiceMeter"
	meter.position = App.design_size * Vector2(voice_position.x, voice_position.y + layout.voiceBarOffsetFraction)
	meter.size = App.design_size * Vector2(layout.voiceWidthFraction, layout.voiceBarHeightFraction)
	meter.show_percentage = false
	meter.value = 0
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", UI.style(Color("#3d604c"), Color.TRANSPARENT, 4))
	meter.add_theme_stylebox_override("fill", UI.style(UI.ACCENT, Color.TRANSPARENT, 4))
	hud.add_child(meter)

func _on_action(id: String) -> void:
	if id == "menu":
		App.reset()
	elif id == "start" and state == State.INTRO:
		state = State.TRANSITION
		overlays.dismiss(_show_placeholder)

func _show_placeholder() -> void:
	state = State.WAITING_FOR_TASK_2
	overlays.show_info({
		"title": App.texts.text("goal.intro.title"),
		"description": App.texts.text("common.microphone.notImplemented"),
		"actions": [{"id": "menu", "label": App.texts.text("common.actions.menu")}],
	}, "diagnostic")

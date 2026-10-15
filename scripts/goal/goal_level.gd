extends Node2D

const World = preload("res://scripts/goal/goal_world.gd")
const OverlayManager = preload("res://scripts/ui/overlay_manager.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const VoiceFactory = preload("res://scripts/voice/voice_input_factory.gd")
const VoiceDetector = preload("res://scripts/voice/voice_detector.gd")
const VoiceFrame = preload("res://scripts/voice/voice_frame.gd")
const Simulation = preload("res://scripts/goal/logic/goal_simulation.gd")
const Spawner = preload("res://scripts/goal/logic/defender_spawner.gd")
enum State { INTRO, MIC_REQUEST, TRANSITION, ACTIVE, MIC_ERROR, RESOLVED }
var state := State.INTRO
var world: Node2D
var overlays: Control
var hud: Control
var meter: ProgressBar
var status_banner: Control
var voice_input: RefCounted
var detector: RefCounted
var voice_frame = VoiceFrame.new()
var debug_input := false
var simulation: RefCounted
var spawner: RefCounted
var status_title: Label
var status_hint: Label

func _ready() -> void:
	if not App.valid:
		return
	debug_input = VoiceFactory.debug_enabled(App.config.data.gameplay)
	voice_input = VoiceFactory.create(App.config.data.gameplay)
	detector = VoiceDetector.new(App.config.data.gameplay.microphone, App.config.data.gameplay.kick)
	simulation = Simulation.new(App.config.data.gameplay, App.config.data.ui_layout)
	spawner = Spawner.new(App.config.data.gameplay)
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
	_create_status_banner()
	overlays = OverlayManager.new()
	overlays.name = "OverlayManager"
	overlays.size = App.design_size
	ui_layer.add_child(overlays)
	overlays.action_requested.connect(_on_action)
	_show_intro()

func _show_intro(connecting: bool = false) -> void:
	var intro: Dictionary = App.config.data["ui.ru"].goal.intro
	overlays.show_info({
		"title": intro.title,
		"description": App.texts.text("common.microphone.connecting") if connecting else intro.objective,
		"instructionItems": intro.instructions,
		"actions": [] if connecting else [{"id": "start", "label": App.texts.text("common.actions.start")}],
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
	meter = ProgressBar.new()
	meter.name = "VoiceMeter"
	meter.position = App.design_size * Vector2(voice_position.x, voice_position.y + layout.voiceBarOffsetFraction)
	meter.size = App.design_size * Vector2(layout.voiceWidthFraction, layout.voiceBarHeightFraction)
	meter.show_percentage = false
	meter.value = 0
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", UI.style(Color("#3d604c"), Color.TRANSPARENT, 4))
	meter.add_theme_stylebox_override("fill", UI.style(UI.ACCENT, Color.TRANSPARENT, 4))
	hud.add_child(meter)

func _create_status_banner() -> void:
	var placement: Dictionary = App.config.data.ui_layout.positions.microphoneStatus
	var layout: Dictionary = App.config.data.ui_layout.components.microphoneStatus
	status_banner = Control.new()
	status_banner.name = "MicrophoneStatus"
	status_banner.position = App.design_size * Vector2(placement.x, placement.y)
	status_banner.size = App.design_size * Vector2(placement.widthFraction, placement.heightFraction)
	status_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(status_banner)
	var panel := Panel.new()
	panel.size = status_banner.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(UI.PAPER))
	status_banner.add_child(panel)
	status_title = UI.label(status_banner, App.texts.text("common.microphone.debugTitle" if debug_input else "common.microphone.activeTitle"), Rect2(0, App.design_size.y * layout.titleY, status_banner.size.x, App.design_size.y * layout.titleHeight), 26)
	status_hint = UI.label(status_banner, App.texts.text("common.microphone.debugHint" if debug_input else "common.microphone.stageHint"), Rect2(0, App.design_size.y * layout.textY, status_banner.size.x, App.design_size.y * layout.textHeight), 22)
	status_banner.hide()

func _on_action(id: String) -> void:
	if id == "menu":
		App.reset()
	elif (id == "start" and state == State.INTRO) or (id == "mic_retry" and state == State.MIC_ERROR):
		_request_microphone()

func _request_microphone() -> void:
	var retrying := state == State.MIC_ERROR
	state = State.MIC_REQUEST
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	status_banner.hide()
	App.animations.follow_value(meter, ^"value", 0, "hud.voiceMeter")
	# Keep the permission request in the button handler, before any exit Tween.
	voice_input.start()
	if retrying:
		overlays.show_info({
			"title": App.texts.text("common.microphone.errorTitle"),
			"description": App.texts.text("common.microphone.connecting"),
			"layoutId": "microphoneError",
			"animationProfile": "microphoneError.panel",
			"actions": [],
		}, "microphoneError")
	else:
		_show_intro(true)

func _process(delta: float) -> void:
	if voice_input == null:
		return
	var raw: Dictionary = voice_input.poll()
	if raw.status == "active":
		if state == State.MIC_REQUEST:
			state = State.TRANSITION
			overlays.dismiss(_activate_input)
		voice_frame = detector.sample(float(raw.rms), float(raw.peak), int(raw.timestamp), delta, state == State.ACTIVE)
		App.animations.follow_value(meter, ^"value", voice_frame.normalized_loudness * 100, "hud.voiceMeter")
		if state == State.ACTIVE:
			spawner.step(delta, simulation)
			simulation.step(delta, voice_frame)
			world.present(simulation)
			if not simulation.outcome.is_empty():
				_show_outcome()
	elif state in [State.MIC_REQUEST, State.TRANSITION, State.ACTIVE, State.RESOLVED] and raw.status != "pending":
		_show_microphone_error(str(raw.status), str(raw.errorCode))

func _activate_input() -> void:
	detector.reset_controls()
	state = State.ACTIVE
	status_banner.show()
	App.animations.play(status_banner, "microphone.status")
	if not simulation.outcome.is_empty():
		_show_outcome()

func _show_outcome() -> void:
	state = State.RESOLVED
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	status_title.text = App.texts.text("goal.event." + simulation.outcome + ".title")
	status_hint.text = App.texts.text("goal.mechanics.resolvedHint")

func _show_microphone_error(mic_status: String, code: String) -> void:
	state = State.MIC_ERROR
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	status_banner.hide()
	App.animations.follow_value(meter, ^"value", 0, "hud.voiceMeter")
	var text_key: String = {"denied": "permissionDenied", "not-found": "notFound", "busy": "busy"}.get(mic_status, "generic")
	if code in ["native", "insecure", "unsupported", "disconnected", "interrupted"]:
		text_key = {"native": "webOnly", "insecure": "requiresHttps", "unsupported": "unsupported", "disconnected": "disconnected", "interrupted": "disconnected"}[code]
	overlays.show_info({
		"title": App.texts.text("common.microphone.errorTitle"),
		"description": App.texts.text("common.microphone." + text_key),
		"layoutId": "microphoneError",
		"animationProfile": "microphoneError.panel",
		"actions": [{"id": "mic_retry", "label": App.texts.text("common.actions.micRetry")}],
	}, "microphoneError")

func _exit_tree() -> void:
	if voice_input != null:
		voice_input.dispose()

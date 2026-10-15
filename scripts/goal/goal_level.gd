extends Node2D

const World = preload("res://scripts/goal/goal_world.gd")
const OverlayManager = preload("res://scripts/ui/overlay_manager.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const VoiceFactory = preload("res://scripts/voice/voice_input_factory.gd")
const VoiceDetector = preload("res://scripts/voice/voice_detector.gd")
const VoiceFrame = preload("res://scripts/voice/voice_frame.gd")
const Simulation = preload("res://scripts/goal/logic/goal_simulation.gd")
const RoundProgress = preload("res://scripts/goal/logic/round_progress.gd")
const RoundSettings = preload("res://scripts/goal/logic/round_settings.gd")
const Campaign = preload("res://scripts/goal/logic/campaign_progress.gd")
const VoiceGuide = preload("res://scripts/ui/voice_meter_guide.gd")
const Notification = preload("res://scripts/ui/game_notification.gd")
const Spawner = preload("res://scripts/goal/logic/defender_spawner.gd")
enum State { INTRO, MIC_REQUEST, TRANSITION, ACTIVE, MIC_ERROR, EVENT, FINAL }
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
var round_progress: RefCounted
var event_notice: Control
var event_time_left := 0.0
var microphone_resume_state := State.ACTIVE
var campaign: RefCounted
var round_config: Dictionary

func _ready() -> void:
	if not App.valid:
		return
	debug_input = VoiceFactory.debug_enabled(App.config.data.gameplay)
	voice_input = VoiceFactory.create(App.config.data.gameplay)
	detector = VoiceDetector.new(App.config.data.gameplay.microphone, App.config.data.gameplay.kick)
	campaign = Campaign.new(App.config.data.gameplay)
	round_config = RoundSettings.for_round(App.config.data.gameplay, campaign.number)
	round_progress = RoundProgress.new(round_config)
	simulation = Simulation.new(round_config, App.config.data.ui_layout)
	spawner = Spawner.new(round_config)
	world = World.new()
	world.name = "World"
	add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "LevelUI"
	add_child(ui_layer)
	hud = Control.new()
	hud.name = "HUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.hide()
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
	var guide := VoiceGuide.new()
	guide.name = "VoiceGuide"
	guide.position = meter.position
	guide.size = Vector2(meter.size.x, App.design_size.y * App.config.data.ui_layout.components.voiceGuide.heightFraction)
	hud.add_child(guide)
	guide.configure(round_config.microphone, App.config.data.ui_layout.components.voiceGuide, meter.size.y)

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

func _update_hud(animate: bool = true) -> void:
	var values: Dictionary = round_progress.values()
	for id in ["round", "goals", "attempts"]:
		var label: Label = hud.get_node(id.capitalize())
		var text: String = App.texts.text("goal.hud." + id, values)
		if label.text != text:
			label.text = text
			if animate:
				App.animations.play(label, "hud." + id, "changed")

func _on_action(id: String) -> void:
	if id == "menu":
		App.reset()
	elif id in ["retry", "next"] and state == State.FINAL:
		if id == "next":
			if not campaign.advance():
				return
		elif campaign.game_won():
			campaign.restart()
		else:
			campaign.retry_round()
		var available: bool = voice_input.poll().status == "active"
		_reset_round_data()
		if available:
			state = State.TRANSITION
			overlays.dismiss(_activate_input)
		else:
			# A fresh permission request stays in the user's button gesture.
			_request_microphone()
	elif (id == "start" and state == State.INTRO) or (id == "mic_retry" and state == State.MIC_ERROR):
		_request_microphone()

func _request_microphone() -> void:
	App.reveal_level_hud(hud)
	var retrying := state != State.INTRO
	state = State.MIC_REQUEST
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	status_banner.hide()
	App.animations.follow_value(meter, ^"value", 0, "hud.voiceMeter")
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
			if round_progress.begin_movement(simulation.ball.has_moved):
				_update_hud()
			world.present(simulation)
			if not simulation.outcome.is_empty():
				_show_outcome()
		elif state == State.EVENT:
			event_time_left -= maxf(0, delta)
			if event_time_left <= event_notice.exit_seconds():
				event_notice.begin_exit()
			if event_time_left <= 0:
				_finish_event()
	elif state in [State.MIC_REQUEST, State.TRANSITION, State.ACTIVE, State.EVENT] and raw.status != "pending":
		_show_microphone_error(str(raw.status), str(raw.errorCode))

func _activate_input() -> void:
	App.reveal_level_hud(hud)
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	if microphone_resume_state == State.EVENT:
		state = State.EVENT
		event_notice.show()
		return
	state = State.ACTIVE
	status_banner.show()
	App.animations.play(status_banner, "microphone.status")

func _show_outcome() -> void:
	if not round_progress.resolve(simulation.outcome):
		return
	state = State.EVENT
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	status_banner.hide()
	_update_hud()
	event_notice = Notification.new()
	event_notice.name = "GameNotification"
	hud.get_parent().add_child(event_notice)
	var tips: Array = App.config.data["ui.ru"].goal.tips
	event_notice.configure(simulation.outcome, round_progress.values(), str(tips.pick_random().text), _protected_rects())
	event_time_left = float(App.config.data.gameplay.eventFeedback.durationMs) / 1000.0
	world.react(simulation.outcome)

func _protected_rects() -> Array[Rect2]:
	var result: Array[Rect2] = world.protected_rects(simulation)
	for item in hud.get_children():
		if item is Control and item.visible:
			result.append(item.get_global_rect())
	result.append(App.reset_button.get_global_rect())
	return result

func _clear_event_notice() -> void:
	if is_instance_valid(event_notice):
		event_notice.get_parent().remove_child(event_notice)
		event_notice.queue_free()
		event_notice = null

func _finish_event() -> void:
	_clear_event_notice()
	world.reset_feedback()
	if round_progress.finished:
		_show_final()
		return
	round_progress.next_ball()
	simulation.reset_ball()
	world.present(simulation)
	microphone_resume_state = State.ACTIVE
	_activate_input()

func _show_final() -> void:
	state = State.FINAL
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	status_banner.hide()
	var values: Dictionary = round_progress.values()
	var tier: Dictionary = App.config.data["ui.ru"].goal.results.tiers[str(round_progress.goals)]
	campaign.record(round_progress)
	var game_won: bool = campaign.game_won()
	var can_advance: bool = campaign.can_advance()
	var title: String = App.texts.text("goal.results.gameWinTitle") if game_won else (App.texts.text("goal.results.roundWinTitle", values) if can_advance else str(tier.phrases.pick_random()))
	var description: String = App.texts.text("goal.results.gameWinDescription") if game_won else App.texts.text("goal.results.roundWinDescription" if can_advance else "goal.results.roundLossDescription", values)
	var statistics: Array = [App.texts.text("goal.results.goals", values), App.texts.text("goal.results.attempts", values)]
	if game_won:
		var totals: Dictionary = campaign.totals(App.config.data.gameplay)
		statistics = [App.texts.text("goal.results.totalGoals", totals), App.texts.text("goal.results.totalAttempts", totals)]
	var actions: Array = [
		{"id": "retry", "label": App.texts.text("common.actions.restartGame" if game_won else "common.actions.retry")},
		{"id": "menu", "label": App.texts.text("common.actions.menu")},
	]
	if not game_won:
		actions.append({"id": "next", "label": App.texts.text("common.actions.next"), "disabled": not can_advance})
	overlays.show_info({
		"kind": "intermediate" if can_advance else "final",
		"layoutId": "result",
		"animationProfile": "final.panel",
		"title": title,
		"description": description,
		"statistics": statistics,
		"actions": actions,
	}, "final")

func _reset_round_data() -> void:
	_clear_event_notice()
	world.reset_feedback()
	round_config = RoundSettings.for_round(App.config.data.gameplay, campaign.number)
	round_progress = RoundProgress.new(round_config)
	simulation = Simulation.new(round_config, App.config.data.ui_layout)
	spawner = Spawner.new(round_config)
	world.present(simulation)
	microphone_resume_state = State.ACTIVE
	detector.reset_controls()
	voice_frame = VoiceFrame.new()
	_update_hud()

func _show_microphone_error(mic_status: String, code: String) -> void:
	if state in [State.ACTIVE, State.EVENT]:
		microphone_resume_state = state
	if is_instance_valid(event_notice):
		event_notice.hide()
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

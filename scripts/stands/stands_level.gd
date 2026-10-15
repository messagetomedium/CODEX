extends Node2D
## Second mini-game. GoalLevel and the shared microphone bridge remain unchanged.
const World = preload("res://scripts/stands/stands_world.gd")
const HUD = preload("res://scripts/stands/ui/stands_hud.gd")
const Picker = preload("res://scripts/stands/ui/team_picker.gd")
const Overlays = preload("res://scripts/ui/overlay_manager.gd")
const Audio = preload("res://scripts/stands/opponent_audio.gd")
const Match = preload("res://scripts/stands/logic/stands_match.gd")
const Clock = preload("res://scripts/stands/logic/session_clock.gd")
const Bursts = preload("res://scripts/stands/logic/voice_bursts.gd")
const Factory = preload("res://scripts/voice/voice_input_factory.gd")
const Detector = preload("res://scripts/voice/voice_detector.gd")
enum State { INTRO, MIC_REQUEST, TRANSITION, ACTIVE, MIC_ERROR, RESULT }
var state := State.INTRO
var world: Node2D
var hud: Control
var overlays: Control
var audio: AudioStreamPlayer
var picker: Control
var voice_input: RefCounted
var detector: RefCounted
var bursts: RefCounted
var match_model: RefCounted
var clock := Clock.new()
var now_source: Callable = Time.get_ticks_msec
var level_ids: Array[String] = []
var level_index := 0
var results: Dictionary = {}
var player_index := 0
var opponent_index := 1
var rng := RandomNumberGenerator.new()
var previous_loudness := 0.0
var previous_input_turn := -1
var turn_seen := -1
var completion_shown := false

func _ready() -> void:
	if not App.valid:
		return
	rng.randomize()
	for id: String in App.config.data.stands_gameplay.levels:
		if App.config.data.stands_gameplay.levels[id].enabled:
			level_ids.append(id)
	level_index=maxi(0,level_ids.find(str(App.config.data.stands_gameplay.active_level)))
	voice_input = Factory.create(App.config.data.gameplay)
	detector = Detector.new(App.config.data.gameplay.microphone, App.config.data.gameplay.kick)
	bursts = Bursts.new(App.config.data.gameplay.microphone, App.config.data.stands_gameplay.input)
	world = World.new()
	world.name = "World"
	add_child(world)
	audio = Audio.new()
	audio.name = "OpponentAudio"
	add_child(audio)
	audio.configure(App.config.data.stands_gameplay.audio)
	var layer := CanvasLayer.new()
	layer.name = "LevelUI"
	add_child(layer)
	hud = HUD.new()
	hud.name = "HUD"
	layer.add_child(hud)
	overlays = Overlays.new()
	overlays.name = "OverlayManager"
	overlays.size = App.design_size
	layer.add_child(overlays)
	overlays.action_requested.connect(_on_action)
	_new_round()
	_select_team(0)
	_show_intro()

func _select_team(index: int) -> void:
	if state != State.INTRO:
		return
	player_index = index
	var others: Array[int] = []
	for i in App.config.data.stands_teams.teams.size():
		if i != index:others.append(i)
	opponent_index = others[rng.randi_range(0,others.size()-1)]
	var teams: Array = App.config.data.stands_teams.teams
	world.set_teams(teams[player_index],teams[opponent_index])
	hud.set_teams(teams[player_index],teams[opponent_index])
	hud.present(match_model,level_index+1)

func _show_intro(connecting: bool = false) -> void:
	var intro: Dictionary = App.config.data["ui.ru"].stands.intro
	var extra: Control
	if not connecting:
		extra = Picker.new()
		picker = extra
		extra.configure(player_index)
		extra.team_selected.connect(_select_team)
	overlays.show_info({
		"title":intro.title,
		"description":App.texts.text("common.microphone.connecting") if connecting else intro.objective,
		"instructionItems":intro.instructions,
		"layoutId":"standsIntro","heightFraction":App.config.data.ui_layout.components.standsIntro.heightFraction,
		"animationProfile":"stands.intro_popup_enter",
		"instructionProfile":"stands.intro_step_enter","iconProfile":"stands.intro_step_icon_slot",
		"extraContent":extra,
		"actions":[] if connecting else [{"id":"start","label":intro.start_button}],
	},"standsIntro")

func _new_round() -> void:
	match_model = Match.new(App.config.data.stands_gameplay,level_ids[level_index],rng.randi())
	clock = Clock.new()
	previous_loudness = 0
	previous_input_turn = -1
	turn_seen = -1
	completion_shown = false
	detector.reset_controls()
	detector.loudness = 0
	bursts.reset()
	bursts.last_at = -1000
	world.idle()
	audio.set_opponent_turn(false)
	hud.reset_round()
	if not hud.left_team.is_empty():hud.present(match_model,level_index+1)

func _on_action(id: String) -> void:
	if id == "menu":
		App.reset()
	elif id == "start" and state == State.INTRO:
		_request_microphone()
	elif id == "mic_retry" and state == State.MIC_ERROR:
		_request_microphone()
	elif id in ["retry","next"] and state == State.RESULT:
		if id == "next":
			if match_model.outcome != "win" or level_index >= level_ids.size()-1:return
			level_index += 1
		elif match_model.outcome == "win" and level_index == level_ids.size()-1:
			level_index = 0
			results.clear()
		else:
			results.erase(level_ids[level_index])
		_new_round()
		if voice_input.poll().status == "active":
			state = State.TRANSITION
			overlays.dismiss(_activate)
		else:
			_request_microphone()

func _request_microphone() -> void:
	var is_intro := state == State.INTRO
	state = State.MIC_REQUEST
	voice_input.start()
	if is_intro:
		_show_intro(true)
	else:
		overlays.show_info({"title":App.texts.text("common.microphone.errorTitle"),"description":App.texts.text("common.microphone.connecting"),"layoutId":"microphoneError","animationProfile":"microphoneError.panel","actions":[]},"microphoneError")

func _activate() -> void:
	var now: int = now_source.call()
	if clock.started:clock.resume(now)
	else:clock.start(now)
	state = State.ACTIVE
	turn_seen = -1
	previous_loudness = 0
	previous_input_turn = -1
	_sync_turn()

func _sync_turn() -> void:
	if turn_seen == match_model.turn_index:return
	turn_seen = match_model.turn_index
	previous_loudness = 0
	previous_input_turn = -1
	detector.reset_controls()
	detector.loudness = 0
	bursts.reset()
	var player: bool = match_model.player_turn()
	audio.set_opponent_turn(not player)
	world.set_turn(player)

func _process(delta: float) -> void:
	if voice_input == null:return
	var raw: Dictionary = voice_input.poll()
	var now: int = now_source.call()
	if raw.status != "active":
		if state in [State.ACTIVE,State.TRANSITION,State.MIC_REQUEST] and raw.status != "pending":
			_mic_error(raw,now)
		return
	if state == State.MIC_REQUEST:
		state = State.TRANSITION
		overlays.dismiss(_activate)
		return
	if state != State.ACTIVE:return
	match_model.advance_to(clock.seconds(now),previous_loudness,previous_input_turn)
	if match_model.finished:
		_finish(now)
		return
	_sync_turn()
	var loudness := 0.0
	var elapsed: float = match_model.elapsed
	var turn: Dictionary = match_model.turns[match_model.turn_index]
	var guard: float = App.config.data.stands_gameplay.input.speaker_echo_guard_ms/1000.0
	if match_model.player_turn() and elapsed-float(turn.start) >= guard:
		var frame: RefCounted = detector.sample(float(raw.rms),float(raw.peak),int(raw.timestamp),delta,false)
		loudness = frame.normalized_loudness
		if bursts.sample(detector.previous_level,elapsed):
			match_model.register_peak(elapsed,match_model.turn_index)
	previous_loudness = loudness
	previous_input_turn = match_model.turn_index
	world.player.set_intensity(loudness)
	hud.present(match_model,level_index+1)

func _mic_error(raw: Dictionary, now: int) -> void:
	clock.pause(now)
	audio.set_opponent_turn(false)
	world.idle()
	previous_loudness = 0
	previous_input_turn = -1
	detector.loudness = 0
	state = State.MIC_ERROR
	var key: String = {"denied":"permissionDenied","not-found":"notFound","busy":"busy"}.get(str(raw.status),"generic")
	var code: String = raw.get("errorCode","")
	if code in ["native","insecure","unsupported","disconnected","interrupted"]:
		key={"native":"webOnly","insecure":"requiresHttps","unsupported":"unsupported","disconnected":"disconnected","interrupted":"disconnected"}[code]
	overlays.show_info({"title":App.texts.text("common.microphone.errorTitle"),"description":App.texts.text("common.microphone."+key),"layoutId":"microphoneError","animationProfile":"microphoneError.panel","actions":[{"id":"mic_retry","label":App.texts.text("common.actions.micRetry")}]},"microphoneError")

func _finish(now: int) -> void:
	if completion_shown:return
	completion_shown = true
	clock.pause(now)
	audio.set_opponent_turn(false)
	world.idle()
	state = State.RESULT
	results[level_ids[level_index]] = {"score":match_model.score,"outcome":match_model.outcome,"peaks":match_model.total_peaks}
	var won: bool = match_model.outcome == "win"
	var all_won: bool = won and level_index == level_ids.size()-1
	var teams: Array = App.config.data.stands_teams.teams
	var values := {"round":level_index+1,"score":snappedf(match_model.score,.1),"playerTeam":App.texts.text(teams[player_index].name_key),"opponentTeam":App.texts.text(teams[opponent_index].name_key)}
	var phrases: Array = App.config.data["ui.ru"].stands.results[match_model.outcome]
	var title := str(phrases[rng.randi_range(0,phrases.size()-1)])
	if won:title = App.texts.text("stands.results.game_win" if all_won else "stands.results.round_win",values)
	var actions: Array = [{"id":"retry","label":App.texts.text("common.actions.restartGame" if all_won else "common.actions.retry")},{"id":"menu","label":App.texts.text("common.actions.menu")}]
	if not all_won:actions.append({"id":"next","label":App.texts.text("common.actions.next"),"disabled":not won})
	overlays.show_info({"kind":"final" if all_won or not won else "intermediate","layoutId":"result","animationProfile":"stands.final_popup_enter","headlineProfile":"stands.final_headline_enter","statsProfile":"stands.final_score_enter","actionsProfile":"stands.final_buttons_enter","title":title,"description":App.texts.text("stands.results.versus",values),"statistics":[App.texts.text("stands.results.summary",values)],"actions":actions},"final")
	(world.player if won else world.opponent).set_state("win")
	hud.present(match_model,level_index+1)

func _exit_tree() -> void:
	if audio != null:audio.set_opponent_turn(false)
	if voice_input != null:voice_input.dispose()

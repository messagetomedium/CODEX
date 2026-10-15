extends Node2D
const World=preload("res://scripts/commentator/commentator_world.gd")
const HUD=preload("res://scripts/commentator/ui/commentator_hud.gd")
const Session=preload("res://scripts/commentator/logic/commentator_session.gd")
const Clock=preload("res://scripts/stands/logic/session_clock.gd")
const Overlays=preload("res://scripts/ui/overlay_manager.gd")
const Factory=preload("res://scripts/voice/voice_input_factory.gd")
const Detector=preload("res://scripts/voice/voice_detector.gd")
enum State { INTRO, MIC_REQUEST, TRANSITION, ACTIVE, MIC_ERROR, RESULT }
var state:=State.INTRO
var world: Node2D
var hud: Control
var overlays: Control
var voice_input: RefCounted
var detector: RefCounted
var session: RefCounted
var clock: RefCounted
var now_source: Callable=Time.get_ticks_msec
var levels: Array=[]
var level_index:=0
var results: Dictionary={}
var previous_loudness:=0.0
var previous_envelope:=0.0
var previous_turn:=-1
var turn_seen:=-1
var completion_shown:=false

func _ready() -> void:
	if not App.valid:return
	for level in App.config.data.commentator_levels.levels:
		if App.config.data.commentator_gameplay.levels[level.id].enabled:levels.append(level)
	voice_input=Factory.create(App.config.data.gameplay)
	detector=Detector.new(App.config.data.gameplay.microphone,App.config.data.gameplay.kick)
	world=World.new()
	world.name="World"
	add_child(world)
	var layer:=CanvasLayer.new()
	layer.name="LevelUI"
	add_child(layer)
	hud=HUD.new()
	hud.name="HUD"
	hud.hide()
	layer.add_child(hud)
	overlays=Overlays.new()
	overlays.name="OverlayManager"
	overlays.size=App.design_size
	layer.add_child(overlays)
	overlays.action_requested.connect(_on_action)
	_new_round()
	_show_intro()

func _show_intro(connecting: bool=false) -> void:
	var intro: Dictionary=App.config.data["ui.ru"].commentator.intro
	overlays.show_info({"title":intro.title,"description":App.texts.text("common.microphone.connecting") if connecting else intro.objective,"instructionItems":intro.instructions,"instructionTitleFontSize":App.config.data.commentator_layout.intro.instruction_title_font_size,"animationProfile":"commentator.intro","actions":[] if connecting else [{"id":"start","label":App.texts.text("common.actions.start")}]})

func _new_round() -> void:
	session=Session.new(levels[level_index],App.config.data.commentator_gameplay)
	clock=Clock.new()
	completion_shown=false
	previous_loudness=0
	previous_envelope=0
	previous_turn=-1
	turn_seen=-1
	detector.reset_controls()
	detector.loudness=0
	world.media.configure(levels[level_index])
	hud.reset_round(session)
	hud.present(session,level_index+1,levels.size())

func _on_action(id: String) -> void:
	if id=="menu":App.reset()
	elif id=="start" and state==State.INTRO:_request_microphone()
	elif id=="mic_retry" and state==State.MIC_ERROR:_request_microphone()
	elif id in ["retry","next"] and state==State.RESULT:
		if id=="next":
			if not session.result.passed or level_index>=levels.size()-1:return
			level_index+=1
		elif session.result.passed and level_index==levels.size()-1:
			level_index=0
			results.clear()
		else:results.erase(levels[level_index].id)
		_new_round()
		if voice_input.poll().status=="active":
			state=State.TRANSITION
			overlays.dismiss(_activate)
		else:_request_microphone()

func _request_microphone() -> void:
	var first:=state==State.INTRO
	App.reveal_level_hud(hud)
	state=State.MIC_REQUEST
	voice_input.start()
	if first:_show_intro(true)
	else:overlays.show_info({"title":App.texts.text("common.microphone.errorTitle"),"description":App.texts.text("common.microphone.connecting"),"layoutId":"microphoneError","animationProfile":"microphoneError.panel","actions":[]},"microphoneError")

func _activate() -> void:
	App.reveal_level_hud(hud)
	var now: int=now_source.call()
	if clock.started:clock.resume(now)
	else:clock.start(now)
	state=State.ACTIVE
	turn_seen=-1
	previous_turn=-1
	previous_loudness=0
	previous_envelope=0
	session.reset_input()
	_sync_turn()

func _sync_turn() -> void:
	var index: int=session.timeline.turn_at(session.elapsed)
	if index!=turn_seen:
		turn_seen=index
		previous_turn=-1
		previous_loudness=0
		previous_envelope=0
		detector.reset_controls()
		detector.loudness=0
		session.reset_input()
	world.media.sync(session)

func _process(delta: float) -> void:
	if voice_input==null:return
	var raw: Dictionary=voice_input.poll()
	var now: int=now_source.call()
	if raw.status!="active":
		if state in [State.MIC_REQUEST,State.TRANSITION,State.ACTIVE] and raw.status!="pending":_mic_error(raw,now)
		return
	if state==State.MIC_REQUEST:
		state=State.TRANSITION
		overlays.dismiss(_activate)
		return
	if state!=State.ACTIVE:return
	session.advance_to(clock.seconds(now),previous_loudness,previous_envelope,previous_turn)
	if session.finished:
		_finish(now)
		return
	_sync_turn()
	var turn: Dictionary=session.timeline.turns[turn_seen]
	previous_loudness=0
	previous_envelope=0
	previous_turn=turn_seen
	if turn.speaker=="player" and session.elapsed-float(turn.start_sec)>=App.config.data.commentator_gameplay.scoring.speaker_echo_guard_sec:
		var sample: RefCounted=detector.sample(float(raw.rms),float(raw.peak),int(raw.timestamp),minf(delta,App.config.data.commentator_gameplay.scoring.max_sample_hold_sec),false)
		previous_loudness=sample.normalized_loudness
		previous_envelope=detector.previous_level
	hud.present(session,level_index+1,levels.size())

func _mic_error(raw: Dictionary, now: int) -> void:
	clock.pause(now)
	world.media.stop()
	previous_turn=-1
	previous_loudness=0
	previous_envelope=0
	session.reset_input()
	state=State.MIC_ERROR
	var key: String={"denied":"permissionDenied","not-found":"notFound","busy":"busy"}.get(str(raw.status),"generic")
	var code: String=raw.get("errorCode","")
	if code in ["native","insecure","unsupported","disconnected","interrupted"]:key={"native":"webOnly","insecure":"requiresHttps","unsupported":"unsupported","disconnected":"disconnected","interrupted":"disconnected"}[code]
	overlays.show_info({"title":App.texts.text("common.microphone.errorTitle"),"description":App.texts.text("common.microphone."+key),"layoutId":"microphoneError","animationProfile":"microphoneError.panel","actions":[{"id":"mic_retry","label":App.texts.text("common.actions.micRetry")}]},"microphoneError")

func values(result: Dictionary, number: int) -> Dictionary:
	return {"round":number,"hitPercent":roundi(100.0*result.words_hit/maxi(1,result.words_total)),"avgScore":snappedf(result.avg_word_score,.1),"interest":roundi(result.interest_end)}

func _finish(now: int) -> void:
	if completion_shown:return
	completion_shown=true
	clock.pause(now)
	world.media.stop()
	state=State.RESULT
	results[levels[level_index].id]=session.result.duplicate(true)
	var last:=level_index==levels.size()-1
	var statistics: Array=[]
	var current:=values(session.result,level_index+1)
	if last:
		var total_words:=0
		var total_hits:=0
		var weighted:=0.0
		for result in results.values():
			total_words+=int(result.words_total)
			total_hits+=int(result.words_hit)
			weighted+=result.avg_word_score*result.words_total
		statistics.append(App.texts.text("commentator.results.final_summary",values({"words_hit":total_hits,"words_total":total_words,"avg_word_score":weighted/maxi(1,total_words),"interest_end":0},0)))
		for i in levels.size():statistics.append(App.texts.text("commentator.results.level_summary",values(results[levels[i].id],i+1)))
	else:
		statistics=[App.texts.text("commentator.results.summary",current),App.texts.text("commentator.results.interest",current)]
	var actions: Array=[{"id":"retry","label":App.texts.text("common.actions.restartGame" if last and session.result.passed else "common.actions.retry")},{"id":"menu","label":App.texts.text("common.actions.menu")}]
	if not last:actions.append({"id":"next","label":App.texts.text("commentator.results.next"),"disabled":not session.result.passed})
	overlays.show_info({"kind":"final" if last else "intermediate","layoutId":"commentatorResult" if last else "result","heightFraction":App.config.data.ui_layout.components.commentatorResult.heightFraction if last else App.config.data.ui_layout.components.popup.heightFraction,"animationProfile":"commentator.result","title":App.texts.text("commentator.results.final" if last and session.result.passed else ("commentator.results.win" if session.result.passed else "commentator.results.loss")),"description":App.texts.text("commentator.results.demo"),"statistics":statistics,"actions":actions},"commentatorFinal" if last else "final")
	hud.present(session,level_index+1,levels.size())

func _exit_tree() -> void:
	if world!=null and world.media!=null:world.media.stop()
	if voice_input!=null:voice_input.dispose()

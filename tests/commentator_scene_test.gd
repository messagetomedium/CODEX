extends SceneTree
class VirtualInput:
	extends "res://scripts/voice/voice_input.gd"
	var rms:=0.0
	var timestamp:=0
	var starts:=0
	var disposed:=false
	func start() -> void:
		starts+=1
		status="active"
	func poll() -> Dictionary:return {"status":status,"errorCode":error_code,"rms":rms,"peak":rms,"timestamp":timestamp}
	func dispose() -> void:
		disposed=true
		status="idle"
var app: Node
var level: Node
var input: RefCounted
var now_ms:=1000
var checks:=0
var failures:=0

func _init() -> void:_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func frames() -> void:
	for i in 3:await process_frame
func tick(ms: int, normalized: float=0) -> void:
	now_ms+=ms
	var gate: float=level.detector.noise_floor*level.detector.settings.noiseGateMultiplier
	input.rms=gate+normalized*(level.detector.settings.referenceRms-gate) if normalized>0 else 0
	input.timestamp=now_ms
	level._process(ms/1000.0)
func complete(rhythmic: bool) -> void:
	var guard:=0
	while level.state==level.State.ACTIVE and guard<3100:
		var next: float=level.clock.seconds(now_ms+20)
		var index: int=level.session.timeline.active_word(next)
		var voice:=0.0
		if rhythmic and index>=0:
			var word: Dictionary=level.session.timeline.words[index]
			var phase: float=(next-word.start_sec)/(word.end_sec-word.start_sec)
			voice=(.72 if word.emphasis else .40) if phase>.04 and phase<.80 else .14
		tick(20,voice)
		guard+=1

func _run() -> void:
	app=root.get_node("App")
	app.reset()
	await frames()
	current_scene.cards[2].pressed.emit()
	await frames()
	await create_timer(.4).timeout
	level=current_scene
	level.set_process(false)
	check(level.name=="CommentatorLevel" and level.state==level.State.INTRO,"Third menu card opens the new level through existing navigation")
	check(not level.hud.visible and level.world.visible and not level.clock.started,"Only the booth/world appears behind the initial popup")
	check(level.overlays.popup.instruction_items.size()==3,"Existing popup supplies exactly three instruction illustrations")
	check(level.world.media.audio.stream==null and level.world.media.video.stream==null,"Demonstration is playable without pretending to contain archive media")
	level.voice_input.dispose()
	input=VirtualInput.new()
	level.voice_input=input
	level.now_source=func():return now_ms
	level.overlays.popup.action_buttons[0].pressed.emit()
	check(input.starts==1 and level.hud.visible and not level.clock.started,"Start alone reveals HUD and requests the shared microphone, before starting time")
	level._process(.02)
	await create_timer(.4).timeout
	check(level.state==level.State.ACTIVE and level.clock.started,"Microphone readiness and popup exit activate the level")
	var noise: float=level.detector.noise_floor
	tick(3000,1)
	check(level.session.interest==50 and level.detector.noise_floor==noise,"Host sound cannot score or contaminate microphone calibration")
	check(level.world.media.optional("res://missing-archive.ogg")==null,"Missing optional archive slots keep the blockout playable")
	level.levels[0].turns[0].audio_path="res://assets/stands/audio/opponent_cheer_loop.wav"
	level.world.media.turn_seen=-1
	level.world.media.sync(level.session)
	check(level.world.media.audio.playing,"An available local host audio slot can play during its authored turn")
	level.world.media.stop()
	check(not level.world.media.audio.playing and level.world.media.paused,"Media pause immediately stops host audio")
	level.world.media.sync(level.session)
	check(level.world.media.audio.playing,"Media resumes at the same authored host turn")
	check(level.hud.labels.turn.text.contains("2"),"Host cue warns about the approaching player turn")
	tick(2400,0)
	check(not level.world.media.audio.playing,"Switching to the player immediately stops optional host audio")
	level.levels[0].turns[0].audio_path=""
	check(level.hud.karaoke.words.size()==6,"Player turn renders independently timed word controls")
	var arrows:=0
	for node in level.hud.karaoke.content.get_children():
		if node.name.begins_with("EmphasisArrows"):arrows+=1
	check(arrows==2,"Every emphasized word has its own animated arrows and ordinary words have none")
	var elapsed: float=level.session.elapsed
	input.status="busy"
	level._process(.02)
	tick(10000,1)
	check(level.state==level.State.MIC_ERROR and level.session.elapsed==elapsed and level.world.media.paused,"Microphone errors pause scoring, clock and all media")
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(.02)
	await create_timer(.4).timeout
	check(level.state==level.State.ACTIVE and input.starts==2,"Retry resumes the same level using the common error popup")
	complete(true)
	check(level.session.finished and level.session.result.passed and level.session.elapsed==60,"Actual controller plus virtual RMS completes the first full level")
	check(level.overlays.popup.action_buttons.size()==3 and not level.overlays.popup.action_buttons[2].disabled,"Passing unlocks the next level in the existing intermediate popup")
	for number in [2,3]:
		level.overlays.popup.action_buttons[2].pressed.emit()
		await create_timer(.4).timeout
		check(level.level_index==number-1 and level.state==level.State.ACTIVE and level.session.elapsed==0,"Next advances without replaying intro or starting an extra scene")
		check(input.starts==2,"Next reuses one microphone session")
		complete(true)
		print("Controller Commentator level ",number,": ",level.session.result)
		check(level.state==level.State.RESULT and level.session.result.passed,"Controller RMS sampling passes every higher difficulty")
	check(level.results.size()==3 and level.overlays.popup.action_buttons.size()==2,"Third result summarizes all three levels in one final popup")
	check(level.overlays.popup.get_node("Statistics").get_child_count()==4,"Final popup shows overall rhythm and each level result")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await create_timer(.4).timeout
	check(level.level_index==0 and level.results.is_empty(),"Play again resets all three level results")
	complete(false)
	check(not level.session.result.passed and level.overlays.popup.action_buttons[2].disabled,"Silence finishes with Retry and cannot unlock Next")
	level._on_action("next")
	check(level.level_index==0,"Disabled Next is also guarded by the controller")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await create_timer(.4).timeout
	check(level.state==level.State.ACTIVE and level.level_index==0 and level.session.elapsed==0,"Retry resets only the current level")
	tick(5500,.4)
	app.reset()
	await frames()
	check(input.disposed and current_scene.name=="MainMenu","Global Reset mid-phrase releases input and all scene-owned Tweens/media")
	app.open_commentator()
	await frames()
	current_scene.overlays.popup.action_buttons[0].pressed.emit()
	await create_timer(.4).timeout
	check(current_scene.state==current_scene.State.MIC_ERROR,"Native production start honestly reports browser-only microphone")
	app.reset()
	await frames()
	print("Commentator scene checks: ",checks,"; passed: ",checks-failures,"; failed: ",failures)
	quit(0 if failures==0 else 1)

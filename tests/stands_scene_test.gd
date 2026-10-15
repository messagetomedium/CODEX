extends SceneTree
class TestInput:
	extends "res://scripts/voice/voice_input.gd"
	var rms := 0.0
	var timestamp := 0
	var starts := 0
	var disposed := false
	func start() -> void:
		starts += 1
		status = "active"
	func poll() -> Dictionary:
		return {"status":status,"errorCode":error_code,"rms":rms,"peak":rms,"timestamp":timestamp}
	func dispose() -> void:
		disposed = true
		status = "idle"

var app: Node
var level: Node
var source: RefCounted
var test_ms := 1000
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 3:await process_frame

func tick(milliseconds: int, rms: float = 0) -> void:
	test_ms += milliseconds
	source.rms = rms
	source.timestamp = test_ms
	level._process(milliseconds/1000.0)

func play_to_end() -> void:
	var guard := 0
	while level.state == level.State.ACTIVE and guard < 1300:
		var model: RefCounted = level.match_model
		var turn: Dictionary = model.turns[model.turn_index]
		var local: float = model.elapsed-turn.start
		var target: int = model.difficulty.target_peaks
		var rms := 0.1
		if model.player_turn() and local < target*.6:
			rms = 0.0 if fposmod(local,.6)<.2 else .1
		tick(50,rms)
		guard += 1

func _run() -> void:
	app = root.get_node("App")
	check(app.valid,"Application loads old and new configs together")
	app.reset()
	await frames()
	var menu: Control = current_scene
	check(not menu.cards[0].disabled and not menu.cards[1].disabled and not menu.cards[2].disabled,"All three mini-games are enabled")
	menu.cards[1].pressed.emit()
	await frames()
	await create_timer(.4).timeout
	level = current_scene
	level.set_process(false)
	check(level.name=="StandsLevel" and level.state==level.State.INTRO,"Menu opens the second level type without replacing the menu framework")
	check(level.overlays.popup.instruction_items.size()==3 and level.picker==null,"Entry contains only the standard three-rule instruction, without team cards")
	check(not level.hud.visible and level.world.visible and not level.clock.started,"Only the world appears behind the instruction; gameplay HUD and timer stay off")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await create_timer(.4).timeout
	check(level.state==level.State.TEAM_SELECT and level.overlays.popup.instruction_items.is_empty() and level.picker.cards.size()==4,"Continue opens a separate team picker in the common popup")
	check(not level.hud.visible and not level.clock.started and level.voice_input.status=="idle","Team choice keeps the HUD hidden and never requests microphone or starts the timer")
	for card in level.picker.cards:
		check(card.get_node("Description").size.x<=card.size.x and card.get_node("Description").get_visible_line_count()>=card.get_node("Description").get_line_count(),"Team description wraps completely within its card")
	check(not level.audio.playing and not level.clock.started,"Intro has no opponent audio or running timer")
	level.picker.cards[2].pressed.emit()
	check(level.player_index==2 and level.opponent_index!=2,"Team selection picks the chosen team and a different automatic opponent")
	check(level.world.player.team.id=="impuls_2000" and level.hud.left_team.id=="impuls_2000","Team colors and names reach the world and HUD")
	level.voice_input.dispose()
	source = TestInput.new()
	level.voice_input = source
	level.now_source = func():return test_ms
	level.overlays.popup.action_buttons[0].pressed.emit()
	check(source.starts==1 and not level.clock.started and level.hud.visible,"Start reveals the HUD and requests one shared microphone, but waits to start the clock")
	level._process(.016)
	await create_timer(.4).timeout
	check(level.state==level.State.ACTIVE and level.clock.started and level.match_model.elapsed==0,"The timer starts only after microphone readiness and popup exit")
	check(level.audio.playing and level.world.opponent.active and not level.world.player.active,"The opponent starts with its sound and matching visual stand")
	var noise: float = level.detector.noise_floor
	tick(5000,.1)
	check(level.match_model.player_turn() and is_equal_approx(level.match_model.score,45),"The first opponent turn lasts exactly five seconds and ignores loud microphone input")
	check(level.detector.noise_floor==noise and level.match_model.total_peaks==0,"Opponent sound cannot contaminate calibration or accumulate peaks")
	check(not level.audio.playing and level.world.player.active and not level.world.opponent.active,"Player turn immediately stops the opponent and switches crowd activation")
	tick(200,.1)
	tick(100,.1)
	check(level.match_model.total_peaks==0,"A held voice from the opponent turn cannot become a synthetic peak through meter smoothing")
	tick(200,0)
	var paused_elapsed: float = level.match_model.elapsed
	var paused_score: float = level.match_model.score
	source.status="busy"
	level._process(.016)
	check(level.state==level.State.MIC_ERROR and not level.audio.playing,"Microphone loss opens the shared error popup and stops sound")
	tick(15000,.1)
	check(level.match_model.elapsed==paused_elapsed and level.match_model.score==paused_score,"Error overlay pauses both time and score")
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(.016)
	await create_timer(.4).timeout
	tick(100,0)
	check(level.state==level.State.ACTIVE and is_equal_approx(level.match_model.elapsed,paused_elapsed+.1),"Retry resumes the same match, excluding the whole pause")
	check(source.starts==2,"Only error retry re-requests the microphone")
	play_to_end()
	check(level.state==level.State.RESULT and level.match_model.elapsed==30 and level.match_model.outcome=="win","Real controller voice sampling can win the first thirty-second round")
	check(not level.audio.playing and level.match_model.finish_count==1,"Completion stops all opponent audio and latches once")
	check(not level.overlays.popup.action_buttons[2].disabled,"Winning round one unlocks the next round")
	var final_score: float = level.match_model.score
	tick(10000,.1)
	check(level.match_model.score==final_score and level.match_model.finish_count==1,"Result overlay freezes input and cannot finish twice")
	for number in [2,3]:
		level.overlays.popup.action_buttons[2].pressed.emit()
		await frames()
		check(level.level_index==number-1 and level.state==level.State.ACTIVE and level.match_model.score==50 and level.match_model.elapsed==0,"Next resets score and clock without replaying team selection")
		check(source.starts==2,"Next reuses the existing microphone instead of opening another stream")
		play_to_end()
		check(level.state==level.State.RESULT and level.match_model.outcome=="win" and level.match_model.elapsed==30,"Controller voice input completes the higher difficulty")
		check(not level.audio.playing and level.match_model.total_peaks>0,"Higher-level peaks count while end audio is off")
	check(level.results.size()==3 and level.overlays.popup.action_buttons.size()==2,"Third victory shows game completion through the common result popup")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await frames()
	check(level.level_index==0 and level.results.is_empty() and level.match_model.score==50 and level.match_model.elapsed==0,"Play again resets the entire three-level sequence")
	# Finish a real silent match and test loss/retry/menu rather than forcing a result.
	tick(30000,0)
	check(level.match_model.outcome=="loss" and level.overlays.popup.action_buttons[2].disabled,"Silence loses and cannot unlock Next")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await frames()
	check(level.level_index==0 and level.match_model.elapsed==0 and level.match_model.score==50,"Retry restarts only the current difficulty")
	# Score exactly fifty after an allowed full match to exercise a draw panel.
	var model: RefCounted=level.match_model
	model.advance_to(25)
	model.score_base=50
	model.score=50
	model.advance_to(30)
	test_ms=level.clock.origin_ms+30000
	level._process(.016)
	check(model.outcome=="draw" and level.overlays.popup.action_buttons[2].disabled,"Draw also offers retry and keeps Next unavailable")
	app.reset_button.pressed.emit()
	await frames()
	check(current_scene.name=="MainMenu" and source.disposed,"Global Reset disposes microphone and returns to menu from results")
	app.open_stands()
	await frames()
	current_scene.overlays.popup.action_buttons[0].pressed.emit()
	await create_timer(.4).timeout
	current_scene.overlays.popup.action_buttons[0].pressed.emit()
	await frames()
	check(current_scene.state==current_scene.State.MIC_ERROR,"A missing native browser microphone uses the existing honest error popup")
	app.reset()
	await frames()
	app.open_goal()
	await frames()
	check(current_scene.name=="GoalLevel" and current_scene.state==current_scene.State.INTRO,"The first mini-game still starts through its original route and instruction")
	app.reset()
	await frames()
	print("Stands scene checks: ",checks,"; passed: ",checks-failures,"; failed: ",failures)
	quit(0 if failures==0 else 1)

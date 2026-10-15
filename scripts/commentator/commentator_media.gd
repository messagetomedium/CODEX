extends Node2D
## Optional local resources. Empty/missing slots leave the playable blockout intact.
var audio: AudioStreamPlayer
var video: VideoStreamPlayer
var background: TextureRect
var portrait: TextureRect
var turn_seen:=-1
var paused:=true

func _ready() -> void:
	audio=AudioStreamPlayer.new()
	audio.volume_db=App.config.data.commentator_gameplay.media.host_volume_db
	add_child(audio)
	video=VideoStreamPlayer.new()
	video.mouse_filter=Control.MOUSE_FILTER_IGNORE
	video.expand=true
	video.volume=0
	add_child(video)
	background=TextureRect.new()
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)
	move_child(background,0)
	portrait=TextureRect.new()
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var p: Array=App.config.data.commentator_layout.media.portrait_rect
	portrait.position=App.design_size*Vector2(p[0],p[1])
	portrait.size=App.design_size*Vector2(p[2],p[3])
	portrait.z_index=1
	add_child(portrait)
	var r: Array=App.config.data.commentator_layout.world.window_rect
	for node in [video,background]:
		node.position=App.design_size*Vector2(r[0],r[1])
		node.size=App.design_size*Vector2(r[2],r[3])

func optional(path: String) -> Resource:
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null

func configure(level: Dictionary) -> void:
	stop()
	background.texture=optional(level.media.background_texture_path) as Texture2D
	portrait.texture=optional(level.media.portrait_texture_path) as Texture2D
	video.stream=optional(level.media.match_video_path) as VideoStream
	background.visible=background.texture!=null
	portrait.visible=portrait.texture!=null
	video.visible=video.stream!=null
	turn_seen=-1

func sync(model: RefCounted) -> void:
	if model.finished:
		stop()
		return
	var turn_index: int=model.timeline.turn_at(model.elapsed)
	var turn: Dictionary=model.timeline.turns[turn_index]
	if paused:
		paused=false
		if video.stream!=null:
			if not video.is_playing():video.play()
			video.stream_position=model.elapsed
			video.paused=false
		turn_seen=-1
	if turn_index!=turn_seen:
		turn_seen=turn_index
		audio.stop()
		if turn.speaker=="host":
			audio.stream=optional(turn.get("audio_path","")) as AudioStream
			if audio.stream!=null:audio.play(maxf(0,model.elapsed-turn.start_sec))
	if turn.speaker!="host":audio.stop()
	if video.stream!=null and absf(video.stream_position-model.elapsed)>App.config.data.commentator_gameplay.media.video_drift_tolerance_sec:video.stream_position=model.elapsed

func stop() -> void:
	paused=true
	if audio!=null:audio.stop()
	if video!=null:video.paused=true

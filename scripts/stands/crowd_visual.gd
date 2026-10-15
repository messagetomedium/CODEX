extends Node2D
## Replaceable visual contract. Cached geometry; Tween moves/modulates the group.
## No per-frame crowd rebuild, score, microphone, turn schedule or sound.
var team: Dictionary = {}
var side := -1
var active := false
var intensity := 0.0
var state := "idle"
var phase := 0.0:
	set(value):
		phase = value
		_apply_motion()
var pulse: Tween
var dim: Tween

func set_team(value: Dictionary) -> void:
	team = value
	queue_redraw()

func set_intensity(value: float) -> void:
	intensity = clampf(value, 0, 1)
	_apply_motion()

func _apply_motion() -> void:
	if not is_inside_tree():return
	var key := "stands.player_stand_pulse" if side<0 else "stands.opponent_stand_pulse"
	var spec: Dictionary = App.config.data.ui_animations.profiles[key].pulse
	position.y = -phase*spec.motion_amplitude_px*(.45+intensity*.55) if active else 0.0
	var brightness := lerpf(spec.min_brightness,spec.max_brightness,phase) if active else 1.0
	self_modulate=Color(brightness,brightness,brightness,1)

func set_state(value: String) -> void:
	state = value if value in ["idle", "cheer", "win"] else "idle"
	set_cheer_active(state != "idle")

func set_cheer_active(value: bool) -> void:
	if active == value and has_meta("cheer_initialized") and (not value or pulse != null):
		return
	set_meta("cheer_initialized",true)
	active = value
	if pulse and pulse.is_valid():
		pulse.kill()
	if dim and dim.is_valid():
		dim.kill()
	var profiles: Dictionary = App.config.data.ui_animations.profiles
	var dim_spec: Dictionary = profiles["stands.inactive_stand_dim"].sourceSettings
	var duration: float = dim_spec.duration_ms / 1000.0
	var opacity: float = 1.0 if active else dim_spec.target_opacity
	if duration <= 0:
		modulate.a = opacity
	else:
		dim = create_tween()
		dim.tween_property(self, "modulate:a", opacity, duration)
	phase = 0
	queue_redraw()
	if active:
		var key := "stands.player_stand_pulse" if side < 0 else "stands.opponent_stand_pulse"
		var spec: Dictionary = profiles[key].pulse
		if spec.enabled and spec.duration_ms > 0:
			pulse = create_tween().set_loops()
			pulse.tween_property(self, "phase", 1.0, spec.duration_ms / 2000.0).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(self, "phase", 0.0, spec.duration_ms / 2000.0).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	if team.is_empty():
		return
	var design: Vector2 = App.design_size
	var w := design.x
	var h := design.y
	var config: Dictionary = App.config.data.stands_layout.world
	var jersey := Color(team.primary_color)
	var alternate := Color(team.secondary_color)
	var paper := Color(team.text_color)
	var ink := Color("#183746")
	var skin := Color("#d7aa78")
	var rows: int = config.rows
	var columns: int = config.columns
	for row in rows:
		var y: float = h * (config.crowd_top + row * config.row_step)
		var fan_h: float = h * (config.fan_height_min + row * config.fan_height_step)
		var near_x := w * (.025 - row * .012)
		var far_x := w * (.435 + row * .007)
		var tier := PackedVector2Array([Vector2(near_x,y-h*.01),Vector2(far_x,y+h*config.edge_rise),Vector2(far_x,y+h*config.edge_rise+fan_h*.64),Vector2(near_x,y+fan_h*.64)])
		if side > 0:
			for i in tier.size():tier[i].x = w-tier[i].x
		draw_colored_polygon(tier,Color("#a7ada1") if row%2 else Color("#8e9d94"))
		for col in columns:
			var f := (col+.35)/columns
			var x := lerpf(near_x,far_x,f)
			var feet := Vector2(x,y + h*config.edge_rise*f)
			if side > 0:feet.x = w-feet.x
			var hh := fan_h * (1.0-f*.18)
			var color := jersey if (col+row)%3 else alternate
			draw_line(feet+Vector2(-hh*.10,-hh*.25),feet+Vector2(-hh*.12,0),ink,hh*.08,true)
			draw_line(feet+Vector2(hh*.10,-hh*.25),feet+Vector2(hh*.12,0),ink,hh*.08,true)
			draw_rect(Rect2(feet+Vector2(-hh*.17,-hh*.65),Vector2(hh*.34,hh*.42)),color)
			draw_circle(feet+Vector2(0,-hh*.80),hh*.12,skin)
			draw_arc(feet+Vector2(0,-hh*.82),hh*.11,PI,TAU,10,ink,hh*.05,true)
			for arm in [-1,1]:
				var wrist := feet+Vector2(arm*hh*.27,-hh*(.48 + (.28 if active else .02)))
				draw_line(feet+Vector2(arm*hh*.13,-hh*.59),wrist,color,hh*.075,true)
				draw_circle(wrist,hh*.045,skin)
			if col%4==row%4:
				var flag := feet+Vector2(hh*.28,-hh*1.02)
				draw_line(feet+Vector2(hh*.28,-hh*.5),flag,ink,2,true)
				draw_rect(Rect2(flag,Vector2(hh*.48,hh*.28)),color)
				draw_rect(Rect2(flag+Vector2(0,hh*.12),Vector2(hh*.48,hh*.07)),paper)
		var banner_y: float = y+fan_h*.29
		var banner := PackedVector2Array([Vector2(near_x,banner_y),Vector2(far_x,banner_y+h*config.edge_rise),Vector2(far_x,banner_y+h*config.edge_rise+fan_h*.27),Vector2(near_x,banner_y+fan_h*.27)])
		if side>0:
			for i in banner.size():banner[i].x=w-banner[i].x
		draw_colored_polygon(banner,jersey if row%2 else alternate)
		for block in 8:
			var f := (block+.25)/8
			var xx := lerpf(near_x,far_x,f)
			if side>0:xx=w-xx
			draw_line(Vector2(xx,banner_y+h*config.edge_rise*f),Vector2(xx,banner_y+h*config.edge_rise*f+fan_h*.26),paper,fan_h*.12,true)

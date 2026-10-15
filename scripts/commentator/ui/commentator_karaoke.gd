extends Control
const UI=preload("res://scripts/ui/ui_factory.gd")
const Regular=preload("res://assets/commentator/fonts/DejaVuSans.ttf")
const Bold=preload("res://assets/commentator/fonts/DejaVuSans-Bold.ttf")
var content: Control
var words: Dictionary={}
var turn_seen:=-1

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel:=Panel.new()
	panel.size=size
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",UI.style(UI.INK.lightened(.08),UI.PAPER,18))
	add_child(panel)
	content=Control.new()
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(content)

func present(model: RefCounted) -> void:
	var turn_index: int=model.timeline.turn_at(model.elapsed)
	if turn_index!=turn_seen:
		turn_seen=turn_index
		for child in content.get_children():
			content.remove_child(child)
			child.queue_free()
		words.clear()
		var turn: Dictionary=model.timeline.turns[turn_index]
		var spec: Dictionary=App.config.data.commentator_layout.karaoke
		if turn.speaker=="host":
			UI.label(content,turn.text,Rect2(Vector2.ZERO,size),spec.host_font_size,UI.PAPER)
		else:_build_words(model,turn_index)
	for index in words:
		var word: Dictionary=model.timeline.words[index]
		var state:="active" if model.elapsed>=word.start_sec and model.elapsed<word.end_sec else ("passed" if model.elapsed>=word.end_sec else "waiting")
		var label: Label=words[index]
		if label.get_meta("state","")!=state:
			label.set_meta("state",state)
			label.add_theme_color_override("font_color",Color(App.config.data.commentator_layout.karaoke[state+"_color"]))
			App.animations.play(label,"commentator.word")

func _build_words(model: RefCounted, turn_index: int) -> void:
	var spec: Dictionary=App.config.data.commentator_layout.karaoke
	var available: float=size.x-2*spec.padding_px
	var lines: Array=[[]]
	var widths: Array[float]=[0.0]
	for index in model.timeline.word_indices(turn_index):
		var word: Dictionary=model.timeline.words[index]
		var font: Font=Bold if word.emphasis else Regular
		var width:=font.get_string_size(word.text,HORIZONTAL_ALIGNMENT_LEFT,-1,spec.font_size).x+4
		var gap: float=spec.word_gap_px if widths[-1]>0 else 0
		if widths[-1]+gap+width>available and not lines[-1].is_empty():
			lines.append([])
			widths.append(0.0)
			gap=0
		lines[-1].append({"index":index,"width":width,"font":font})
		widths[-1]+=gap+width
	var top: float=(size.y-lines.size()*spec.line_height_px)/2+spec.padding_px/2
	for row in lines.size():
		var x: float=(size.x-widths[row])/2
		for entry in lines[row]:
			var word: Dictionary=model.timeline.words[entry.index]
			var label:=UI.label(content,word.text,Rect2(x,top+row*spec.line_height_px,entry.width,spec.line_height_px),spec.font_size,UI.PAPER)
			label.add_theme_font_override("font",entry.font)
			words[entry.index]=label
			if word.emphasis:
				var arrow:=UI.label(content,str(spec.arrow_text).repeat(int(word.arrows)),Rect2(x,label.position.y+spec.arrow_offset_px,entry.width,spec.arrow_font_size+4),spec.arrow_font_size,UI.PAPER)
				arrow.name="EmphasisArrows"+str(entry.index)
				arrow.add_theme_font_override("font",Bold)
				_pulse(arrow)
			x+=entry.width+spec.word_gap_px

func _pulse(arrow: Label) -> void:
	var profile: Dictionary=App.config.data.ui_animations.profiles["commentator.arrow"].pulse
	var duration: float=profile.durationMs/2000.0
	if duration<=0:return
	var y:=arrow.position.y
	arrow.modulate.a=profile.minOpacity
	var tween:=arrow.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arrow,^"position:y",y-profile.risePx,duration)
	tween.parallel().tween_property(arrow,^"modulate:a",profile.maxOpacity,duration)
	tween.tween_property(arrow,^"position:y",y,duration)
	tween.parallel().tween_property(arrow,^"modulate:a",profile.minOpacity,duration)

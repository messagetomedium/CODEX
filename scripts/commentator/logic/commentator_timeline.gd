extends RefCounted
## Absolute authoring times; highlighting never waits for microphone input.
var level: Dictionary
var turns: Array
var words: Array[Dictionary] = []

func _init(data: Dictionary) -> void:
	level=data
	turns=data.turns
	for i in turns.size():
		for source in turns[i].get("words",[]):
			var word: Dictionary=source.duplicate(true)
			word.turn_index=i
			words.append(word)

func turn_at(seconds: float) -> int:
	for i in turns.size():
		if seconds<float(turns[i].end_sec):return i
	return turns.size()-1

func active_word(seconds: float) -> int:
	for i in words.size():
		if seconds>=float(words[i].start_sec) and seconds<float(words[i].end_sec):return i
	return -1

func word_indices(turn_index: int) -> Array[int]:
	var indices: Array[int]=[]
	for i in words.size():
		if words[i].turn_index==turn_index:indices.append(i)
	return indices

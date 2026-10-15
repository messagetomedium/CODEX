extends RefCounted
## Apply a difficulty profile to a copy, leaving shared microphone tuning intact.

static func for_round(source: Dictionary, number: int) -> Dictionary:
	assert(number >= 1 and number <= source.rounds.size())
	var result := source.duplicate(true)
	var profile: Dictionary = source.rounds[number - 1]
	result.round.number = number
	for group in ["defender", "goalkeeper"]:
		result[group].merge(profile[group].duplicate(true), true)
	return result

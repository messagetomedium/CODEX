extends RefCounted
## Amplitude/timing assessment only; no word recognition, pitch or recordings.
var word: Dictionary
var settings: Dictionary
var profile: Dictionary
var active_seconds:=0.0
var energy:=0.0
var baseline:=0.35
var baseline_captured:=false
var onset_offset:=INF
var finalized:=false
var result: Dictionary={}

func _init(data: Dictionary, config: Dictionary, difficulty: Dictionary) -> void:
	word=data
	settings=config
	profile=difficulty
	baseline=config.baseline_initial

func integrate(from: float, until: float, loudness: float, voice_base: float) -> void:
	var dt:=maxf(0,minf(until,word.end_sec)-maxf(from,word.start_sec))
	if finalized or dt<=0 or loudness<settings.voice_threshold:return
	if not baseline_captured:
		baseline=voice_base
		baseline_captured=true
	active_seconds+=dt
	energy+=loudness*dt

func onset(seconds: float) -> void:
	if finalized:return
	var offset:=seconds-float(word.start_sec)
	if absf(offset)<absf(onset_offset):onset_offset=offset

func finish() -> Dictionary:
	if finalized:return result
	finalized=true
	var coverage:=clampf(active_seconds/(float(word.end_sec)-float(word.start_sec)),0,1)
	var timing: float=settings.fallback_timing if onset_offset==INF else clampf(1-absf(onset_offset)/(2*profile.onset_tolerance_sec),0,1)
	var activity:=clampf(coverage/settings.coverage_target,0,1)
	var mean:=energy/maxf(active_seconds,.000001)
	var ratio:=mean/maxf(baseline,.001)
	var volume:=clampf((ratio-1)/settings.emphasis_boost_ratio,0,1) if word.emphasis else clampf(minf(ratio,1)-maxf(0,ratio-settings.normal_loud_ratio)*.3,0,1)
	var score: float=100*(settings.timing_weight*timing+settings.activity_weight*activity+settings.volume_weight*volume)
	if onset_offset==INF:score=minf(score,settings.no_rhythm_cap)
	if word.emphasis and ratio<1+settings.emphasis_boost_ratio:score=minf(score,settings.weak_emphasis_cap)
	if coverage<settings.weak_activity_ratio:score=minf(score,settings.weak_activity_cap)
	if active_seconds<=0:score=0
	var status:="missing" if onset_offset==INF else ("early" if onset_offset < -profile.onset_tolerance_sec else ("late" if onset_offset>profile.onset_tolerance_sec else "on_time"))
	result={"score":clampf(score,0,100),"hit":score>=settings.word_hit_score and status=="on_time","timing_status":status,"coverage":coverage,"mean_loudness":mean,"baseline":baseline}
	return result

extends RefCounted
## Render remote actors on a short delayed timeline, with bounded extrapolation for jitter.
const DELAY:=.15
const MAX_EXTRAPOLATION:=.12
const CLOCK_WINDOW:=1.0
const CLOCK_DRIFT:=.05
var samples: Array=[]
var last_tick:=-1
var clock_offset:=INF
var offset_samples: Array=[]
var rendered_at:=-INF
func push(row: Dictionary,tick: int,now: float) -> void:
	if tick<=last_tick:return
	last_tick=tick
	var offset:=now-float(tick)/60
	# Physics ticks can fall behind wall time during a building update. A lifetime
	# minimum would leave every later packet outside the interpolation window.
	offset_samples.append({"at":now,"offset":offset})
	while now-float(offset_samples[0].at)>CLOCK_WINDOW:offset_samples.pop_front()
	var recent_offset:=offset
	for entry in offset_samples:recent_offset=minf(recent_offset,float(entry.offset))
	if recent_offset<clock_offset or recent_offset>clock_offset+CLOCK_DRIFT:
		if is_finite(clock_offset):
			var shift:=recent_offset-clock_offset
			for sample_ in samples:sample_.at+=shift
			rendered_at+=shift
		clock_offset=recent_offset
	if not samples.is_empty():
		var old: Dictionary=samples[-1].row
		if old.get("generation",0)!=row.get("generation",0) or point(old.position).distance_to(point(row.position))>4:samples.clear();rendered_at=-INF
	samples.append({"row":row.duplicate(true),"at":float(tick)/60+clock_offset})
	if samples.size()>16:samples.pop_front()
func sample(now: float) -> Dictionary:
	if samples.is_empty():return {}
	# Recalibration may briefly hold the pose, but must never rewind a walk/jump.
	var target:=maxf(now-DELAY,rendered_at)
	while samples.size()>2 and float(samples[1].at)<=target:samples.pop_front()
	var a: Dictionary=samples[0]
	if target<=float(a.at):rendered_at=float(a.at);return a.row
	if samples.size()>1:
		var b: Dictionary=samples[1]
		if target<=float(b.at):
			rendered_at=target
			var ratio:=clampf((target-float(a.at))/maxf(.001,float(b.at)-float(a.at)),0,1)
			var row: Dictionary=b.row.duplicate(true)
			var p:=point(a.row.position).lerp(point(b.row.position),ratio)
			row.position=[p.x,p.y,p.z];row.yaw=lerp_angle(float(a.row.get("yaw",0)),float(b.row.get("yaw",0)),ratio)
			return row
	var row: Dictionary=samples[-1].row.duplicate(true)
	if not row.get("pose",{}).is_empty() or row.get("sleeping",false):rendered_at=float(samples[-1].at);return row
	var age:=clampf(target-float(samples[-1].at),0,MAX_EXTRAPOLATION)
	rendered_at=float(samples[-1].at)+age
	var p:=point(row.position)+point(row.get("velocity",[0,0,0]))*age
	if not row.get("grounded",true):p.y-=9*age*age
	row.position=[p.x,p.y,p.z]
	return row
func point(p: Array) -> Vector3:return Vector3(p[0],p[1],p[2])

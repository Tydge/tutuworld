extends Node
var bunny: CharacterBody3D
var route: Array[Vector3]=[]
var index:=0
var previous_index:=-1
var wait:=0.0
var speed:=1.45
var city: Node3D
var rng:=RandomNumberGenerator.new()
var path:=PackedVector3Array()
var path_index:=0
var recent: Array[int]=[]
var progress_clock:=0.0
var progress_origin:=Vector3.ZERO
var wall_time:=0.0
var recovery_time:=0.0
var recovery_motion:=Vector3.ZERO
var last_normal:=Vector3.ZERO
var recovery_count:=0
var repath_count:=0
var cooldown:=0.0
func _ready() -> void:
	rng.randomize()
	progress_origin=bunny.position
func choose_destination() -> void:
	if city==null or not city.navigation.ready_for_paths: return
	for attempt in range(24):
		var candidate: int
		var destination: Vector3
		if route.is_empty():
			var choice: Dictionary=city.navigation.random_destination(bunny.position,rng,recent)
			if choice.is_empty(): return
			candidate=choice.zone;destination=choice.position
		else:
			candidate=rng.randi_range(0,route.size()-1);destination=route[candidate]
			if recent.has(candidate): continue
		if destination.distance_to(bunny.position)<3: continue
		var next: PackedVector3Array=city.navigation.path_between(bunny.position,destination)
		if next.size()<2: continue
		previous_index=index
		index=candidate
		recent.append(candidate)
		if recent.size()>4: recent.pop_front()
		path=next
		path_index=0
		progress_clock=0
		progress_origin=bunny.position
		wall_time=0
		speed=rng.randf_range(1.10,1.65)*bunny.rig_profile.walk_speed_scale
		repath_count+=1
		return
	path.clear()
	wait=.5
func recover() -> void:
	recovery_count+=1
	var away:=last_normal
	if away.length_squared()<.1:
		away=Vector3(-bunny.velocity.z,0,bunny.velocity.x).normalized()
		if away.length_squared()<.1: away=Vector3(cos(rng.randf()*TAU),0,sin(rng.randf()*TAU))
	var tangent:=Vector3(-away.z,0,away.x)*rng.randf_range(-.7,.7)
	recovery_motion=(away+tangent).normalized()
	recovery_time=rng.randf_range(.38,.65)
	cooldown=1.0
	wall_time=0
	progress_clock=0
	progress_origin=bunny.position
	path.clear()
func _physics_process(delta: float) -> void:
	if bunny==null or city==null or not city.navigation.ready_for_paths: return
	var chatting: bool=city.talking_npc==bunny.name
	var partner: CharacterBody3D=city.bunny
	if city.has_method("chatting_with"):
		partner=city.chatting_with(str(bunny.name));chatting=is_instance_valid(partner)
	wait=maxf(0,wait-delta)
	cooldown=maxf(0,cooldown-delta)
	if not chatting and path.is_empty() and wait<=0 and recovery_time<=0: choose_destination()
	var direction:=Vector3.ZERO
	if recovery_time>0 and not chatting:
		direction=recovery_motion
		recovery_time=maxf(0,recovery_time-delta)
		if recovery_time==0: choose_destination()
	elif path_index<path.size():
		direction=path[path_index]-bunny.position
		direction.y=0
		if direction.length()<.32:
			path_index+=1
			if path_index>=path.size():
				path.clear()
				wait=rng.randf_range(.5,3.5) if rng.randf()<.50 else 0
				direction=Vector3.ZERO
			else:
				direction=path[path_index]-bunny.position
				direction.y=0
	var stopped:=chatting or wait>0 or direction.length_squared()<.001
	var separation:=Vector3.ZERO
	if not stopped:
		for other in city.npcs: separation+=separation_from(other)
		separation+=separation_from(city.bunny)
	var steering: Vector3=direction.normalized()+separation
	var target:=Vector3.ZERO if stopped else steering.normalized()*speed
	if not bunny.is_on_floor(): bunny.velocity.y-=18*delta
	if chatting:
		bunny.velocity.x=0
		bunny.velocity.z=0
	else:
		bunny.velocity.x=move_toward(bunny.velocity.x,target.x,delta*6)
		bunny.velocity.z=move_toward(bunny.velocity.z,target.z,delta*6)
	if not city.can_walk(bunny.position+Vector3(bunny.velocity.x,0,bunny.velocity.z)*delta):
		bunny.velocity.x=0;bunny.velocity.z=0
		last_normal=Vector3(-bunny.position.x,0,-bunny.position.z).normalized()
		if cooldown<=0: recover()
	bunny.move_on_ground(delta)
	bunny.walking=not stopped and Vector2(bunny.velocity.x,bunny.velocity.z).length()>.15
	if chatting:
		var face: Vector3=partner.position-bunny.position
		bunny.visual.rotation.y=lerp_angle(bunny.visual.rotation.y,atan2(face.x,face.z),1-exp(-delta*9))
	elif bunny.walking:
		bunny.visual.rotation.y=lerp_angle(bunny.visual.rotation.y,atan2(bunny.velocity.x,bunny.velocity.z),1-exp(-delta*7))
		bunny.step_phase+=delta*7
	var hit_wall:=false
	for i in range(bunny.get_slide_collision_count()):
		var collision:=bunny.get_slide_collision(i)
		var normal:=collision.get_normal()
		if absf(normal.y)<.5:
			hit_wall=true
			last_normal=Vector3(normal.x,0,normal.z).normalized()
	if stopped:
		progress_clock=0
		progress_origin=bunny.position
		wall_time=0
	else:
		wall_time=wall_time+delta if hit_wall else maxf(0,wall_time-delta*2)
		progress_clock+=delta
		if cooldown<=0 and wall_time>.55: recover()
		elif progress_clock>=1.2:
			if cooldown<=0 and bunny.position.distance_to(progress_origin)<.28: recover()
			progress_clock=0
			progress_origin=bunny.position
func separation_from(other: CharacterBody3D) -> Vector3:
	if other==bunny: return Vector3.ZERO
	var away: Vector3=bunny.position-other.position
	away.y=0
	var clearance: float=bunny.rig_profile.head_radii.x+other.rig_profile.head_radii.x+.35
	var squared:=away.length_squared()
	if squared<.0001 or squared>=clearance*clearance: return Vector3.ZERO
	var gap:=sqrt(squared)
	return away/gap*(1-gap/clearance)*1.6

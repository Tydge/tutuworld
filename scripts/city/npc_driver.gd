extends Node

const SERVER_STEP_INTERVAL := 3
var bunny: CharacterBody3D
var route: Array[Vector3]=[]
var use_local_neighbours:=false
var local_neighbours: Array=[]
var nearby_players: Array=[]
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
var server_step_phase := 0
var server_step_elapsed := 0.0
func _ready() -> void:
	rng.randomize()
	progress_origin=bunny.position
	server_step_phase = posmod(str(bunny.name).hash(), SERVER_STEP_INTERVAL)
func choose_destination() -> void:
	if city==null or not city.navigation.ready_for_paths: return
	if route.size()==1:
		if bunny.position.distance_to(route[0])<1.2:
			wait=1.0
			return
	var tried: Array[int]=[]
	for attempt in range(1 if route.size()==1 else 24):
		var candidate: int
		var destination: Vector3
		if route.is_empty():
			var choice: Dictionary=city.navigation.random_destination(bunny.position,rng,recent)
			if choice.is_empty(): return
			candidate=choice.zone;destination=choice.position
		else:
			candidate=rng.randi_range(0,route.size()-1);destination=route[candidate]
			if recent.has(candidate) or tried.has(candidate):continue
			tried.append(candidate)
		if route.size()!=1 and destination.distance_to(bunny.position)<3:continue
		var next: PackedVector3Array=city.navigation.path_between(bunny.position,destination)
		if next.size()<2: continue
		if route.size()!=1:recent.append(candidate)
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
	recovery_motion=walkable_recovery((away+tangent).normalized())
	recovery_time=rng.randf_range(.38,.65)
	cooldown=1.0
	wall_time=0
	progress_clock=0
	progress_origin=bunny.position
	path.clear()
func walkable_recovery(preferred: Vector3) -> Vector3:
	# A clear grid cell can sit beyond an unwalkable strip between samples.
	# Repeatedly steering straight toward it traps the actor in the same place.
	# Check the intervening floor before choosing a short turn around the strip.
	# Probe the preferred escape first. Ranking before tracing avoids repeating dozens
	# of floor queries once a safe turn with the highest score has been found.
	var turns: Array[Vector3]=[]
	var scores:=PackedFloat32Array()
	for i in range(16):
		var angle:=TAU*i/16.
		var direction:=Vector3(cos(angle),0,sin(angle))
		turns.append(direction)
		scores.append(direction.dot(preferred)+rng.randf_range(0,.15))
	var order: Array=range(turns.size())
	order.sort_custom(func(a,b):return scores[a]>scores[b])
	for i: int in order:
		var clear:=true
		for distance in [.01,.04,.10]:
			var point: Vector3=bunny.position+turns[i]*distance
			if not city.can_walk(point) or not city.navigation.can_step(bunny.position,point,use_local_neighbours or bunny.server_resident):
				clear=false;break
		if clear:return turns[i]
	return Vector3.ZERO
func _physics_process(delta: float) -> void:
	if bunny==null or city==null or not city.navigation.ready_for_paths: return
	var step_scale := 1.0
	if bunny.server_resident:
		# Spread expensive clearance and collision work across physics ticks.
		# Each server step integrates the full elapsed time. Clients still
		# interpolate the same 10 Hz authoritative positions.
		server_step_elapsed += delta
		if Engine.get_physics_frames() % SERVER_STEP_INTERVAL != server_step_phase:
			return
		step_scale = server_step_elapsed / delta
		delta = server_step_elapsed
		server_step_elapsed = 0.0
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
	if use_local_neighbours and not chatting:
		var aside:=give_way()
		if aside!=Vector3.ZERO:
			direction=aside
			if not bunny.action.is_empty():bunny.action="";bunny.mood_label.text=""
			wait=0.
	var stopped:=chatting or wait>0 or direction.length_squared()<.001
	var separation:=Vector3.ZERO
	if not stopped:
		for other in (local_neighbours if use_local_neighbours else city.npcs): separation+=separation_from(other)
		if use_local_neighbours:
			for visitor in nearby_players:
				if is_instance_valid(visitor):separation+=separation_from(visitor)
		else:separation+=separation_from(city.bunny)
	var steering: Vector3=direction.normalized()+separation
	var target:=Vector3.ZERO if stopped else steering.normalized()*speed
	if not bunny.is_on_floor(): bunny.velocity.y-=18*delta
	if chatting:
		bunny.velocity.x=0
		bunny.velocity.z=0
	else:
		# Preserve the selected turn when accelerating from rest. Independent axes
		# initially produce a diagonal that may point straight back into the strip.
		var horizontal:=Vector2(bunny.velocity.x,bunny.velocity.z).move_toward(Vector2(target.x,target.z),delta*6)
		bunny.velocity.x=horizontal.x;bunny.velocity.z=horizontal.y
	var next_position:=bunny.position+Vector3(bunny.velocity.x,0,bunny.velocity.z)*delta
	var moving:=Vector2(bunny.velocity.x,bunny.velocity.z).length_squared()>.0001
	if moving and (not city.can_walk(next_position) or not city.navigation.can_step(bunny.position,next_position,use_local_neighbours or bunny.server_resident)):
		bunny.velocity.x=0;bunny.velocity.z=0
		var safe: Vector2i=city.navigation.closest_free(bunny.position)
		last_normal=(Vector3(safe.x,bunny.position.y,safe.y)-bunny.position).normalized() if safe.x!=999 else -direction.normalized()
		if cooldown<=0: recover()
	if step_scale > 1.0:
		# CharacterBody3D uses the engine's fixed tick. Preserve the step
		# distance, then restore metres per second for replication/steering.
		bunny.velocity *= step_scale
		bunny.move_on_ground(delta)
		bunny.velocity /= step_scale
	else:
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
# Stop short of a visitor's line, including when the visitor is another online player.
func give_way() -> Vector3:
	for candidate in nearby_players:
		if not is_instance_valid(candidate):continue
		var visitor: CharacterBody3D=candidate
		var offset:=bunny.position-visitor.position
		if offset.length_squared()>=4.84 or absf(offset.y)>=1.:continue
		var approach: Vector2=visitor.walking_intent
		if approach.length_squared()<=.16:approach=Vector2(visitor.velocity.x,visitor.velocity.z)
		if approach.length_squared()<=.16:continue
		var forward:=approach.normalized()
		var lateral:=Vector2(-forward.y,forward.x)
		var gap:=Vector2(offset.x,offset.z)
		var side:=gap.dot(lateral)
		if gap.dot(forward)>.05 and absf(side)<1.25:return Vector3(lateral.x,0,lateral.y)*(1. if side>=0. else -1.)
	return Vector3.ZERO
func separation_from(other: CharacterBody3D) -> Vector3:
	if other==bunny: return Vector3.ZERO
	var away: Vector3=bunny.position-other.position
	away.y=0
	var clearance: float=bunny.rig_profile.head_radii.x+other.rig_profile.head_radii.x+.35
	var squared:=away.length_squared()
	if squared<.0001 or squared>=clearance*clearance: return Vector3.ZERO
	var gap:=sqrt(squared)
	return away/gap*(1-gap/clearance)*1.6

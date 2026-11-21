extends RefCounted
const GRAVITY := 9.81
const SPEED := 1.22
const HOLES := [Vector2(-.06,-.04), Vector2(0,-.04), Vector2(.06,-.04),
	Vector2(-.06,.025), Vector2(0,.025), Vector2(.06,.025)]

static func approach(actor: CharacterBody3D, bed: Vector3) -> void:
	var away := actor.global_position - bed
	away.y = 0
	var distance_ := away.length()
	if distance_ < .001:
		away = -actor.visual.global_basis.z
		away.y = 0
	actor.work_position = bed + away.normalized() * clampf(distance_, .76, 1.65)
	actor.work_position.y = actor.global_position.y
	actor.work_align_active = actor.global_position.distance_to(actor.work_position) > .035

static func hold(actor: CharacterBody3D, can: Node3D, phase: float) -> void:
	var tilt := smoothstep(.05,.34,phase) * (1.-smoothstep(.78,1.,phase))
	var forward: Vector3 = actor.visual.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var level := Basis(Vector3.UP.cross(forward),Vector3.UP,forward)
	var angle := lerpf(-.05,.63,tilt)
	var scale_ := .78 if actor.rig_profile.species_id=="bunny" else .86
	var basis := (level * Basis(Vector3.RIGHT, angle)).scaled_local(Vector3.ONE*scale_)
	var grip_center: Vector3 = (can.get_node("GripR").position+can.get_node("GripL").position)*.5
	var height: float = actor.arm_rest_right.y-.22+tilt*.12
	var reach: float = actor.rig_profile.body_radii.z+.28+.06*tilt
	var handle: Vector3 = actor.visual.global_position + level*Vector3(0,height,reach)
	can.global_transform = Transform3D(basis,handle-basis*grip_center)
	for side in [-1,1]:
		var arm: Node3D = actor.left_arm if side<0 else actor.right_arm
		var shoulder: Vector3 = actor.arm_rest_left if side<0 else actor.arm_rest_right
		arm.position = shoulder + Vector3(-side*.028,-.025,.065)*tilt
		actor.aim_hand(arm,can.get_node("GripL" if side<0 else "GripR").global_position,side<0)

static func velocity(nozzle: Basis, hole: Vector2 = Vector2.ZERO) -> Vector3:
	return (nozzle * Vector3(hole.x*1.6,hole.y*1.6,1)).normalized()*SPEED

static func flight(start_y: float, speed_y: float, floor_y: float) -> float:
	return maxf(0., (speed_y+sqrt(maxf(0.,speed_y*speed_y+2.*GRAVITY*(start_y-floor_y))))/GRAVITY)

static func landing(start: Vector3, speed: Vector3, seconds: float) -> Vector3:
	return start + speed*seconds - Vector3.UP*(.5*GRAVITY*seconds*seconds)

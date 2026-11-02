extends CharacterBody3D
const SleepPose=preload("res://scripts/characters/sleep_pose.gd")
## Shared semantic rig: four limb pivots, head, eyes, mouth and wearable slots.
@export var rig_profile: Resource = preload("res://config/animals/bunny.tres")
signal movement_predicted(direction: Vector3,jump: bool,running: bool)
signal landed
var visual: Node3D
var head: Node3D
var eyes: Node3D
var mouth: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var ears: Array[Node3D] = []
var mood_label: Label3D
var held_cup: Node3D
var clock := 0.0
var step_phase := 0.0
var gait_blend := 0.0
var run_blend := 0.0
var blink_in := 4.8
var blink_time := -1.0
var action := ""
var action_time := 0.0
var action_length := 0.0
var walking := false
var seated := false
var was_on_floor := true
var facing := 0.0
var can_move := true
var move_speed := 2.8
var speed_multiplier := 1.0
var run_speed_multiplier := 1.0
var stamina_fraction:=1.0
var run_enabled:=false
var is_running:=false
var leg_rest_left:=Vector3.ZERO
var leg_rest_right:=Vector3.ZERO
var arm_rest_left:=Vector3.ZERO
var arm_rest_right:=Vector3.ZERO
var floor_query: PhysicsRayQueryParameters3D
var step_floor_offset:=.005
const SPRINT_MULTIPLIER := 1.7
var world: Node3D
var sleeping:=false
var work_align_active:=false
var work_position:=Vector3.ZERO
var head_rest_position:=Vector3.ZERO
var sleep_collision_layer:=2
var network_controlled:=false
var network_direction:=Vector3.ZERO
var network_jump:=false
var network_replica:=false
var network_grounded:=true
var network_client_prediction:=false
var network_sequenced:=false
var network_generation:=1
var network_ack:=0
var network_received:=0
var network_queue: Array=[]
var network_budget:=0.0
var network_idle:=0.0
var network_restore_grounded: Variant=null
var presentation_offset:=Vector3.ZERO
var presentation_applied:=Vector3.ZERO
const INPUT_STEP:=1.0/60.0
func reset_network_motion() -> void:
	network_generation+=1;network_ack=0;network_received=0;network_queue.clear();network_budget=0
	network_direction=Vector3.ZERO;network_jump=false
func movement_state() -> Dictionary:
	return {"position":[position.x,position.y,position.z],"velocity":[velocity.x,velocity.y,velocity.z],"grounded":is_on_floor()}
func restore_movement_state(value: Dictionary) -> void:
	var p: Array=value.position;var v: Array=value.velocity
	position=Vector3(p[0],p[1],p[2]);velocity=Vector3(v[0],v[1],v[2])
	network_restore_grounded=bool(value.get("grounded",false));was_on_floor=network_restore_grounded


func _ready() -> void:
	visual = $Visual
	head = $Visual/Head
	head_rest_position=head.position
	eyes = $Visual/Head/Eyes
	mouth = $Visual/Head/Mouth
	left_arm = $Visual/LeftArm
	right_arm = $Visual/RightArm
	left_leg = $Visual/LeftLeg
	right_leg = $Visual/RightLeg
	ears = [$Visual/Head/LeftEar, $Visual/Head/RightEar]
	mood_label = $Mood
	held_cup = $Visual/RightArm/Cup
	leg_rest_left=left_leg.position
	leg_rest_right=right_leg.position
	arm_rest_left=left_arm.position
	arm_rest_right=right_arm.position
	facing = visual.rotation.y
	floor_query=PhysicsRayQueryParameters3D.new()
	floor_query.collision_mask=8
	for child in get_children():
		if not child is CollisionShape3D or child.disabled:continue
		var half_height:=0.0
		if child.shape is BoxShape3D:half_height=child.shape.size.y*.5
		elif child.shape is CapsuleShape3D or child.shape is CylinderShape3D:half_height=child.shape.height*.5
		elif child.shape is SphereShape3D:half_height=child.shape.radius
		step_floor_offset=maxf(step_floor_offset,half_height-child.position.y+safe_margin+.004)

func toggle_run() -> void:
	if run_enabled: run_enabled=false
	elif stamina_fraction>.0001: run_enabled=true
func play_action(kind: String, duration: float, symbol: String = "") -> void:
	action = kind
	action_time = 0.0
	action_length = duration
	mood_label.text = symbol
	held_cup.visible = kind == "tea"

func sit_on(seat: Transform3D) -> void:
	seated = true
	can_move = false
	walking = false
	velocity = Vector3.ZERO
	global_position = seat.origin
	reset_physics_interpolation()
	visual.rotation.y = seat.basis.get_euler().y
	facing = visual.rotation.y

func sit_on_surface(seat: Transform3D) -> void:
	seat.origin.y-=rig_profile.body_center.y-rig_profile.body_radii.y-.018
	sit_on(seat)
func stand_up(exit_position: Vector3) -> void:
	sleeping=false
	collision_layer=sleep_collision_layer
	action="";eyes.scale.y=1;head.position=head_rest_position
	visual.rotation.x=0;visual.rotation.z=0
	seated = false
	can_move = true
	velocity = Vector3.ZERO
	global_position = exit_position
	reset_physics_interpolation()
func lie_in_bed(bed: Node3D) -> void:
	sleep_collision_layer=collision_layer;collision_layer=0
	var pose:=SleepPose.layout(rig_profile)
	sit_on(Transform3D(bed.global_basis,bed.to_global(pose.root)))
	sleeping=true;run_enabled=false;is_running=false
	play_action("sleep",INF)
	visual.rotation.x=SleepPose.BODY_ANGLE
	head.position=pose.head;head.rotation=Vector3(SleepPose.HEAD_ANGLE,0,0)

func _physics_process(delta: float) -> void:
	visual.position-=presentation_applied;presentation_applied=Vector3.ZERO
	presentation_offset*=exp(-delta*14)
	animate_pose(delta)
	presentation_applied=presentation_offset;visual.position+=presentation_applied
	if network_replica or world==null:return
	if network_sequenced:
		network_idle+=delta
		network_budget=minf(120,network_budget+delta*60)
		var count_: int=mini(8,mini(network_queue.size(),int(network_budget)))
		for i in range(count_):
			network_idle=0
			var input: Dictionary=network_queue.pop_front();network_budget-=1
			run_enabled=bool(input.running)
			simulate_movement(INPUT_STEP,Vector3(input.direction[0],0,input.direction[2]),bool(input.jump),false)
			network_ack=int(input.seq)
		if count_==0 and network_idle>.3:simulate_movement(delta,Vector3.ZERO,false,false)
		return
	if stamina_fraction<=.0001:run_enabled=false
	var text_entry: bool=world.has_method("is_text_entry_active") and world.is_text_entry_active()
	if not network_controlled and Input.is_action_just_pressed("sprint") and can_move and action=="" and not world.paused and not text_entry:toggle_run()
	var axis:=Input.get_vector("move_left","move_right","move_up","move_down")
	var yaw: float=world.yaw
	var direction:=Vector3(cos(yaw),0,-sin(yaw))*axis.x+Vector3(sin(yaw),0,cos(yaw))*axis.y
	if network_controlled:direction=network_direction
	var jump: bool=network_jump if network_controlled else Input.is_action_just_pressed("jump")
	if network_client_prediction and not world.session.test_mode and not DisplayServer.window_is_focused():direction=Vector3.ZERO;jump=false
	if not can_move or action!="" or world.paused or text_entry:direction=Vector3.ZERO;jump=false
	simulate_movement(delta,direction,jump,true)
	network_jump=false
	if network_client_prediction:movement_predicted.emit(direction,jump,run_enabled)
func simulate_movement(delta: float,direction: Vector3,jump: bool,feedback: bool=true,replay: bool=false) -> void:
	is_running=false
	if seated:velocity=Vector3.ZERO;walking=false;return
	if stamina_fraction<=.0001:run_enabled=false
	var text_entry: bool=world.has_method("is_text_entry_active") and world.is_text_entry_active()
	if not can_move or action!="" or (not replay and (world.paused or text_entry)):direction=Vector3.ZERO;jump=false
	direction=direction.limit_length(1)
	var grounded: bool=is_on_floor() if network_restore_grounded==null else bool(network_restore_grounded)
	network_restore_grounded=null
	if work_align_active:
		var offset:=work_position-global_position;offset.y=0
		if offset.length()<.035 or action=="": work_align_active=false
		else: direction=offset.normalized()
	var base_speed:=move_speed*speed_multiplier
	var target_speed := minf(2.4,global_position.distance_to(work_position)*12.0) if work_align_active else base_speed*(SPRINT_MULTIPLIER*run_speed_multiplier if run_enabled else 1.0)
	var acceleration := 20.0 if direction.length_squared()>.01 else 24.0
	velocity.x = move_toward(velocity.x,direction.x*target_speed,acceleration*delta)
	velocity.z = move_toward(velocity.z,direction.z*target_speed,acceleration*delta)
	if direction.length()>.1:
		facing = atan2(direction.x,direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y,facing,1.0-exp(-delta*12.0))
	if not grounded: velocity.y -= 18.0*delta
	if jump and grounded and action=="" and (replay or not world.paused):
		velocity.y = 7.0
		if feedback:world.play_tone(510.0,.08,.15)
	if not world.can_walk(global_position+Vector3(velocity.x,0,velocity.z)*delta):
		velocity.x = 0
		velocity.z = 0
	move_on_ground(delta,grounded)
	if feedback and not was_on_floor and is_on_floor():
		landed.emit()
		if action=="": mood_label.text = ""
	was_on_floor = is_on_floor()
	var speed := Vector2(velocity.x,velocity.z).length()
	walking = speed>.2
	is_running=run_enabled and direction.length_squared()>.01 and speed>base_speed*1.05 and can_move and action=="" and not world.paused
	if walking and is_on_floor():
		var pace := clampf((speed-move_speed*speed_multiplier)/(move_speed*speed_multiplier*(SPRINT_MULTIPLIER*run_speed_multiplier-1)),0,1)
		var rate := 8.6*minf(speed/(move_speed*speed_multiplier),1.0)+1.6*pace
		var next_phase := step_phase+delta*rate
		if feedback and int(step_phase/PI)!=int(next_phase/PI): world.footstep(global_position)
		step_phase = fmod(next_phase,TAU*100)
	if global_position.y < -8.0:
		global_position=world.respawn_position();velocity=Vector3.ZERO;reset_physics_interpolation()

func move_on_ground(delta: float,grounded_state: Variant=null) -> void:
	var grounded: bool=is_on_floor() if grounded_state==null else bool(grounded_state)
	var horizontal:=Vector3(velocity.x,0,velocity.z)
	if grounded and velocity.y<=0 and horizontal.length_squared()>.01:
		var ahead: Vector3=global_position+horizontal.normalized()*rig_profile.step_probe_distance
		floor_query.from=ahead+Vector3(0,.38,0)
		floor_query.to=ahead-Vector3(0,.12,0)
		var hit:=get_world_3d().direct_space_state.intersect_ray(floor_query)
		if not hit.is_empty() and hit.normal.y>cos(floor_max_angle):
			var rise: float=hit.position.y+step_floor_offset-global_position.y
			if rise>.006 and rise<.32 and not test_move(global_transform,Vector3.UP*rise):global_position.y+=rise
	move_and_slide()
func animate_pose(delta: float) -> void:
	left_arm.position=arm_rest_left
	right_arm.position=arm_rest_right
	clock += delta
	blink_in -= delta
	if blink_in<=0:
		blink_time = 0
		blink_in = randf_range(4.5,8.0)
	if blink_time>=0:
		blink_time += delta
		eyes.scale.y = clampf(absf(blink_time-.09)/.09,.06,1)
		if blink_time>=.18:
			blink_time = -1
			eyes.scale.y = 1
	var grounded:=network_grounded if network_replica else is_on_floor()
	var moving := walking and grounded and not seated and (action=="" or work_align_active)
	var speed := Vector2(velocity.x,velocity.z).length()
	var pace := clampf((speed-move_speed*speed_multiplier)/(move_speed*speed_multiplier*(SPRINT_MULTIPLIER*run_speed_multiplier-1)),0,1) if moving else 0.0
	gait_blend = move_toward(gait_blend,1.0 if moving else 0.0,delta*8)
	run_blend = move_toward(run_blend,pace,delta*5)
	var stride := sin(step_phase)*gait_blend
	var arm_swing: float=lerpf(.52,.90,run_blend)*rig_profile.stride_scale
	var leg_swing: float=lerpf(.62,1.04,run_blend)*rig_profile.stride_scale
	var arm_l := Vector3(stride*arm_swing,0,-.025)
	var arm_r := Vector3(-stride*arm_swing,0,.025)
	var leg_l := Vector3(-stride*leg_swing,0,0)
	var leg_r := Vector3(stride*leg_swing,0,0)
	var bob := lerpf((.006+sin(clock*1.7)*.006),lerpf(absf(cos(step_phase))*.022,absf(sin(step_phase))*.025,run_blend),gait_blend)
	var roll := stride*lerpf(.018,.027,run_blend)
	var lean := lerpf(.025,.075,run_blend)*gait_blend
	var head_roll := -roll*.55
	if world!=null and not grounded and not seated and action=="":
		arm_l.z=-.48;arm_r.z=.48
		arm_l.x=-.10;arm_r.x=-.10
		bob=0;lean=.015
	mouth.scale = Vector3.ONE
	mood_label.position.y = rig_profile.mood_height+sin(clock*3)*.045
	if action!="":
		action_time += delta
		var t := action_time
		match action:
			"plant", "water", "weed", "gather_stone", "gather_copper", "gather_wood", "gather_branch":
				lean = .23 if action in ["plant","gather_branch"] else .10
				arm_r.x = -1.05 + sin(t*7.0)*(.40 if action.begins_with("gather") else .12)
				arm_l.x = -.65 if action=="plant" else -.16
				roll = sin(t*5)*.018
			"cook":
				arm_r.x=-1.10+sin(t*4.5)*.20
				arm_r.z=.08+cos(t*4.5)*.10
				arm_l.x=-.85
				lean=.04
				roll=sin(t*2.5)*.012
			"eat":
				var bite:=.5+.5*sin(t*3.8)
				arm_r.x=lerpf(-.75,-1.95,smoothstep(.1,.9,bite))
				var inward: float=clampf(right_arm.position.x/rig_profile.grip_offset.length(),.65,1.0)
				arm_r.y=-inward*smoothstep(.20,.85,bite)
				arm_l.x=-.45
				leg_l.x=-1.10
				leg_r.x=-1.10
				lean=-.015
				roll=sin(t*2)*.008
				mouth.scale=Vector3(.68,1.0+smoothstep(.6,.95,bite)*1.1,1)
				bob=0
			"tea":
				arm_r.x = -1.52
				head_roll = -.045
				mouth.scale = Vector3(.56,1.7+sin(t*7)*.15,1)
				roll = sin(t*2)*.015
			"harvest_tree":
				arm_l.x=-1.7;arm_l.z=-.8
				arm_r.x=-1.7;arm_r.z=.8
				head_roll=sin(t*2)*.025
				bob=absf(sin(t*4))*.025
			"harvest":
				lean = sin(minf(t/1.2,1.0)*PI)*.55
				arm_l.x = -.9
				arm_r.x = -.9
				bob = absf(sin(t*7))*.05
			"snack":
				arm_r.x = -1.7
				arm_r.y = -.65
				arm_l.x = -.25
				mouth.scale = Vector3(.68,1.15+absf(sin(t*9))*.65,1)
				head_roll = sin(t*3)*.028
			"nap":
				leg_l.x = -1.22
				leg_r.x = -1.22
				arm_l.x = -.15
				arm_r.x = -.15
				lean = -.035
				roll = -.025
				head_roll = -.10
				bob = sin(t*1.5)*.003
			"sleep":
				arm_l=Vector3(0,0,.22);arm_r=Vector3(0,0,-.22)
				leg_l=Vector3.ZERO;leg_r=Vector3.ZERO
				lean=SleepPose.BODY_ANGLE;roll=0;head_roll=0;bob=0
				eyes.scale.y=.045
			"confused":
				head_roll = sin(minf(t,1.0)*PI*.5)*.19
			"celebrate":
				bob = absf(sin(t*5))*.28
				arm_l.z = -1.05
				arm_r.z = 1.05
				roll = sin(t*5)*.045
			"bell":
				arm_r.z = 1.1
				head_roll = .10
		if action_time>=action_length:
			action = ""
			mood_label.text = ""
			held_cup.visible = false
			mouth.scale = Vector3.ONE
	bob*=rig_profile.bob_scale
	lean*=rig_profile.tilt_scale
	if sleeping: lean=SleepPose.BODY_ANGLE
	roll*=rig_profile.tilt_scale
	var blend := 1.0-exp(-delta*18.0)
	pose_limb(left_arm,arm_l,blend)
	pose_limb(right_arm,arm_r,blend)
	pose_limb(left_leg,leg_l,blend)
	pose_limb(right_leg,leg_r,blend)
	var lift_phase:=cos(step_phase)
	var lift:=lerpf(.035,.12,run_blend)*gait_blend if moving else 0.0
	left_leg.position=leg_rest_left+Vector3(0,maxf(0,lift_phase)*lift,0)
	right_leg.position=leg_rest_right+Vector3(0,maxf(0,-lift_phase)*lift,0)
	if moving:
		var a: Vector3=visual.basis*(left_leg.position+left_leg.basis*rig_profile.leg_end)
		var b: Vector3=visual.basis*(right_leg.position+right_leg.basis*rig_profile.leg_end)
		var sole: float=minf(a.y,b.y)-rig_profile.leg_radius
		bob-=maxf(0,sole)*.55*run_blend
	visual.position.y = lerpf(visual.position.y,bob,blend)
	visual.rotation.z = lerp_angle(visual.rotation.z,roll,blend)
	visual.rotation.x = lerp_angle(visual.rotation.x,lean,blend)
	head.rotation.z = lerp_angle(head.rotation.z,head_roll,1.0-exp(-delta*7))
	head.rotation.x = lerp_angle(head.rotation.x,SleepPose.HEAD_ANGLE if sleeping else -lean*.3,blend)
	ears[0].rotation.z = rig_profile.ear_rest.x+(sin(clock*2.1)*.012+stride*.02)*rig_profile.ear_motion
	ears[1].rotation.z = rig_profile.ear_rest.y+(sin(clock*2.1+.5)*.012-stride*.016)*rig_profile.ear_motion
	for ear in ears: ear.rotation.x = lerpf(ear.rotation.x,(-run_blend*.10+sin(step_phase-.4)*gait_blend*.022)*rig_profile.ear_motion,blend)
	if action=="harvest_tree": pose_tree_reach()
	if sleeping:
		eyes.scale.y=.045
		for ear in ears: ear.rotation.x=.30*rig_profile.ear_motion
	if rig_profile.tail_sway>0 and has_node("Visual/Tail"):
		$Visual/Tail.rotation.y=(sin(clock*1.4)+stride*.8)*rig_profile.tail_sway
	if held_cup.visible:
		var hand := right_arm.to_global(rig_profile.grip_offset)
		held_cup.global_transform = Transform3D(visual.global_basis,hand+visual.global_basis*Vector3(0,.12,.12))

func align_work(target: Vector3,distance_: float) -> void:
	var away:=global_position-target;away.y=0
	if away.length()<distance_ or away.length()>distance_+.85: return
	work_position=target+away.normalized()*distance_;work_position.y=global_position.y
	work_align_active=true
func aim_hand(limb: Node3D,point: Vector3,left: bool=false) -> void:
	var grip: Vector3=rig_profile.grip_offset
	if left: grip.x=-grip.x
	var direction:=visual.to_local(point)-limb.position
	var stretch:=clampf(sqrt(maxf(.01,(direction.length_squared()-grip.x*grip.x-grip.z*grip.z)/(grip.y*grip.y))),.60,1.75)
	limb.scale=Vector3(1,stretch,1);grip.y*=stretch
	limb.quaternion=Quaternion(grip.normalized(),direction.normalized())
func pose_tree_reach() -> void:
	# Reach around the cheeks on an outward arc; raising straight through the
	# face would hide these deliberately simple, unjointed arms inside the head.
	var lift:=smoothstep(0,.30,action_time)
	for side in [-1,1]:
		var limb: Node3D=left_arm if side<0 else right_arm
		var rest:=arm_rest_left if side<0 else arm_rest_right
		limb.position=rest+Vector3(0,-.12,.08)*lift
		var raised:=Vector3(side*.70,.46+sin(action_time*5+side)*.055,.66).normalized()
		var direction:=Vector3(side*.16,-.98,.12).normalized().slerp(raised,lift)
		var point: Vector3=limb.position+direction*rig_profile.grip_offset.length()*lerpf(1.0,1.55,lift)
		aim_hand(limb,visual.to_global(point),side<0)
func pose_limb(limb: Node3D, angles: Vector3, blend: float) -> void:
	limb.quaternion = limb.quaternion.slerp(Quaternion.from_euler(angles),blend)
